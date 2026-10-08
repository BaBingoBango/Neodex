import CoreSpotlight
import Foundation
import NeodexKit
import UniformTypeIdentifiers

/// Indexes the Pokédex into Spotlight so Pokémon, moves, abilities, items and natures can be
/// searched from the Home Screen. Re-indexes whenever the bundled dataset changes.
enum SpotlightIndexer {
    private static let indexedVersionKey = "spotlightIndexedDataVersion"

    static func indexIfNeeded(database: PokedexDatabase) async {
        let version = database.manifest.map { "\($0.generatedAt.timeIntervalSince1970)-\($0.schemaVersion)" } ?? "unknown"
        guard UserDefaults.standard.string(forKey: indexedVersionKey) != version else { return }
        await reindex(database: database)
        UserDefaults.standard.set(version, forKey: indexedVersionKey)
    }

    static func reindex(database: PokedexDatabase) async {
        await Task.detached(priority: .utility) {
            await performIndexing(database: database)
        }.value
    }

    nonisolated private static func performIndexing(database: PokedexDatabase) async {
        let index = CSSearchableIndex.default()
        try? await index.deleteAllSearchableItems()

        var items: [CSSearchableItem] = []
        items.reserveCapacity(database.pokemon.count + database.moves.count + database.abilities.count + database.items.count + 25)

        for pokemon in database.pokemon {
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = pokemon.displayName
            let typeText = pokemon.types.map(\.name).joined(separator: "/")
            attributes.contentDescription = "\(pokemon.formattedDexNumber) · \(typeText)-type Pokémon" + (pokemon.genus.map { " · \($0) Pokémon" } ?? "")
            attributes.keywords = [pokemon.name, pokemon.displayName, "Pokémon", String(pokemon.nationalDexNumber)] + pokemon.types.map(\.name)
            attributes.thumbnailURL = Bundle.main.url(forResource: "\(pokemon.imageID)-thumb", withExtension: "heic")
            items.append(CSSearchableItem(uniqueIdentifier: AppRoute.pokemon(pokemon.id).spotlightIdentifier!,
                                          domainIdentifier: "pokemon", attributeSet: attributes))
        }
        for move in database.moves where move.kind == .standard {
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = move.name
            attributes.contentDescription = "\(move.type.name)-type \(move.category.name.lowercased()) move" + (move.shortDescription.map { " · \($0)" } ?? "")
            attributes.keywords = [move.name, "move", move.type.name]
            items.append(CSSearchableItem(uniqueIdentifier: AppRoute.move(move.id).spotlightIdentifier!,
                                          domainIdentifier: "move", attributeSet: attributes))
        }
        for ability in database.abilities {
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = ability.name
            attributes.contentDescription = "Ability" + (ability.shortDescription.map { " · \($0)" } ?? "")
            attributes.keywords = [ability.name, "ability"]
            items.append(CSSearchableItem(uniqueIdentifier: AppRoute.ability(ability.id).spotlightIdentifier!,
                                          domainIdentifier: "ability", attributeSet: attributes))
        }
        for item in database.items {
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = item.name
            attributes.contentDescription = "\(item.category.name.dropLast(item.category.name.hasSuffix("s") ? 1 : 0))" + (item.shortDescription.map { " · \($0)" } ?? "")
            attributes.keywords = [item.name, "item"]
            attributes.thumbnailURL = Bundle.main.url(forResource: "\(item.id)-item", withExtension: "png")
            items.append(CSSearchableItem(uniqueIdentifier: AppRoute.item(item.id).spotlightIdentifier!,
                                          domainIdentifier: "item", attributeSet: attributes))
        }
        for nature in database.natures {
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = "\(nature.name) Nature"
            attributes.contentDescription = nature.isNeutral ? "Neutral nature" : "\(nature.summary) nature"
            attributes.keywords = [nature.name, "nature"]
            items.append(CSSearchableItem(uniqueIdentifier: AppRoute.nature(nature.id).spotlightIdentifier!,
                                          domainIdentifier: "nature", attributeSet: attributes))
        }

        for chunk in stride(from: 0, to: items.count, by: 500) {
            let slice = Array(items[chunk..<min(chunk + 500, items.count)])
            try? await index.indexSearchableItems(slice)
        }
    }
}
