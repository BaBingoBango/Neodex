//
//  TeamManager.swift
//  Scope Lens
//
//  Phase 3, m9: app-side ownership of the pilot's team. Persists the
//  imported team as JSON in Application Support (sandbox container), falls
//  back to the bundled default paste (Resources/Team/default-team.txt — the
//  same file the CLI harnesses read from the repo, so app and diagnostics
//  agree by construction), and feeds every consumer:
//
//    - Settings ⌘, Team tab (import/edit/revert)          — main actor
//    - scout report + live matchup + advisor context      — main actor
//    - the capture loop's reconciler seeds (detached task) — via Feed
//
//  APP-ONLY file: uses Bundle.module; never compiled into Diagnostics.
//

import Foundation
import Combine

@MainActor
public final class TeamManager: ObservableObject {

    public static let shared = TeamManager()

    /// Posted after the team changes (import or revert). The live tracker
    /// invalidates its scout/matchup caches; reconciler seeds naturally
    /// apply from the next battle.
    nonisolated static let teamChanged = Notification.Name("ScopeLensTeamChanged")

    @Published public private(set) var team: Team
    @Published public private(set) var lastIssues: [TeamIssue] = []
    /// Non-nil when persistence/bundle loading hit a real problem.
    @Published public private(set) var storageError: String?

    let vocab: TeamVocab?

    // MARK: Cross-actor snapshot for the capture loop

    /// The capture loop runs detached from the main actor; it reads the
    /// team through this lock-protected box instead of hopping actors
    /// mid-frame.
    nonisolated final class Feed: @unchecked Sendable {
        static let shared = Feed()
        private let lock = NSLock()
        private var _seeds: [BattleReconciler.TeamSeed] = []
        private var _specsByIdentity: [String: MonSpec] = [:]

        fileprivate func update(seeds: [BattleReconciler.TeamSeed],
                                specs: [String: MonSpec]) {
            lock.lock(); defer { lock.unlock() }
            _seeds = seeds
            _specsByIdentity = specs
        }
        /// Reconciler seeds for a NEW battle (species + on-screen name).
        func reconcilerSeeds() -> [BattleReconciler.TeamSeed] {
            lock.lock(); defer { lock.unlock() }
            return _seeds
        }
        /// m12-B: the configured slot for a damage-inference defender —
        /// same identity keys as membersByIdentity (species / display /
        /// nickname, lowercased), readable from the detached poll loop
        /// without a main-actor hop.
        func monSpec(forIdentity key: String) -> MonSpec? {
            lock.lock(); defer { lock.unlock() }
            return _specsByIdentity[key.lowercased()]
        }
    }

    // MARK: Init + storage

    private static var storeURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("team.json")
    }

    private init() {
        vocab = Bundle.scopeLens.url(forResource: "vocab", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? TeamVocab(vocabJSON: $0) }

        if let data = try? Data(contentsOf: Self.storeURL),
           let saved = try? JSONDecoder().decode(Team.self, from: data) {
            team = saved
        } else if let bundled = Self.bundledDefault(vocab: vocab) {
            team = bundled
        } else {
            team = Team(members: [])
            storageError = "No saved team and the bundled default is missing."
        }
        pushFeed()
    }

    private static func bundledDefault(vocab: TeamVocab?) -> Team? {
        guard let url = Bundle.scopeLens.url(forResource: "default-team", withExtension: "txt"),
              let paste = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let parsed = ShowdownPaste.parse(paste)
        guard let vocab else { return parsed }
        return parsed.canonicalized(with: vocab).team
    }

    // MARK: Mutations

    /// Parse + validate + (if error-free) adopt and persist a Showdown
    /// paste. Returns the issues either way so the UI can show them.
    @discardableResult
    public func importPaste(_ paste: String) -> [TeamIssue] {
        let parsed = ShowdownPaste.parse(paste)
        let (canonical, issues): (Team, [TeamIssue])
        if let vocab {
            (canonical, issues) = parsed.canonicalized(with: vocab)
        } else {
            (canonical, issues) = (parsed, [TeamIssue(.warning,
                "vocab.json unavailable — imported without name validation")])
        }
        lastIssues = issues
        guard !issues.contains(where: { $0.severity == .error }) else { return issues }
        adopt(canonical)
        return issues
    }

    /// Throw away the saved team and return to the bundled default.
    public func revertToDefault() {
        guard let bundled = Self.bundledDefault(vocab: vocab) else {
            storageError = "Bundled default team is missing."
            return
        }
        lastIssues = []
        adopt(bundled)
    }

    private func adopt(_ newTeam: Team) {
        team = newTeam
        persist()
        pushFeed()
        NotificationCenter.default.post(name: Self.teamChanged, object: nil)
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(team).write(to: Self.storeURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "Could not save team: \(error.localizedDescription)"
        }
    }

    private func pushFeed() {
        var specs: [String: MonSpec] = [:]
        for m in team.members {
            specs[m.species.lowercased()] = m.monSpec
            specs[m.displayName(vocab: vocab).lowercased()] = m.monSpec
            if let nick = m.nickname { specs[nick.lowercased()] = m.monSpec }
        }
        Feed.shared.update(seeds: team.teamSeeds(vocab: vocab).map {
            BattleReconciler.TeamSeed(species: $0.species, display: $0.display)
        }, specs: specs)
    }

    // MARK: Engine-facing views (main-actor consumers)

    /// Scout-report inputs: every configured slot as an engine MonSpec.
    var monSpecs: [MonSpec] { team.members.map(\.monSpec) }

    /// Live-matchup merge: configured slot by canonical species, display
    /// name, or nickname (all lowercased) — whatever the reconciler binds.
    var membersByIdentity: [String: TeamMember] {
        var out: [String: TeamMember] = [:]
        for m in team.members {
            out[m.species.lowercased()] = m
            out[m.displayName(vocab: vocab).lowercased()] = m
            if let nick = m.nickname { out[nick.lowercased()] = m }
        }
        return out
    }
}
