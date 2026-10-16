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
    private(set) var messages: [DexbotMessage] = []
    private(set) var isResponding = false
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
        conversation = nil
        messages = []
        session = nil
        streamingText = ""
    }

    func resume(_ conversation: DexbotConversation) {
        guard conversation.id != self.conversation?.id else { return }
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

    func clearPendingSpeech() { pendingSpeech = nil }

    /// Sends one message and streams the reply. `spoken` keeps the answer short and queues it for speech.
    func send(_ rawText: String, spoken: Bool = false) async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding, let database else { return }
        isResponding = true
        streamingText = ""
        defer { isResponding = false }

        append(DexbotMessage(role: .user, text: text))
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
        append(DexbotMessage(role: .dexbot, text: note.map { reply + "\n\n_\($0)_" } ?? reply))
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
            let title = messages.first { $0.role == .user }.map { String($0.text.prefix(48)) } ?? "New Chat"
            let created = DexbotConversation(title: title)
            context.insert(created)
            conversation = created
        }
        conversation?.messages = messages
        conversation?.touch()
    }
}
