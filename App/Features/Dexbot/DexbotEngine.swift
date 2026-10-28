import Foundation
import FoundationModels
import NeodexKit

/// Dexbot's brain: the persona, which model to use, and one-shot answers for Siri and CarPlay.
/// The chat screen keeps a long-lived session; everything else goes through `answer`.
nonisolated enum DexbotEngine {
    static let backendKey = "dexbotBackend"

    static let instructions = """
        You are Dexbot, the voice of Neodex, an offline Pokédex app. You know the Pokémon games and competitive \
        battling inside out. Use the tools for every fact about Pokémon, moves, Abilities, items, type matchups, \
        usage statistics, damage and the user's teams; never invent stats, moves, matchups or numbers. If a tool \
        can't find something, say so and offer the closest match. Be friendly and concise: a short paragraph, or a \
        few bullet points for lists. Use the exact names the tools return. Light Markdown is fine (bold names), \
        no headings. Never mention the tools or that you looked something up; just answer.
        """

    static let spokenInstructions = instructions + """
         The user is listening, not reading: answer in one or two plain sentences with no Markdown, lists or symbols.
        """

    /// The model the user picked, Apple Intelligence on device unless they chose another. Dexbot uses it
    /// whenever it can run (`activeBackend`).
    static var preferredBackend: Backend {
        get { UserDefaults.standard.string(forKey: backendKey).flatMap(Backend.init(rawValue:)) ?? .onDevice }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: backendKey) }
    }

    nonisolated enum Backend: String, CaseIterable, Identifiable, Sendable {
        case onDevice, privateCloud, claude

        var id: String { rawValue }

        var name: String {
            switch self {
            case .onDevice: "On-Device"
            case .privateCloud: "Private Cloud Compute"
            case .claude: "Claude"
            }
        }
    }

    /// Why Dexbot can't run here, in the user's words. Claude needs only a key, so it can stand in
    /// where Apple Intelligence isn't available.
    static var unavailableReason: String? {
        if activeBackend == .claude { return nil }
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(.deviceNotEligible): return "Dexbot needs a device that supports Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings to chat with Dexbot."
        case .unavailable(.modelNotReady): return "Apple Intelligence is still downloading its model. Try again in a little while."
        @unknown default: return "Apple Intelligence isn't available right now."
        }
    }

    /// Private Cloud Compute needs Apple's managed `com.apple.developer.private-cloud-compute`
    /// entitlement. Without it the model still reports itself available and the framework traps on the
    /// first request, so the cloud path is compiled in only when the `PRIVATE_CLOUD_COMPUTE` condition is
    /// set together with the entitlement.
    static var isPrivateCloudAvailable: Bool {
        #if PRIVATE_CLOUD_COMPUTE
        return PrivateCloudComputeLanguageModel().isAvailable
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
            return error is PrivateCloudComputeLanguageModel.Error
            #else
            return false
            #endif
        case .claude:
            return DexbotClaude.isOutage(error)
        }
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
            return LanguageModelSession(model: PrivateCloudComputeLanguageModel(), tools: tools, instructions: text)
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
        } catch where isCloudOutage(error, on: backend) && isOnDeviceAvailable {
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
        #if PRIVATE_CLOUD_COMPUTE
        if let cloud = error as? PrivateCloudComputeLanguageModel.Error {
            switch cloud {
            case .networkFailure: return "I couldn't reach Private Cloud Compute. Check your connection, or switch me to on-device answers from the menu."
            case .quotaLimitReached: return "You've used today's Private Cloud Compute requests. Switch me to on-device answers from the menu and I'll keep going."
            case .serviceUnavailable: return "Private Cloud Compute isn't available right now. Switch me to on-device answers from the menu and I'll keep going."
            @unknown default: break
            }
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
