import Foundation
import FoundationModels
import NeodexKit
import Observation
import SwiftData

/// The chat screen's state: the open conversation, its live model session and streaming replies.
@Observable
@MainActor
final class DexbotModel {
    static let shared = DexbotModel()

    private(set) var conversation: DexbotConversation?
    /// Changes whenever the model switches chats, so a chat screen can tell its own chat from one opened elsewhere.
    private(set) var chatID = UUID()
    private(set) var messages: [DexbotMessage] = []
    private(set) var isResponding = false
    /// The saved chat a reply is streaming into, so only that chat's screen shows it.
    private(set) var respondingConversationID: UUID?
    /// The reply being streamed, before it is saved.
    private(set) var streamingText = ""
    /// Set when Dexbot wants to say the last reply out loud (voice mode).
    private(set) var pendingSpeech: String?

    var prefersPrivateCloud: Bool {
        didSet {
            DexbotEngine.prefersPrivateCloud = prefersPrivateCloud
            session = nil
        }
    }

    private var session: LanguageModelSession?
    /// Which model the live session runs on; a cloud outage switches the chat to on-device.
    private var sessionBackend: DexbotEngine.Backend = .onDevice
    private var database: PokedexDatabase?
    private var context: ModelContext?

    init() {
        prefersPrivateCloud = DexbotEngine.prefersPrivateCloud
    }

    var backend: DexbotEngine.Backend { DexbotEngine.activeBackend }
    var isPrivateCloudAvailable: Bool { DexbotEngine.isPrivateCloudAvailable }

    func configure(database: PokedexDatabase, context: ModelContext) {
        self.database = database
        self.context = context
    }

    func startNewChat() {
        chatID = UUID()
        conversation = nil
        messages = []
        session = nil
        streamingText = ""
    }

    func resume(_ conversation: DexbotConversation) {
        guard conversation.id != self.conversation?.id else { return }
        chatID = UUID()
        self.conversation = conversation
        messages = conversation.messages
        session = nil
        streamingText = ""
    }

    /// Deletes the open conversation from the store and starts over.
    func deleteConversation() {
        if let conversation, let context {
            context.delete(conversation)
        }
        startNewChat()
    }

    /// Lets go of a conversation that is being deleted elsewhere (the conversations list).
    func forget(_ conversation: DexbotConversation) {
        if conversation.id == self.conversation?.id { startNewChat() }
    }

    /// A saved chat by ID, or nil once it has been deleted.
    func storedConversation(_ id: UUID) -> DexbotConversation? {
        guard let context else { return nil }
        var descriptor = FetchDescriptor<DexbotConversation>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func clearPendingSpeech() { pendingSpeech = nil }

    /// Sends one message and streams the reply. `spoken` keeps the answer short and queues it for speech.
    func send(_ rawText: String, spoken: Bool = false) async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding, let database else { return }
        isResponding = true
        streamingText = ""
        defer {
            isResponding = false
            respondingConversationID = nil
        }

        append(DexbotMessage(role: .user, text: text))
        // Another screen can switch chats before the reply arrives; the answer still belongs here.
        let askedID = conversation?.id
        respondingConversationID = askedID
        if session == nil { session = makeSession(spoken: spoken) }
        guard let session else { return }

        var reply = ""
        var note: String?
        do {
            reply = try await stream(prompt(for: text, spoken: spoken), in: session)
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error, let fresh = makeSession(spoken: spoken) {
                // Start a fresh session that remembers the gist, and try once more.
                self.session = fresh
                do {
                    reply = try await stream(prompt(for: text, spoken: spoken), in: fresh)
                } catch {
                    reply = DexbotEngine.describe(error)
                }
            } else {
                reply = DexbotEngine.describe(error)
            }
        } catch where sessionBackend == .privateCloud && DexbotEngine.isCloudOutage(error) {
            // Private Cloud Compute is unreachable: finish this chat on device instead.
            if let fallback = makeSession(spoken: spoken, backend: .onDevice) {
                self.session = fallback
                do {
                    reply = try await stream(prompt(for: text, spoken: spoken), in: fallback)
                    note = "Private Cloud Compute wasn't reachable, so this answer came from the on-device model."
                } catch {
                    reply = DexbotEngine.describe(error)
                }
            } else {
                reply = DexbotEngine.describe(error)
            }
        } catch {
            reply = DexbotEngine.describe(error)
        }
        streamingText = ""
        let answer = DexbotMessage(role: .dexbot, text: note.map { reply + "\n\n_\($0)_" } ?? reply)
        if conversation?.id == askedID {
            append(answer)
        } else if let askedID, let asked = storedConversation(askedID) {
            asked.messages.append(answer)
            asked.touch()
        }
        if spoken { pendingSpeech = reply }
    }

    private func stream(_ prompt: String, in session: LanguageModelSession) async throws -> String {
        var latest = ""
        for try await snapshot in session.streamResponse(to: prompt) {
            latest = snapshot.content
            streamingText = latest
        }
        return latest.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first prompt of a resumed chat carries a short recap, since the model's own transcript starts empty.
    private func prompt(for text: String, spoken: Bool) -> String {
        var prompt = text
        if (session?.transcript.count ?? 0) <= 1, messages.count > 1 {
            let recent = messages.dropLast().suffix(6).map { message in
                "\(message.role == .user ? "User" : "Dexbot"): \(String(message.text.prefix(300)))"
            }
            prompt = "Earlier in this conversation:\n" + recent.joined(separator: "\n") + "\n\nUser's new message: " + text
        }
        if spoken { prompt += "\n(Answer in one or two spoken sentences.)" }
        return prompt
    }

    private func makeSession(spoken: Bool, backend: DexbotEngine.Backend = DexbotEngine.activeBackend) -> LanguageModelSession? {
        guard let database else { return nil }
        sessionBackend = backend
        return DexbotEngine.makeSession(database: database, spoken: spoken, backend: backend)
    }

    private func append(_ message: DexbotMessage) {
        messages.append(message)
        if conversation == nil, let context {
            let title = messages.first { $0.role == .user }.map { DexbotConversation.title(for: $0.text) } ?? "New Chat"
            let created = DexbotConversation(title: title)
            context.insert(created)
            conversation = created
        }
        conversation?.messages = messages
        conversation?.touch()
    }
}
