import Foundation
import NeodexKit
import SwiftData
import SwiftUI

/// Records what the user looks at, for Explore's "Recently Viewed" and recommendations.
enum History {
    static let maximumRecords = 300

    static func record(_ kind: BrowsingRecord.Kind, id: String, in context: ModelContext) {
        context.insert(BrowsingRecord(kind: kind, entityID: id))
        prune(in: context)
    }

    /// Distinct entity IDs of a kind, most recent first.
    static func recent(_ kind: BrowsingRecord.Kind, limit: Int, in context: ModelContext) -> [String] {
        let kindValue = kind.rawValue
        var descriptor = FetchDescriptor<BrowsingRecord>(predicate: #Predicate { $0.kind == kindValue },
                                                        sortBy: [SortDescriptor(\.viewedAt, order: .reverse)])
        descriptor.fetchLimit = maximumRecords
        let records = (try? context.fetch(descriptor)) ?? []
        var seen = Set<String>()
        var result: [String] = []
        for record in records where seen.insert(record.entityID).inserted {
            result.append(record.entityID)
            if result.count == limit { break }
        }
        return result
    }

    static func clear(in context: ModelContext) {
        try? context.delete(model: BrowsingRecord.self)
    }

    /// Deletes everything past the newest `maximumRecords`. Looks only at saved records: a fetch that
    /// includes pending changes would return the record inserted a moment ago regardless of the
    /// offset, and delete it on the spot.
    private static func prune(in context: ModelContext) {
        var descriptor = FetchDescriptor<BrowsingRecord>(sortBy: [SortDescriptor(\.viewedAt, order: .reverse)])
        descriptor.fetchOffset = maximumRecords
        descriptor.includePendingChanges = false
        for stale in (try? context.fetch(descriptor)) ?? [] { context.delete(stale) }
    }
}

/// Records a visit to an entity's detail screen when it appears.
struct RecordsHistory: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    var kind: BrowsingRecord.Kind
    var id: String

    func body(content: Content) -> some View {
        content.task(id: id) {
            History.record(kind, id: id, in: modelContext)
        }
    }
}

extension View {
    func recordsHistory(_ kind: BrowsingRecord.Kind, id: String) -> some View {
        modifier(RecordsHistory(kind: kind, id: id))
    }
}
