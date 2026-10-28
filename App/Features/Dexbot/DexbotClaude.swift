import ClaudeForFoundationModels
import Foundation
import FoundationModels
import Security

/// Dexbot on Claude, with the user's own Anthropic API key. Anthropic's Claude for Foundation Models
/// package plugs Claude into the same `LanguageModelSession` the on-device model uses, so Dexbot's
/// tools, persona and chats don't change. Questions and Dexbot's lookups go from the device straight
/// to Anthropic and are billed to the user's Anthropic account.
nonisolated enum DexbotClaude {
    /// The Claude models Dexbot offers, most capable first.
    nonisolated enum Model: String, CaseIterable, Identifiable, Sendable {
        case fable5_1 = "claude-fable-5-1"
        case opus5_5 = "claude-opus-5-5"
        case sonnet5_5 = "claude-sonnet-5-5"
        case haiku5_5 = "claude-haiku-5-5"

        var id: String { rawValue }

        var name: String {
            switch self {
            case .fable5_1: "Claude Fable 5.1"
            case .opus5_5: "Claude Opus 5.5"
            case .sonnet5_5: "Claude Sonnet 5.5"
            case .haiku5_5: "Claude Haiku 5.5"
            }
        }

        var summary: String {
            switch self {
            case .fable5_1: "Anthropic's most capable model, and the priciest."
            case .opus5_5: "Careful reasoning for teams and tricky matchups."
            case .sonnet5_5: "Quick, thorough answers for less."
            case .haiku5_5: "The fastest and cheapest."
            }
        }

        var claudeModel: ClaudeModel {
            switch self {
            case .fable5_1: .fable5_1
            case .opus5_5: .opus5_5
            case .sonnet5_5: .sonnet5_5
            case .haiku5_5: .haiku5_5
            }
        }

        /// When a model declines a request on policy grounds, the API can hand it to the substitute it
        /// recommends. Haiku 5.5 has none, and the API rejects the setting for it.
        var usesServerFallbacks: Bool { self != .haiku5_5 }
    }

    static let modelKey = "dexbotClaudeModel"

    /// The model Dexbot uses with Claude: Opus 5.5 unless the user picks another.
    static var model: Model {
        get { UserDefaults.standard.string(forKey: modelKey).flatMap(Model.init(rawValue:)) ?? .opus5_5 }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: modelKey) }
    }

    static var hasKey: Bool { APIKey.saved != nil }

    /// Claude for one Dexbot session, or nil without a key. Dexbot's answers are lookups and short
    /// explanations, so every model runs at medium effort and the choice of model sets the quality and cost.
    static func languageModel(_ model: Model = model) -> ClaudeLanguageModel? {
        guard let key = APIKey.saved else { return nil }
        return ClaudeLanguageModel(name: model.claudeModel, auth: .apiKey(key), fixedEffort: .medium,
                                   fallbacks: model.usesServerFallbacks ? .serverDefault : [])
    }

    /// Whether Claude couldn't answer for a reason the on-device model can cover: no connection, a busy API
    /// or a timeout. A rejected key isn't one; that's the user's to fix.
    static func isOutage(_ error: Error) -> Bool {
        if error is URLError { return true }
        if let error = error as? LanguageModelError {
            switch error {
            case .rateLimited, .timeout: return true
            default: return false
            }
        }
        return false
    }

    /// Friendly wording for Claude's errors, or nil for ones Dexbot words itself.
    static func describe(_ error: Error) -> String? {
        if case ClaudeError.missingCredential = error {
            return "Claude didn't accept your API key. Check it in Settings › Dexbot."
        }
        if let error = error as? LanguageModelError {
            switch error {
            case .rateLimited: return "Claude is busy, or your Anthropic account hit its rate limit. Try again in a moment."
            case .timeout: return "Claude took too long to answer. Try asking again."
            case .refusal, .guardrailViolation: return "I can't help with that one, but ask me anything about Pokémon."
            default: return nil
            }
        }
        if error is URLError {
            return "I couldn't reach Claude. Check your connection, or switch me to on-device answers from the menu."
        }
        return nil
    }

    // MARK: The key

    /// The user's key, in the Keychain item Scope Lens's advisor uses on the Mac (its `AdvisorClient`'s
    /// `keychainService` and `keychainAccount`), so one key serves both there.
    nonisolated enum APIKey {
        private static let service = "com.babingobango.ScopeLens.advisor"
        private static let account = "anthropic-api-key"

        private static var item: [String: Any] {
            [kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: service,
             kSecAttrAccount as String: account]
        }

        static var saved: String? {
            var query = item
            query[kSecReturnData as String] = true
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data,
                  let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
            return key
        }

        /// The last four characters, to show which key is saved without showing the key.
        static var hint: String? { saved.map { "••••" + $0.suffix(4) } }

        /// Saves a key in place of any earlier one. On iPhone and iPad it stays on the device and is
        /// readable once the device has been unlocked after starting up, so Siri, CarPlay and the
        /// watch can ask Claude while it's locked.
        @discardableResult
        static func save(_ key: String) -> Bool {
            remove()
            var add = item
            add[kSecValueData as String] = Data(key.utf8)
            #if os(iOS)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            #endif
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }

        static func remove() {
            SecItemDelete(item as CFDictionary)
        }
    }

    // MARK: Checking a key

    /// What checking a key found.
    nonisolated enum KeyCheck: Equatable, Sendable {
        case works(modelName: String)
        case rejected
        case modelUnavailable
        case failed(String)
    }

    /// Checks a key with Anthropic's Models API, which costs nothing: it confirms the key works and can use
    /// the model. The Claude package speaks only the Messages API, so this one request is plain HTTP.
    static func check(key: String, model: Model) async -> KeyCheck {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models/\(model.rawValue)")!)
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200:
                let info = try? JSONDecoder().decode(ModelInfo.self, from: data)
                return .works(modelName: info?.displayName ?? model.name)
            case 401: return .rejected
            case 403, 404: return .modelUnavailable
            case let status:
                let failure = try? JSONDecoder().decode(ErrorBody.self, from: data)
                return .failed(failure?.error.message ?? "Anthropic answered with HTTP \(status).")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private nonisolated struct ModelInfo: Decodable {
        var displayName: String

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    private nonisolated struct ErrorBody: Decodable {
        struct Detail: Decodable { var message: String }
        var error: Detail
    }
}
