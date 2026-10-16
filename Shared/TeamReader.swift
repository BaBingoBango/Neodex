import Foundation
import NeodexKit
import SwiftData

/// A team as the widgets see it: plain values read from the shared SwiftData store.
nonisolated struct TeamSummary: Sendable, Hashable, Identifiable {
    var id: String
    var name: String
    var format: String?
    var pokemonIDs: [String]
    var shiny: [Bool]
    var updatedAt: Date
}

/// A full set as plain values, for Dexbot's team tools.
nonisolated struct TeamSetSummary: Sendable, Hashable {
    var pokemonID: String
    var itemID: String?
    var abilityID: String?
    var natureID: String
    var teraType: String?
    var evs: [String: Int]
    var moveIDs: [String]
    var level: Int
}

/// Every model in the shared store; the app, the widgets and Dexbot must agree on this list.
nonisolated enum SharedSchema {
    static var models: [any PersistentModel.Type] { [SavedTeam.self, BrowsingRecord.self, DexbotConversation.self] }
}

/// Reads teams from the shared store. SwiftData models are main-actor isolated, so this hops there.
@MainActor
enum TeamReader {
    private static func fetchTeams() -> [SavedTeam] {
        guard let url = SharedContainer.storeURL, FileManager.default.fileExists(atPath: url.path),
              let container = try? ModelContainer(for: Schema(SharedSchema.models), configurations: ModelConfiguration(url: url)) else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SavedTeam>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func teams() -> [TeamSummary] {
        fetchTeams().map { team in
            TeamSummary(id: team.id.uuidString, name: team.name, format: team.format,
                        pokemonIDs: team.members.map(\.pokemonID), shiny: team.members.map(\.shiny), updatedAt: team.updatedAt)
        }
    }

    /// Teams with their full sets, newest first.
    static func teamSets() -> [(team: TeamSummary, sets: [TeamSetSummary])] {
        fetchTeams().map { team in
            let summary = TeamSummary(id: team.id.uuidString, name: team.name, format: team.format,
                                      pokemonIDs: team.members.map(\.pokemonID), shiny: team.members.map(\.shiny), updatedAt: team.updatedAt)
            let sets = team.members.map { member in
                TeamSetSummary(pokemonID: member.pokemonID, itemID: member.itemID, abilityID: member.abilityID, natureID: member.natureID,
                               teraType: member.teraType?.rawValue,
                               evs: Dictionary(uniqueKeysWithValues: member.evs.nonZero.map { ($0.stat.showdownAbbreviation, $0.value) }),
                               moveIDs: member.chosenMoveIDs, level: member.level)
            }
            return (summary, sets)
        }
    }
}

/// A Dexbot conversation as plain values.
nonisolated struct ConversationSummary: Sendable, Hashable, Identifiable {
    var id: String
    var title: String
    var updatedAt: Date
    var messages: [DexbotMessage]
}

extension TeamReader {
    private static func sharedContext() -> ModelContext? {
        guard let url = SharedContainer.storeURL,
              let container = try? ModelContainer(for: Schema(SharedSchema.models), configurations: ModelConfiguration(url: url)) else { return nil }
        return ModelContext(container)
    }

    /// Recent Dexbot chats, newest first.
    static func recentConversations(limit: Int) -> [ConversationSummary] {
        guard let context = sharedContext() else { return [] }
        var descriptor = FetchDescriptor<DexbotConversation>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map {
            ConversationSummary(id: $0.id.uuidString, title: $0.title, updatedAt: $0.updatedAt, messages: $0.messages)
        }
    }

    /// Saves a spoken exchange (CarPlay, Siri) as its own short chat so it shows up in the app.
    static func saveConversation(question: String, answer: String) {
        guard let context = sharedContext() else { return }
        let conversation = DexbotConversation(title: String(question.prefix(48)),
                                              messages: [DexbotMessage(role: .user, text: question), DexbotMessage(role: .dexbot, text: answer)])
        context.insert(conversation)
        try? context.save()
    }
}
