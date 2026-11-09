import AppIntents
import Foundation
import NeodexKit

/// A Pokémon as Siri and Shortcuts see it.
nonisolated struct PokemonEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Pokémon")
    static let defaultQuery = PokemonEntityQuery()

    var id: String
    var name: String
    var dexNumber: Int
    var types: [PokemonType]
    var imageID: String

    init(_ pokemon: Pokemon) {
        id = pokemon.id
        name = pokemon.displayName
        dexNumber = pokemon.nationalDexNumber
        types = pokemon.types
        imageID = pokemon.imageID
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = "#\(String(format: "%04d", dexNumber)) · " + types.map(\.name).joined(separator: " / ")
        if let url = Bundle.main.url(forResource: "\(imageID)-thumb", withExtension: "heic"),
           let data = try? Data(contentsOf: url) {
            return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)", image: .init(data: data))
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

/// Finds Pokémon by ID and by typed or spoken name, and suggests the few that Siri's phrases name
/// (see `ShortcutPokemon`).
nonisolated struct PokemonEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [PokemonEntity] {
        let database = try await DatabaseProvider.shared.database()
        return identifiers.compactMap { database.pokemon(id: $0) }.map(PokemonEntity.init)
    }

    func entities(matching string: String) async throws -> [PokemonEntity] {
        let database = try await DatabaseProvider.shared.database()
        return database.search(string, limitPerCategory: 20).pokemon.map(PokemonEntity.init)
    }

    func suggestedEntities() async throws -> [PokemonEntity] {
        let database = try await DatabaseProvider.shared.database()
        return await ShortcutPokemon.ids().compactMap { database.pokemon(id: $0) }.map(PokemonEntity.init)
    }
}
