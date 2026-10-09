import Foundation
import NeodexKit

/// Loads the bundled Pokédex exactly once per process, for the UI and for App Intents alike.
actor DatabaseProvider {
    static let shared = DatabaseProvider()

    private var task: Task<PokedexDatabase, Error>?

    func database() async throws -> PokedexDatabase {
        if let task { return try await task.value }
        let task = Task { try await PokedexDatabase.load(from: .main) }
        self.task = task
        do {
            return try await task.value
        } catch {
            self.task = nil
            throw error
        }
    }
}
