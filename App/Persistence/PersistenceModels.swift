import Foundation
import NeodexKit
import SwiftData

/// A saved Teambuilder team. Members are stored as a value array so their order is preserved.
@Model
final class SavedTeam {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Showdown format ID, e.g. `"gen9ou"`.
    var format: String?
    var createdAt: Date
    var updatedAt: Date
    var members: [TeamMember]

    init(name: String = "New Team", format: String? = nil, members: [TeamMember] = []) {
        id = UUID()
        self.name = name
        self.format = format
        createdAt = .now
        updatedAt = .now
        self.members = members
    }

    func touch() { updatedAt = .now }

    static let maximumMembers = 6
}

/// One Pokémon on a team: a Showdown set expressed with Neodex IDs.
struct TeamMember: Codable, Hashable, Identifiable {
    var id = UUID()
    var pokemonID: String
    var nickname: String?
    /// `"M"`, `"F"` or `nil`.
    var gender: String?
    var level = 100
    var shiny = false
    var itemID: String?
    var abilityID: String?
    var natureID = Nature.serious.id
    var teraType: PokemonType?
    var evs: StatBlock = .zero
    var ivs: StatBlock = .perfectIVs
    var moveIDs: [String?] = [nil, nil, nil, nil]

    init(pokemon: Pokemon) {
        pokemonID = pokemon.id
        abilityID = pokemon.abilities.primary
        teraType = pokemon.primaryType
        if let ratio = pokemon.maleRatio {
            gender = ratio >= 0.5 ? "M" : "F"
            if ratio == 0.5 { gender = nil }
        }
    }

    var chosenMoveIDs: [String] { moveIDs.compactMap { $0 } }
}

/// A record of something the user looked at, powering history and recommendations.
@Model
final class BrowsingRecord {
    var kind: String
    var entityID: String
    var viewedAt: Date

    init(kind: Kind, entityID: String) {
        self.kind = kind.rawValue
        self.entityID = entityID
        viewedAt = .now
    }

    enum Kind: String {
        case pokemon, move, ability, item
    }
}
