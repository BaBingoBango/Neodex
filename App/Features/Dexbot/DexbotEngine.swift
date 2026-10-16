import Foundation
import FoundationModels
import NeodexKit

/// Dexbot's brain: the persona, which Apple model to use, and one-shot answers for Siri and CarPlay.
/// The chat screen keeps a long-lived session; everything else goes through `answer`.
nonisolated enum DexbotEngine {
    static let usesPrivateCloudKey = "dexbotUsesPrivateCloud"

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

    /// Whether the user prefers Private Cloud Compute when it is available.
    static var prefersPrivateCloud: Bool {
        get { UserDefaults.standard.object(forKey: usesPrivateCloudKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: usesPrivateCloudKey) }
    }

    enum Backend: String, CaseIterable, Identifiable, Sendable {
        case onDevice, privateCloud

        var id: String { rawValue }

        var name: String {
            switch self {
            case .onDevice: "On-Device"
            case .privateCloud: "Private Cloud Compute"
            }
        }
    }

    /// Why Dexbot can't run here, in the user's words.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(.deviceNotEligible): return "Dexbot needs a device that supports Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings to chat with Dexbot."
        case .unavailable(.modelNotReady): return "Apple Intelligence is still downloading its model. Try again in a little while."
        @unknown default: return "Apple Intelligence isn't available right now."
        }
    }

    /// Private Cloud Compute arrived with iOS 27 and needs Apple's managed
    /// `com.apple.developer.private-cloud-compute` entitlement. Without it the model still reports itself
    /// available and the framework traps on the first request, so the cloud path is compiled in only when the
    /// `PRIVATE_CLOUD_COMPUTE` condition is set together with the entitlement. iOS 26 runs on device only.
    static var isPrivateCloudAvailable: Bool {
        #if PRIVATE_CLOUD_COMPUTE
        if #available(iOS 27, *) { return PrivateCloudComputeLanguageModel().isAvailable }
        #endif
        return false
    }

    /// Whether an error means Private Cloud Compute itself is unreachable, out of quota or down,
    /// in which case the on-device model can take over.
    static func isCloudOutage(_ error: Error) -> Bool {
        #if PRIVATE_CLOUD_COMPUTE
        if #available(iOS 27, *), error is PrivateCloudComputeLanguageModel.Error { return true }
        #endif
        return false
    }

    static var activeBackend: Backend { prefersPrivateCloud && isPrivateCloudAvailable ? .privateCloud : .onDevice }

    /// A fresh session with Dexbot's tools and persona.
    static func makeSession(database: PokedexDatabase, spoken: Bool, backend: Backend = activeBackend) -> LanguageModelSession {
        let tools = DexbotTools.all(database: database)
        let text = spoken ? spokenInstructions : instructions
        #if PRIVATE_CLOUD_COMPUTE
        if backend == .privateCloud, #available(iOS 27, *) {
            return LanguageModelSession(model: PrivateCloudComputeLanguageModel(), tools: tools, instructions: text)
        }
        #endif
        return LanguageModelSession(model: SystemLanguageModel.default, tools: tools, instructions: text)
    }

    /// One question, one answer. Used by Siri and CarPlay. Falls back to the on-device model when
    /// Private Cloud Compute can't be reached.
    static func answer(_ question: String, database: PokedexDatabase, spoken: Bool) async throws -> String {
        let backend = activeBackend
        do {
            return try await respond(to: question, in: makeSession(database: database, spoken: spoken, backend: backend))
        } catch where backend == .privateCloud && isCloudOutage(error) {
            return try await respond(to: question, in: makeSession(database: database, spoken: spoken, backend: .onDevice))
        }
    }

    private static func respond(to question: String, in session: LanguageModelSession) async throws -> String {
        try await session.respond(to: question).content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Friendly wording for the framework's errors.
    static func describe(_ error: Error) -> String {
        if let generation = error as? LanguageModelSession.GenerationError {
            switch generation {
            case .exceededContextWindowSize: return "That conversation got too long for me to keep in my head. I've started a fresh page; ask me again."
            case .guardrailViolation, .refusal: return "I can't help with that one, but ask me anything about Pokémon."
            case .rateLimited: return "I'm being asked a lot right now. Give me a moment and try again."
            case .assetsUnavailable: return "Apple Intelligence isn't ready on this device yet."
            case .concurrentRequests: return "One question at a time, Trainer. Let me finish this one first."
            case .unsupportedLanguageOrLocale: return "I can only chat in languages Apple Intelligence supports."
            default: break
            }
        }
        if error is LanguageModelSession.ToolCallError {
            return "I couldn't look that up. Smogon's statistics need an internet connection; everything else works offline."
        }
        #if PRIVATE_CLOUD_COMPUTE
        if #available(iOS 27, *), let cloud = error as? PrivateCloudComputeLanguageModel.Error {
            switch cloud {
            case .networkFailure: return "I couldn't reach Private Cloud Compute. Check your connection, or switch me to on-device answers from the menu."
            case .quotaLimitReached: return "You've used today's Private Cloud Compute requests. Switch me to on-device answers from the menu and I'll keep going."
            case .serviceUnavailable: return "Private Cloud Compute isn't available right now. Switch me to on-device answers from the menu and I'll keep going."
            @unknown default: break
            }
        }
        #endif
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
