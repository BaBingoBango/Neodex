import Foundation
import NeodexKit
import SwiftData
import Testing
@testable import Neodex

/// Browsing history against an in-memory SwiftData store.
@Suite("Browsing history")
@MainActor
struct HistoryTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: SavedTeam.self, BrowsingRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @Test("Recording keeps the record that was just inserted")
    func recordSurvivesPruning() throws {
        let context = try makeContext()
        History.record(.pokemon, id: "garchomp", in: context)
        History.record(.move, id: "earthquake", in: context)
        History.record(.pokemon, id: "kingambit", in: context)
        History.record(.pokemon, id: "garchomp", in: context)
        #expect(History.recent(.pokemon, limit: 10, in: context) == ["garchomp", "kingambit"])
        #expect(History.recent(.move, limit: 10, in: context) == ["earthquake"])
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<BrowsingRecord>()) == 4)
    }

    @Test("Pruning drops only records beyond the maximum")
    func pruneKeepsNewest() throws {
        let context = try makeContext()
        for index in 0..<(History.maximumRecords + 5) {
            context.insert(BrowsingRecord(kind: .pokemon, entityID: "p\(index)"))
        }
        try context.save()
        History.record(.pokemon, id: "newest", in: context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<BrowsingRecord>()) == History.maximumRecords + 1)
        #expect(History.recent(.pokemon, limit: 1, in: context) == ["newest"])
    }

    @Test("Clearing removes everything")
    func clear() throws {
        let context = try makeContext()
        History.record(.pokemon, id: "eevee", in: context)
        try context.save()
        History.clear(in: context)
        #expect(History.recent(.pokemon, limit: 5, in: context).isEmpty)
    }
}
