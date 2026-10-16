import Foundation
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

/// Reads teams from the shared store. SwiftData models are main-actor isolated, so this hops there.
@MainActor
enum TeamReader {
    static func teams() -> [TeamSummary] {
        guard let url = SharedContainer.storeURL, FileManager.default.fileExists(atPath: url.path),
              let container = try? ModelContainer(for: SavedTeam.self, BrowsingRecord.self,
                                                  configurations: ModelConfiguration(url: url)) else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SavedTeam>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map { team in
            TeamSummary(id: team.id.uuidString, name: team.name, format: team.format,
                        pokemonIDs: team.members.map(\.pokemonID), shiny: team.members.map(\.shiny), updatedAt: team.updatedAt)
        }
    }
}
