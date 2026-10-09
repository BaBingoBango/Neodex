import AppIntents
import Foundation
import NeodexKit

/// Opens a Pokémon's page.
struct OpenPokemonIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Open a Pokémon"
    nonisolated static let description = IntentDescription("Opens a Pokémon's Pokédex page in Neodex.")
    nonisolated static let openAppWhenRun = true

    @Parameter(title: "Pokémon")
    var pokemon: PokemonEntity

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$pokemon)")
    }

    func perform() async throws -> some IntentResult {
        await DeepLinkRouter.shared.open(.pokemon(pokemon.id))
        return .result()
    }
}

/// Opens a random species.
nonisolated struct RandomPokemonIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Random Pokémon"
    nonisolated static let description = IntentDescription("Opens a random Pokémon in Neodex.")
    nonisolated static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let database = try await DatabaseProvider.shared.database()
        guard let pokemon = database.species.randomElement() else { throw NeodexIntentError.noData }
        await DeepLinkRouter.shared.open(.pokemon(pokemon.id))
        return .result(dialog: "How about \(pokemon.displayName)?")
    }
}

/// Describes a Pokémon's weaknesses and resistances, without opening the app.
struct TypeMatchupIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Check Type Matchups"
    nonisolated static let description = IntentDescription("Tells you what a Pokémon is weak to and what it resists.")

    @Parameter(title: "Pokémon")
    var pokemon: PokemonEntity

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Check matchups for \(\.$pokemon)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let database = try await DatabaseProvider.shared.database()
        guard let entry = database.pokemon(id: pokemon.id) else { throw NeodexIntentError.unknownPokemon }
        let summary = TypeMatchupSummary.spoken(for: entry)
        return .result(value: summary, dialog: IntentDialog("\(summary)"))
    }
}

/// Reads a Pokédex entry aloud.
struct DexEntryIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Read a Pokédex Entry"
    nonisolated static let description = IntentDescription("Reads a Pokémon's Pokédex entry.")

    @Parameter(title: "Pokémon")
    var pokemon: PokemonEntity

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Read the entry for \(\.$pokemon)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let database = try await DatabaseProvider.shared.database()
        guard let entry = database.pokemon(id: pokemon.id) else { throw NeodexIntentError.unknownPokemon }
        let kind = entry.genus.map { "the \($0) Pokémon" } ?? "a \(entry.types.map(\.name).joined(separator: " and ")) type"
        let text = "\(entry.displayName), \(kind). " + (entry.dexEntries.first?.text ?? "No Pokédex entry is available.")
        return .result(value: text, dialog: IntentDialog("\(text)"))
    }
}

nonisolated enum NeodexIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noData
    case unknownPokemon

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noData: "The Pokédex couldn't be loaded."
        case .unknownPokemon: "That Pokémon isn't in the Pokédex."
        }
    }
}

/// Siri phrases that work out of the box; the Pokémon names come from `PokemonEntityQuery.suggestedEntities()`.
nonisolated struct NeodexShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenPokemonIntent(), phrases: [
            "Open \(\.$pokemon) in \(.applicationName)",
            "Show \(\.$pokemon) in \(.applicationName)",
            "Look up \(\.$pokemon) in \(.applicationName)",
        ], shortTitle: "Open a Pokémon", systemImageName: "book")
        AppShortcut(intent: TypeMatchupIntent(), phrases: [
            "What is \(\.$pokemon) weak to in \(.applicationName)",
            "Check \(\.$pokemon) matchups in \(.applicationName)",
        ], shortTitle: "Type Matchups", systemImageName: "circle.grid.cross")
        AppShortcut(intent: DexEntryIntent(), phrases: [
            "Read the \(.applicationName) entry for \(\.$pokemon)",
            "Tell me about \(\.$pokemon) in \(.applicationName)",
        ], shortTitle: "Read an Entry", systemImageName: "text.book.closed")
        AppShortcut(intent: RandomPokemonIntent(), phrases: [
            "Random Pokémon in \(.applicationName)",
            "Surprise me in \(.applicationName)",
        ], shortTitle: "Random Pokémon", systemImageName: "dice")
    }
}
