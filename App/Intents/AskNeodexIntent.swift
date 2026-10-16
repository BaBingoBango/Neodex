import AppIntents
import Foundation
import NeodexKit

/// "Hey Siri, ask Neodex…": Dexbot answers one question out loud, hands-free, anywhere Siri runs.
struct AskNeodexIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Ask Dexbot"
    nonisolated static let description = IntentDescription("Ask Neodex's Dexbot a Pokémon question and hear the answer.")

    @Parameter(title: "Question", requestValueDialog: "What would you like to ask Dexbot?")
    var question: String

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Ask Dexbot \(\.$question)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard DexbotEngine.unavailableReason == nil else {
            throw NeodexIntentError.appleIntelligenceUnavailable
        }
        let database = try await DatabaseProvider.shared.database()
        let answer = try await DexbotEngine.answer(question, database: database, spoken: true)
        return .result(value: answer, dialog: IntentDialog("\(answer)"))
    }
}
