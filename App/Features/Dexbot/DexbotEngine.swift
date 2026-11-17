import Foundation
import FoundationModels
import NeodexKit
import os

/// Dexbot's brain: the persona, which model to use, and one-shot answers for Siri and CarPlay.
/// The chat screen keeps a long-lived session; everything else goes through `answer`.
nonisolated enum DexbotEngine {
    static let backendKey = "dexbotBackend"
    private static let log = Logger(subsystem: "Neodex", category: "Dexbot")

    static let instructions = """
        You are Dexbot, the voice of Neodex, an offline Pokédex app. You know the Pokémon games and competitive \
        battling inside out. Use the tools for every fact about Pokémon, moves, Abilities, items, type matchups, \
        usage statistics, damage and the user's teams; never invent stats, moves, matchups or numbers. If a tool \
        can't find something, say so and offer the closest match. Be friendly and concise: a short paragraph, or a \
        few bullet points for lists. Use the exact names the tools return. Light Markdown is fine (bold names), \
        no headings. Never mention the tools or that you looked something up; just answer. When the user asks you \
        to build or make a team, call buildTeam once with a name, the format, the weather only if they asked for \
        a weather team, and only the Pokémon the user asked for, or else one or two the team is built around; \
        Neodex picks the rest from Smogon's statistics, completes every set and fixes anything the format doesn't \
        allow. Then, in a few sentences about only the Pokémon buildTeam saved, give the team's name, each one's \
        job in a few words from its moves, and what Neodex added or changed. The app shows the whole team under \
        your reply, so don't list the sets. Only build a team when asked.
        """

    static let spokenInstructions = instructions + """
         The user is listening, not reading: answer in one or two plain sentences with no Markdown, lists or symbols.
        """

    /// The model the user picked: Apple's larger Private Cloud Compute model unless they chose another.
    /// Dexbot uses it whenever it can run (`activeBackend`), and the on-device model otherwise.
    static var preferredBackend: Backend {
        get { UserDefaults.standard.string(forKey: backendKey).flatMap(Backend.init(rawValue:)) ?? .privateCloud }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: backendKey) }
    }

    nonisolated enum Backend: String, CaseIterable, Identifiable, Sendable {
        case onDevice, privateCloud, claude

        var id: String { rawValue }

        var name: String {
            switch self {
            case .onDevice: "On This Device"
            case .privateCloud: "Private Cloud Compute"
            case .claude: "Claude"
            }
        }

        /// What choosing it means, under its name in Dexbot's settings.
        var summary: String {
            switch self {
            case .onDevice: "Apple Intelligence's model on this device. Private, free and works offline."
            case .privateCloud: "Apple Intelligence's larger model, run privately on Apple's servers. Free, with a daily limit."
            case .claude: "Anthropic's models, with your own API key."
            }
        }
    }

    /// Why Dexbot can't run here, in the user's words. Claude needs only a key, and Private Cloud Compute
    /// can answer while the on-device model is still downloading, so either stands in for it.
    static var unavailableReason: String? {
        if activeBackend != .onDevice { return nil }
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(.deviceNotEligible): return "Dexbot needs a device that supports Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings to chat with Dexbot."
        case .unavailable(.modelNotReady): return "Apple Intelligence is still downloading its model. Try again in a little while."
        @unknown default: return "Apple Intelligence isn't available right now."
        }
    }

    #if PRIVATE_CLOUD_COMPUTE
    /// The one Private Cloud Compute model the app uses. Each `PrivateCloudComputeLanguageModel()` opens and
    /// prewarms model sessions of its own, and SwiftUI checks availability on every update, so a fresh
    /// instance per check churned through hundreds of sessions a second while a reply streamed.
    static let privateCloud = PrivateCloudComputeLanguageModel()
    #endif

    /// Private Cloud Compute needs Apple's managed `com.apple.developer.private-cloud-compute`
    /// entitlement. Without it the model still reports itself available and the framework traps on the
    /// first request, so the cloud path is compiled in only when the `PRIVATE_CLOUD_COMPUTE` condition is
    /// set together with the entitlement.
    static var isPrivateCloudAvailable: Bool {
        #if PRIVATE_CLOUD_COMPUTE
        return privateCloud.isAvailable
        #else
        return false
        #endif
    }

    static var isOnDeviceAvailable: Bool { SystemLanguageModel.default.isAvailable }

    /// Whether an error means a cloud model itself is unreachable, busy or down, in which case the
    /// on-device model can take over.
    static func isCloudOutage(_ error: Error, on backend: Backend) -> Bool {
        switch backend {
        case .onDevice:
            return false
        case .privateCloud:
            #if PRIVATE_CLOUD_COMPUTE
            // Not every failure arrives as `PrivateCloudComputeLanguageModel.Error`: on a network that
            // blocks iCloud Private Relay, the token server Private Cloud Compute needs is unreachable and
            // the framework passes on an error of its own. Anything that isn't about the question means
            // the cloud couldn't answer it, so the device can.
            return !isAboutTheQuestion(error)
            #else
            return false
            #endif
        case .claude:
            return DexbotClaude.isOutage(error)
        }
    }

    /// Failures the on-device model would run into as well: the question itself, a tool, or the user.
    static func isAboutTheQuestion(_ error: Error) -> Bool {
        if error is CancellationError || error is LanguageModelSession.ToolCallError
            || error is LanguageModelSession.Error || isContextOverflow(error) {
            return true
        }
        if let error = error as? LanguageModelError {
            switch error {
            case .guardrailViolation, .refusal, .unsupportedLanguageOrLocale: return true
            default: return false
            }
        }
        return false
    }

    /// The note under an answer the on-device model gave because `backend` couldn't.
    static func fallbackNote(after error: Error, from backend: Backend) -> String {
        #if PRIVATE_CLOUD_COMPUTE
        if let cloud = error as? PrivateCloudComputeLanguageModel.Error, case .quotaLimitReached = cloud {
            return "You've used today's Private Cloud Compute requests, so this answer came from the on-device model."
        }
        #endif
        return "\(backend.name) wasn't reachable, so this answer came from the on-device model."
    }

    /// Records why a model couldn't answer, for Console. The error's type, domain and code are public; its
    /// wording stays private, since it can quote the question.
    static func logFailure(_ error: Error, on backend: Backend) {
        let bridged = error as NSError
        log.error("""
            \(backend.rawValue, privacy: .public) couldn't answer: \(String(reflecting: type(of: error)), privacy: .public) \
            (\(bridged.domain, privacy: .public) \(bridged.code, privacy: .public)) \(String(describing: error), privacy: .private)
            """)
    }

    /// Whether a conversation outgrew the model's context window, from Apple's models or Claude.
    static func isContextOverflow(_ error: Error) -> Bool {
        if let error = error as? LanguageModelError, case .contextSizeExceeded = error { return true }
        return false
    }

    static var activeBackend: Backend {
        resolve(preferred: preferredBackend, hasClaudeKey: DexbotClaude.hasKey, privateCloudAvailable: isPrivateCloudAvailable)
    }

    /// The preferred model when it can run, otherwise the on-device one.
    static func resolve(preferred: Backend, hasClaudeKey: Bool, privateCloudAvailable: Bool) -> Backend {
        switch preferred {
        case .claude where hasClaudeKey: .claude
        case .privateCloud where privateCloudAvailable: .privateCloud
        default: .onDevice
        }
    }

    /// Identifies what a new session would run on, so a live chat notices a switch of model or key.
    static var sessionSignature: String {
        let backend = activeBackend
        return backend == .claude ? "claude-\(DexbotClaude.model.rawValue)-\(DexbotClaude.APIKey.hint ?? "")" : backend.rawValue
    }

    /// Where answers come from, for the chat's intro.
    static var sourceDescription: (text: String, systemImage: String) {
        switch activeBackend {
        case .onDevice: ("Answers are generated on this device.", "iphone")
        case .privateCloud: ("Answers come from Apple's Private Cloud Compute.", "icloud")
        case .claude: ("Answers come from \(DexbotClaude.model.name), with your API key.", "sparkle")
        }
    }

    /// A fresh session with Dexbot's tools and persona.
    static func makeSession(database: PokedexDatabase, spoken: Bool, backend: Backend = activeBackend) -> LanguageModelSession {
        var tools = DexbotTools.all(database: database)
        var text = spoken ? spokenInstructions : instructions
        #if os(macOS)
        // Scope Lens lives in the Mac app; Dexbot can read the battle it is tracking.
        tools.append(LiveBattleTool())
        text += ScopeLensDexbot.instructions
        #endif
        if backend == .claude, let claude = DexbotClaude.languageModel() {
            return LanguageModelSession(model: claude, tools: tools, instructions: text)
        }
        #if PRIVATE_CLOUD_COMPUTE
        if backend == .privateCloud {
            return LanguageModelSession(model: privateCloud, tools: tools, instructions: text)
        }
        #endif
        return LanguageModelSession(model: SystemLanguageModel.default, tools: tools, instructions: text)
    }

    /// One question, one answer. Used by Siri, CarPlay and the watch. Falls back to the on-device model
    /// when a cloud model can't be reached.
    static func answer(_ question: String, database: PokedexDatabase, spoken: Bool) async throws -> String {
        let backend = activeBackend
        do {
            return try await respond(to: question, in: makeSession(database: database, spoken: spoken, backend: backend))
        } catch {
            logFailure(error, on: backend)
            guard isCloudOutage(error, on: backend), isOnDeviceAvailable else { throw error }
            return try await respond(to: question, in: makeSession(database: database, spoken: spoken, backend: .onDevice))
        }
    }

    private static func respond(to question: String, in session: LanguageModelSession) async throws -> String {
        try await session.respond(to: question).content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Friendly wording for the framework's errors, and Claude's when it was answering.
    static func describe(_ error: Error, backend: Backend = activeBackend) -> String {
        if isContextOverflow(error) {
            return "That conversation got too long for me to keep in my head. I've started a fresh page; ask me again."
        }
        if error is LanguageModelSession.ToolCallError {
            return "I couldn't look that up. Smogon's statistics need an internet connection; everything else works offline."
        }
        if backend == .claude, let message = DexbotClaude.describe(error) {
            return message
        }
        if let error = error as? LanguageModelError {
            switch error {
            case .guardrailViolation, .refusal: return "I can't help with that one, but ask me anything about Pokémon."
            case .rateLimited: return "I'm being asked a lot right now. Give me a moment and try again."
            case .unsupportedLanguageOrLocale: return "I can only chat in languages Apple Intelligence supports."
            case .timeout: return "That took too long. Try asking again."
            default: break
            }
        }
        if error is SystemLanguageModel.Error {
            return "Apple Intelligence isn't ready on this device yet."
        }
        if let error = error as? LanguageModelSession.Error, error == .concurrentRequests {
            return "One question at a time, Trainer. Let me finish this one first."
        }
        // A cloud failure lands here only when the on-device model couldn't take over either, so these
        // don't suggest switching to it.
        #if PRIVATE_CLOUD_COMPUTE
        if let cloud = error as? PrivateCloudComputeLanguageModel.Error {
            switch cloud {
            case .quotaLimitReached: return "You've used today's Private Cloud Compute requests. Try again tomorrow."
            case .serviceUnavailable: return "Private Cloud Compute isn't available right now. Try again in a little while."
            case .networkFailure: break
            @unknown default: break
            }
        }
        if backend == .privateCloud, isCloudOutage(error, on: .privateCloud) {
            return "I couldn't reach Private Cloud Compute. Check your connection and try again."
        }
        #endif
        if backend == .claude {
            // Anthropic's own wording, such as a low credit balance, is the useful part.
            return "Claude couldn't answer: \(error.localizedDescription)"
        }
        return "Something went wrong on my end. Try asking again."
    }

    /// Starter questions shown on an empty chat.
    static let suggestions = [
        "What is Garchomp weak to?",
        "Who's most used in OU right now?",
        "Can Kingambit learn Sucker Punch?",
        "Choice Band Garchomp Earthquake vs. Corviknight",
        "Best special Fire moves for Charizard",
        "Is my team legal in OU?",
    ]
}
