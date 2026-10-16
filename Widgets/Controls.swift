import AppIntents
import SwiftUI
import WidgetKit

/// Control Center and Action button: open a random Pokémon.
struct RandomPokemonControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "Ethan.Neodex.control.random") {
            ControlWidgetButton(action: OpenRandomPokemonIntent()) {
                Label("Random Pokémon", systemImage: "dice.fill")
            }
        }
        .displayName("Random Pokémon")
        .description("Opens a random Pokémon in Neodex.")
    }
}

/// Control Center and Action button: open the Damage Calculator.
struct DamageCalcControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "Ethan.Neodex.control.calc") {
            ControlWidgetButton(action: OpenDamageCalcIntent()) {
                Label("Damage Calc", systemImage: "function")
            }
        }
        .displayName("Damage Calculator")
        .description("Opens Neodex's Damage Calculator.")
    }
}

nonisolated struct OpenRandomPokemonIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a Random Pokémon"
    static let description = IntentDescription("Opens a random Pokémon in Neodex.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(SharedContainer.deepLink("random")))
    }
}

nonisolated struct OpenDamageCalcIntent: AppIntent {
    static let title: LocalizedStringResource = "Open the Damage Calculator"
    static let description = IntentDescription("Opens Neodex's Damage Calculator.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(SharedContainer.deepLink("calc")))
    }
}
