import Foundation
import SwiftData

/// The app's SwiftData container, kept in the App Group so the Team widget can read teams.
enum PersistenceContainer {
    static func make() -> ModelContainer {
        let schema = Schema(SharedSchema.models)
        if let shared = SharedContainer.storeURL {
            migrateLegacyStoreIfNeeded(to: shared)
            if let container = try? ModelContainer(for: schema, configurations: ModelConfiguration(url: shared)) {
                return container
            }
        }
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Could not open the Neodex store: \(error)")
        }
    }

    /// Earlier versions kept the store in Application Support; move it the first time the group store is used.
    private static func migrateLegacyStoreIfNeeded(to destination: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination.path),
              let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let legacy = support.appendingPathComponent("default.store")
        guard fileManager.fileExists(atPath: legacy.path) else { return }
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacy.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try? fileManager.copyItem(at: source, to: URL(fileURLWithPath: destination.path + suffix))
        }
    }
}
