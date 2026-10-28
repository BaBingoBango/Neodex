import Foundation
import NeodexKit
import SwiftData
import WidgetKit

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

    func touch() {
        updatedAt = .now
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.team)
    }

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

/// A Dexbot chat. Messages are stored as a value array so the whole conversation travels together.
@Model
final class DexbotConversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [DexbotMessage]

    init(title: String = "New Chat", messages: [DexbotMessage] = []) {
        id = UUID()
        self.title = title
        createdAt = .now
        updatedAt = .now
        self.messages = messages
    }

    func touch() { updatedAt = .now }

    /// A chat's title: its first question, ending at a whole word when it runs long.
    nonisolated static func title(for question: String) -> String {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 60 else { return text }
        let words = text.prefix(60).split(separator: " ").dropLast()
        return (words.isEmpty ? String(text.prefix(60)) : words.joined(separator: " ")) + "…"
    }
}

/// One turn of a Dexbot chat. Plain data that crosses isolation boundaries (CarPlay, widgets), so nonisolated.
nonisolated struct DexbotMessage: Codable, Hashable, Identifiable, Sendable {
    enum Role: String, Codable {
        case user, dexbot
    }

    var id = UUID()
    var role: Role
    var text: String
    var date = Date()

    init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}
