//
//  BattleArchiveStore.swift
//  Scope Lens
//
//  Phase 3, m13-C: battle persistence — the first stop on the backlog's
//  agreed dev queue (battle archive → eval set → playbooks). The spec's
//  stated purpose is LEARNING, and until now every log, matchup, and
//  advice trace vanished when the window closed. One JSON record per
//  battle lands in Application Support/BattleArchive/; the Battle Archive
//  window (⇧⌘A) lists and replays them.
//
//  The records double as the raw material for the eval-set milestone:
//  each AdviceEntry is a decision point — board context (via the log),
//  the committed play, and the engine checks behind it.
//

import Foundation

/// One archived battle: metadata + the full narrated log + every advisor
/// decision point. Codable DTOs only — UI types (AdvisorPlay etc.) are
/// flattened to display strings at capture time so the archive schema
/// stays stable even if the live types evolve.
nonisolated public struct BattleRecord: Codable, Identifiable, Sendable {

    /// One engine check from an advice loop's why-trace.
    nonisolated public struct TraceEntry: Codable, Sendable {
        public let tool: String
        public let input: String
        public let result: String
        public let isError: Bool
    }

    /// One decision point: what the advisor said for a turn.
    nonisolated public struct AdviceEntry: Codable, Sendable, Identifiable {
        public let turn: Int
        public let askedAt: Date
        public let text: String
        /// Pre-rendered play lines ("Charizard: Heat Wave → Gengar · Mega
        /// Evolve — watch for Protect"); empty = prose-only answer.
        public let playLines: [String]
        public let thoughts: [String]
        public let trace: [TraceEntry]
        public let meta: String?          // "2 round-trips · 3 checks · 9.1s"
        // m15-A: the eval supply. All optional-with-default so pre-m15
        // records (and the memberwise init's existing call sites) are
        // untouched. verdict/verdictNote are the pilot's 👍/👎 labels,
        // written after the fact via BattleArchiveStore.setVerdict; the
        // contexts are the EXACT prompt blocks this ask sent, so the eval
        // harness can replay the decision byte-for-byte.
        public var verdict: String? = nil       // "good" | "bad"
        public var verdictNote: String? = nil   // pilot's one-liner, optional
        public var staticContext: String? = nil
        public var turnContext: String? = nil
        public var model: String? = nil   // model id that answered
        // m15-B: the structured play (not just display lines), the board
        // facts it was checked against, and what the lint said — together
        // they make every archived decision re-lintable offline, forever.
        public var play: AdvisorPlay? = nil
        public var lintContext: LintContext? = nil
        public var lintFindings: [PlayLint.Finding]? = nil
        public var id: Date { askedAt }
    }

    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    /// The reconciler's outcome ("won — opponent's team fainted", …) or
    /// "abandoned" (battle replaced/reset before a result was seen).
    public let outcome: String
    public let turns: Int
    public let yourTeam: [String]
    public let opponentSpecies: [String]
    /// Final per-side summary lines (the Battle Log header block).
    public let stateLines: [String]
    /// The full narrated log, exactly as the Battle Log renders it.
    public let logMarkdown: String
    /// The m12-A preview scout's recommendation, when one was asked.
    public let previewAdvice: String?
    public let previewAdviceMeta: String?
    /// Decision points in ask order (a turn can appear twice: a late
    /// answer for turn N followed by the re-ask for turn N+1).
    public var advice: [AdviceEntry]
    /// m15-A: which build watched this battle (stale-instance discipline —
    /// "was this played on the fixed build?" answered from the record).
    public var appBuild: String? = nil

    public var isWin: Bool { outcome.hasPrefix("won") }
    public var isAbandoned: Bool { outcome == "abandoned" }
}

/// Disk store: one pretty-printed JSON per battle under Application
/// Support/BattleArchive/. List/decode is cheap at pilot scale (a ranked
/// session is tens of battles; records are a few KB of text each).
nonisolated public enum BattleArchiveStore {

    /// Posted (on any thread) after a record is saved or deleted, so an
    /// open archive window refreshes live.
    public static let changed = Notification.Name("BattleArchiveStore.changed")

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("BattleArchive", isDirectory: true)
    }

    private static func url(for id: UUID, startedAt: Date) -> URL {
        // Sortable-by-name on disk; the UUID suffix keeps names unique.
        let stamp = ISO8601DateFormatter().string(from: startedAt)
            .replacingOccurrences(of: ":", with: "-")
        return directory.appendingPathComponent(
            "\(stamp)-\(id.uuidString.prefix(8)).json")
    }

    private static func coder() -> (JSONEncoder, JSONDecoder) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return (enc, dec)
    }

    /// Write a record (atomic; creates the directory on first use).
    /// Returns false on any I/O failure — archiving must never take the
    /// live tracker down with it.
    @discardableResult
    public static func save(_ record: BattleRecord) -> Bool {
        let (enc, _) = coder()
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let data = try enc.encode(record)
            try data.write(to: url(for: record.id, startedAt: record.startedAt),
                           options: .atomic)
            NotificationCenter.default.post(name: changed, object: nil)
            return true
        } catch {
            return false
        }
    }

    /// All archived battles, newest first. Unreadable files are skipped,
    /// not fatal (a half-written record from a crash shouldn't hide the
    /// rest of the archive).
    public static func list() -> [BattleRecord] {
        let (_, dec) = coder()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? dec.decode(BattleRecord.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// Remove one battle's record (the archive window's Delete).
    public static func delete(_ record: BattleRecord) {
        try? FileManager.default.removeItem(
            at: url(for: record.id, startedAt: record.startedAt))
        NotificationCenter.default.post(name: changed, object: nil)
    }

    /// m15-A: persist the pilot's verdict on one decision point.
    /// Decode-mutate-rewrite from DISK (never a view's possibly-stale
    /// copy): records are single JSON files, so the whole record re-saves.
    /// The entry is identified by its askedAt (AdviceEntry.id). Passing
    /// verdict nil clears the label. Returns the updated record so the
    /// caller can refresh in place; nil if the record or entry is gone.
    @discardableResult
    public static func setVerdict(recordID: UUID, askedAt: Date,
                                  verdict: String?, note: String?) -> BattleRecord? {
        guard var record = list().first(where: { $0.id == recordID }),
              let index = record.advice.firstIndex(where: { $0.askedAt == askedAt })
        else { return nil }
        record.advice[index].verdict = verdict
        record.advice[index].verdictNote = (note?.isEmpty == true) ? nil : note
        guard save(record) else { return nil }
        return record
    }
}
