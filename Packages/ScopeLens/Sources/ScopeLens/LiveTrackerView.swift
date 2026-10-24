//
//  LiveTrackerView.swift
//  Scope Lens
//
//  Phase 2, milestone 2: the in-app live tracker debug panel. Watches the
//  QuickTime mirror through MirrorCaptureSource, classifies each sampled frame
//  with ScreenStateClassifier, and shows the live state, overlays, confidence,
//  a viewport preview, and a rolling transition log.
//
//  This panel is the app-side twin of Tools/ScopeLensDiagnostics/LiveCaptureProbe's `stream`
//  mode: raw per-sample truth, no debouncing — the BattleState layer will own
//  smoothing when it lands.
//

import SwiftUI
import Combine
import ScreenCaptureKit

// MARK: - Model

/// Serializes lazy engine load + JSC calls off the main actor.
actor ScoutEngineBox {
    private var engine: ScoutEngine?
    private var executor: AdvisorToolExecutor?
    private func loaded() throws -> ScoutEngine {
        if engine == nil {
            engine = try ScoutEngine.bundled()
            // m11-C: a refreshed snapshot in App Support outranks the
            // bundled one (the committed snapshot stays the harness pin).
            if let cached = MetaStore.cachedMetaData() {
                try? engine!.setMeta(cached)
            }
        }
        return engine!
    }

    /// Hot-swap after a Settings refresh (or revert): nil re-applies the
    /// bundled snapshot by rebuilding the engine lazily on next use.
    func reloadMeta(_ data: Data?) {
        if let data, let engine {
            try? engine.setMeta(data)
        } else if data == nil {
            engine = nil        // next call rebuilds from the bundle
            executor = nil
        }
    }
    func report(mine: [MonSpec], theirs: [String]) throws -> ScoutReportData {
        try loaded().report(mine: mine, theirs: theirs)
    }
    func liveMatchup(mine: [MonSpec], theirs: [MonSpec],
                     field: LiveFieldSpec) throws -> LiveMatchupData {
        try loaded().liveMatchup(mine: mine, theirs: theirs, field: field)
    }

    // m11: the agentic advisor's tool surface — same engine, same actor.

    private func loadedExecutor(team: [MonSpec]) throws -> AdvisorToolExecutor {
        if executor == nil {
            executor = AdvisorToolExecutor(
                engine: try loaded(),
                vocabulary: try BattleVocabulary.bundled(),
                configuredTeam: team)
        } else {
            executor!.configuredTeam = team
        }
        return executor!
    }

    /// Execute a batch of the model's tool calls (milliseconds — local JSC).
    func runTools(_ calls: [AdvisorToolCall], team: [MonSpec]) -> [AdvisorToolResult] {
        guard let ex = try? loadedExecutor(team: team) else {
            return calls.map {
                AdvisorToolResult(id: $0.id, text: "Error: engine unavailable", isError: true)
            }
        }
        return calls.map {
            let r = ex.execute(name: $0.name, arguments: $0.input)
            return AdvisorToolResult(id: $0.id, text: r.text, isError: r.isError)
        }
    }

    /// Battle-static meta capsules for the opponent's preview species.
    func capsules(species: [String], team: [MonSpec]) throws -> [OpponentCapsule] {
        try loadedExecutor(team: team).buildCapsules(species: species)
    }

    /// m12-B: reverse damage inference against the same engine.
    func inferAttack(_ input: [String: Any]) throws -> [String: Any] {
        try loaded().inferAttack(input) ?? [:]
    }

    /// m12-C: capsules + dex effect text composed into per-opponent
    /// dossiers, in the caller's display order (actives first).
    func dossiers(for ordered: [(species: String, active: Bool)],
                  team: [MonSpec]) throws -> [OpponentDossier] {
        try OpponentDossier.build(ordered: ordered,
                                  executor: loadedExecutor(team: team))
    }

    /// m12-C+: your team's type matchups (base + mega-changed typing) for
    /// the dossier window's switch-decision card. `team` keeps the
    /// executor's configured-team default intact (never pass a stub).
    func teamTypes(members: [TeamMember], activeKeys: Set<String>,
                   team: [MonSpec]) throws -> [TeamTypeEntry] {
        TeamTypeEntry.build(members: members, activeKeys: activeKeys,
                            executor: try loadedExecutor(team: team))
    }
}

@MainActor
public final class LiveTrackerModel: ObservableObject {

    /// Shared instance so the Live Tracker and Scout Report windows observe
    /// the same live state. TODO: proper scene-level injection when the app
    /// grows beyond debug windows.
    public static let shared = LiveTrackerModel()

    struct TransitionEntry: Identifiable {
        let id = UUID()
        let time: Date
        let from: String
        let to: String
        let confidence: Double
    }

    @Published private(set) var isRunning = false
    @Published private(set) var statusLine = "Idle — press Start with the QuickTime mirror up."
    @Published private(set) var windowLine = ""
    @Published private(set) var current: ScreenStateClassification?
    @Published private(set) var previewImage: CGImage?
    @Published private(set) var transitions: [TransitionEntry] = []
    /// Frame-voted opponent team read, live while a team preview is on screen.
    @Published private(set) var opponentRead: [PreviewAggregate.RowConsensus] = []
    @Published private(set) var opponentSprites: [Int: CGImage] = [:]
    @Published private(set) var opponentFrameCount = 0
    /// Structured scout report computed from the consensus (+ confirm-taps).
    @Published private(set) var scoutReport: ScoutReportData?
    @Published private(set) var scoutStatus: String?
    @Published private(set) var speciesOverrides: [Int: String] = [:]
    /// The matcher's closed species vocabulary (bundled index), for the
    /// manual-entry picker (BACKLOG P1). Static data, loaded on first use.
    private(set) lazy var previewSpeciesUniverse: [String] =
        PreviewPipeline.bundledSpeciesNames()

    // Battle log (m5b): the live twin of the m4 paper replay.
    @Published private(set) var battleEvents: [BattleEvent] = []
    @Published private(set) var battleStateLines: [String] = []
    @Published private(set) var battleOutcome: String?
    @Published private(set) var battleLogMarkdown: String = ""
    private var battleResetRequested = false
    /// m13-D: unresolved nicknamed opponents + candidate species — non-nil
    /// drives the Battle Log's bind card ("Toucan sam is…").
    @Published private(set) var nicknameBinds: BattleReconciler.NicknameBindState?
    private var pendingNicknameBinds: [(display: String, species: String)] = []
    /// m14-A: the notepad board — every observed fact per mon, both sides
    /// (opponent rendered in the Battle Log; ghosts = unseen preview rows).
    @Published private(set) var battleRoster: [BattleReconciler.RosterEntry] = []

    // Live matchup (Phase 3 m7): damage both ways for the CURRENT actives.
    @Published private(set) var liveMatchup: LiveMatchupData?
    private var lastMatchupSignature = ""

    // Preview scout (m12-A): the agentic "what do I bring" layer over the
    // same tool loop. Deterministic safe_four stays always-on (two-speed
    // doctrine §4.1); this is the toggle-on layer.
    @Published private(set) var previewAdviceText: String?
    @Published private(set) var previewAdviceStatus: String?
    @Published private(set) var previewAdviceTrace: [AdvisorTraceEntry] = []
    @Published private(set) var previewAdviceMeta: String?
    /// Live loop readout (m12-E): streamed thinking, tool calls forming,
    /// round-trip markers — non-empty only while an ask is in flight.
    @Published private(set) var previewAdviceProgress: [String] = []
    /// The loop's thinking summaries, for the post-hoc why-trace.
    @Published private(set) var previewAdviceThoughts: [String] = []
    /// Ask automatically once per preview when the consensus stabilizes
    /// (default OFF — each ask is an API call on the pilot's key).
    @Published var autoPreviewScout = false
    private var previewAdviceInFlight = false
    private var previewAdviceAskedForThisPreview = false

    // Opponent dossiers (m12-C): capsules + plain-English effect text for
    // every opponent ScopeLens currently knows — the ⇧⌘K window's feed.
    @Published private(set) var dossiers: [OpponentDossier] = []
    /// Your team's type matchups (m12-C+): the same window's
    /// switch-decision card — actives flagged mid-battle.
    @Published private(set) var teamTypes: [TeamTypeEntry] = []
    private var lastDossierSignature = ""

    // "What's the play" advisor (Phase 3 m8; agentic since m11): opt-in LLM layer.
    @Published private(set) var adviceText: String?
    @Published private(set) var adviceStatus: String?
    @Published private(set) var adviceTurn: Int?
    /// The "why" trace (m11): which engine tools the advisor consulted.
    @Published private(set) var adviceTrace: [AdvisorTraceEntry] = []
    /// One-line loop stats for the UI footer ("2 round-trips · 3 checks · 9.1s").
    @Published private(set) var adviceMeta: String?
    /// Live loop readout (m12-E) — non-empty only while an ask is in flight.
    @Published private(set) var adviceProgress: [String] = []
    /// Thinking summaries from the last answered ask (why-trace 🧠 lines).
    @Published private(set) var adviceThoughts: [String] = []
    /// The committed per-active decision (m12-F) — chips above the prose.
    @Published private(set) var advicePlay: AdvisorPlay?
    /// m15-C: UNRESOLVED rule violations on the shown play (the model was
    /// bounced once and still committed them) — rendered in orange under
    /// the chips so the pilot knows the play breaks a deterministic rule.
    @Published private(set) var adviceLintWarnings: [String] = []
    @Published var autoAdvise = false
    /// The reconciler's current turn, published so the advice card can mark
    /// a play that outlived its turn (BACKLOG P2 belt-and-braces).
    @Published private(set) var battleTurn = 0
    private var adviceInFlight = false
    private var lastAdvisedTurn = -1
    /// True while adviceStatus shows the turn-change prompt ("Turn N — ask
    /// for the play."), so the next turn's curtain refreshes it.
    private var advicePromptShown = false
    /// Published for the overlay HUD (m10-A): perish clocks + active HP chips.
    @Published private(set) var advisorSnapshots: [BattleReconciler.ActiveSnapshot] = []
    private var advisorField = LiveFieldSpec()
    private var advisorState = BattleState()

    // Battle archive (m13-C): everything a battle showed us, persisted at
    // its end — the spec's learning purpose needs a review surface.
    private var battleStartedAt: Date?
    private var battleArchived = false
    private var adviceLog: [BattleRecord.AdviceEntry] = []
    private var archivedPreviewAdvice: (text: String, meta: String?)?

    private var lastConsensusTop1: [Int: String] = [:]
    private let engineBox = ScoutEngineBox()
    private var teamChangeCancellable: AnyCancellable?
    private var metaChangeCancellable: AnyCancellable?

    private init() {
        // Team edits (Settings ⌘, → Team) invalidate the engine-facing
        // caches immediately; reconciler seeds refresh at the next battle.
        teamChangeCancellable = NotificationCenter.default
            .publisher(for: TeamManager.teamChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.handleTeamChange() }
            }
        // Meta refresh (Settings ⌘, → Meta): hot-swap the engine snapshot
        // and recompute everything usage-priors touch (m11-C).
        metaChangeCancellable = NotificationCenter.default
            .publisher(for: MetaStore.metaChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.handleMetaChange() }
            }
        // m12-C+: the your-team type card is useful before any capture
        // starts — compute it up front (engine loads lazily, off-main).
        recomputeDossiersIfNeeded(force: true)
    }

    private func handleMetaChange() {
        let cached = MetaStore.cachedMetaData()
        Task { [engineBox] in
            await engineBox.reloadMeta(cached)
            await MainActor.run { [weak self] in self?.handleTeamChange() }
        }
    }

    private func handleTeamChange() {
        lastMatchupSignature = ""
        recomputeScoutReport()
        recomputeDossiersIfNeeded(force: true)   // usage %s may have moved (m12-C)
        if !advisorSnapshots.isEmpty {
            recomputeMatchupIfNeeded(snapshots: advisorSnapshots,
                                     field: advisorField, state: advisorState)
        }
    }

    /// Sampling cadence. 2 fps matches the validated offline profile.
    let fps: Double = 2.0
    /// OCR downscale — 0.5 is harness-validated on all fixtures.
    private let ocrScale: CGFloat = 0.5
    private let maxLogEntries = 200

    private var pollTask: Task<Void, Never>?
    private var lastPrimaryRaw: String?

    func start() {
        guard pollTask == nil else { return }
        isRunning = true
        statusLine = "Looking for the QuickTime mirror window…"
        let interval = 1.0 / fps
        let scale = ocrScale

        pollTask = Task.detached(priority: .userInitiated) { [weak self] in
            let classifier = ScreenStateClassifier()
            let observer = VisionFrameObserver()
            // Preview pipeline is heavyweight (bundled references) — lazy-load
            // on the first teamPreview sighting, then keep for the session.
            var previewPipeline: PreviewPipeline?
            var aggregate = PreviewAggregate()
            var lastPreviewRun = Date.distantPast
            var lastPreviewSeen = Date.distantPast

            // Battle-state layer (m5b): one reconciler per battle, fed from
            // the SAME OCR pass the classifier uses — no extra Vision cost.
            let vocabulary = try? BattleVocabulary.bundled()
            let parser = vocabulary.map { BattleEventParser(vocabulary: $0) }
            var reconciler: BattleReconciler?
            var battleEpoch = Date()
            var publishedBattleSignature = ""

            func freshReconciler() -> BattleReconciler? {
                guard let vocabulary else { return nil }
                battleEpoch = Date()
                publishedBattleSignature = ""
                // Seeds come from the configured team (m9), read through the
                // lock-protected feed — this loop is detached from the main
                // actor. A team edited mid-session applies from the next
                // battle, which is when seeds are consumed anyway.
                return BattleReconciler(
                    vocabulary: vocabulary,
                    yourTeam: TeamManager.Feed.shared.reconcilerSeeds())
            }

            while let self, !Task.isCancelled {
                let tick = Date()
                do {
                    // Re-resolve the window each cycle: cheap, and survives the
                    // mirror window being closed/reopened or resized (viewport
                    // is re-detected per frame — full-window mirrors make this
                    // nearly free; revisit if a chrome-heavy source appears).
                    let windows = try await MirrorCapture.shareableWindows()
                    guard let (window, info) = MirrorCapture.findQuickTimeMirror(in: windows) else {
                        await self.publishStatus("No QuickTime window found — is the mirror up?", windowLine: "")
                        try await Task.sleep(nanoseconds: 1_500_000_000)
                        continue
                    }

                    let frame = try await MirrorCapture.captureOnce(window)
                    guard let viewport = ViewportDetector.detect(in: frame),
                          let cropped = frame.cropping(to: viewport) else {
                        await self.publishStatus("Viewport not found — waiting for content…",
                                                 windowLine: Self.describe(info))
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        continue
                    }

                    let ocrInput = cropped.scopeScaled(by: scale) ?? cropped
                    let tokens = try observer.observe(ocrInput)
                    let result = classifier.classify(tokens: tokens)
                    await self.publish(result: result, preview: cropped, info: info)

                    // ---- battle-state layer -----------------------------
                    if let parser {
                        if await self.consumeBattleReset() {
                            // Mid-battle Reset semantics (m11-B, battle 7):
                            // the fresh reconciler re-bootstraps cleanly, and
                            // if THIS battle's preview had already seeded,
                            // the same consensus re-applies immediately — no
                            // nickname-only degradation, no phantom carry-over.
                            let hadSeeds = reconciler?.hasPreviewSeed ?? false
                            reconciler = freshReconciler()
                            if hadSeeds, let reconciler,
                               aggregate.frameCount >= 5, aggregate.consensus.count == 6,
                               aggregate.consensus.allSatisfy({ !$0.speciesTop.isEmpty }) {
                                reconciler.seedPreview(aggregate.consensus.map {
                                    .init(row: $0.row,
                                          speciesTop: $0.speciesTop.map(\.name),
                                          types: $0.typePair)
                                }, t: 0)
                            }
                        }
                        // A finished battle followed by a fresh preview means
                        // a NEW battle — start clean.
                        if let r = reconciler, r.outcome != nil, result.primary == .teamPreview {
                            reconciler = freshReconciler()
                        }
                        if reconciler == nil { reconciler = freshReconciler() }
                        if let reconciler {
                            let t = Date().timeIntervalSince(battleEpoch)
                            // m13-D: pilot binds queued from the Battle Log
                            // card apply before this tick's observations.
                            for bind in await self.consumeNicknameBinds() {
                                reconciler.bindNickname(displayName: bind.display,
                                                        species: bind.species, t: t)
                            }
                            reconciler.ingest(parser.observe(
                                tokens: tokens, classification: result, t: t))
                            // m12-B: settled damage observations → engine
                            // inference → verdicts, all BEFORE this tick
                            // publishes (the 🔎 event and its verdict land
                            // atomically; JSC answers in milliseconds).
                            for obs in reconciler.drainPendingInferences() {
                                if let summary = await self.inferVerdict(for: obs) {
                                    reconciler.recordInferenceVerdict(for: obs, summary: summary)
                                }
                            }
                            // Count + last value: HP coalescing edits the tail
                            // event IN PLACE, which must still re-publish.
                            let signature = "\(reconciler.events.count)|\(reconciler.events.last?.value ?? "")"
                            if signature != publishedBattleSignature {
                                publishedBattleSignature = signature
                                await self.publishBattle(
                                    events: reconciler.events,
                                    stateLines: Self.summarize(reconciler.state),
                                    outcome: reconciler.outcome,
                                    markdown: reconciler.renderLog(title: "Live battle"),
                                    nickBinds: reconciler.nicknameBindState(),
                                    roster: reconciler.rosterSnapshots())
                                await self.recomputeMatchupIfNeeded(
                                    snapshots: reconciler.activeSnapshots(),
                                    field: reconciler.liveFieldSpec(),
                                    state: reconciler.state)
                            }
                        }
                    }

                    // Team-preview frames additionally feed the opponent-read
                    // pipeline (full-res crop; throttled — voting needs a
                    // handful of good frames, not every tick).
                    if result.primary == .teamPreview,
                       Date().timeIntervalSince(lastPreviewRun) >= 1.0 {
                        lastPreviewRun = Date()
                        if await self.consumePipelineReload() { previewPipeline = nil }
                        if previewPipeline == nil {
                            previewPipeline = try? PreviewPipeline.bundled(
                                nativeOverlayJSON: NativeReferenceStore.overlayData())
                        }
                        // A preview seen after a long gap is a NEW battle.
                        if Date().timeIntervalSince(lastPreviewSeen) > 60 {
                            aggregate = PreviewAggregate()
                            if reconciler?.events.isEmpty == false {
                                reconciler = freshReconciler()
                            }
                        }
                        lastPreviewSeen = Date()
                        if let read = previewPipeline?.read(frame: cropped) {
                            aggregate.add(read)
                            var sprites: [Int: CGImage] = [:]
                            for r in read.rows { sprites[r.row] = r.spriteCrop }
                            await self.publishOpponentRead(aggregate.consensus,
                                                           sprites: sprites,
                                                           frames: aggregate.frameCount)
                        }
                        // Seed the reconciler's opponent bench once the vote
                        // stabilizes — and KEEP re-seeding while the preview
                        // is up: early votes are laser-degraded (battle 4's
                        // Scrafty froze as "Krokorok" under a 5-frame seed).
                        // seedPreview refines in place; bindings only happen
                        // once the battle starts.
                        if aggregate.frameCount >= 5,
                           let reconciler, aggregate.consensus.count == 6,
                           aggregate.consensus.allSatisfy({ !$0.speciesTop.isEmpty }) {
                            reconciler.seedPreview(aggregate.consensus.map {
                                .init(row: $0.row,
                                      speciesTop: $0.speciesTop.map(\.name),
                                      types: $0.typePair)
                            }, t: Date().timeIntervalSince(battleEpoch))
                        }
                    }
                } catch {
                    await self.publishStatus("Capture error: \(error.localizedDescription) — retrying…",
                                             windowLine: "")
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }

                let elapsed = Date().timeIntervalSince(tick)
                if elapsed < interval {
                    try? await Task.sleep(nanoseconds: UInt64((interval - elapsed) * 1e9))
                }
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        isRunning = false
        statusLine = "Stopped."
    }

    // MARK: publishing (main actor)

    private func publishStatus(_ status: String, windowLine: String) {
        self.statusLine = status
        self.windowLine = windowLine
    }

    private func publishOpponentRead(_ consensus: [PreviewAggregate.RowConsensus],
                                     sprites: [Int: CGImage], frames: Int) {
        if frames < opponentFrameCount {   // new battle's preview
            bankedTapRows.removeAll()
            clearPreviewAdvice()           // m12-A: the scout is per-preview
        }
        opponentRead = consensus
        opponentFrameCount = frames
        opponentSprites.merge(sprites) { _, new in new }
        recomputeDossiersIfNeeded()

        // A full-team consensus (with a few frames of voting behind it) drives
        // the scout report; recompute only when the voted top-1 set changes.
        guard frames >= 5, consensus.count == 6,
              consensus.allSatisfy({ !$0.speciesTop.isEmpty }) else { return }
        let top1 = Dictionary(uniqueKeysWithValues: consensus.map { ($0.row, $0.speciesTop[0].name) })
        if top1 != lastConsensusTop1 {
            lastConsensusTop1 = top1
            recomputeScoutReport()
        }
    }

    /// Confirm-tap: pin a row to a species (usually a matcher runner-up) —
    /// and BANK the row's sprite crop as a permanent native reference (m7a):
    /// the pipeline reloads with the new overlay, so even this session's
    /// later previews benefit.
    func confirmSpecies(row: Int, name: String) {
        if speciesOverrides[row] == name {
            speciesOverrides.removeValue(forKey: row)   // tap again to unpin
        } else {
            speciesOverrides[row] = name
            if !bankedTapRows.contains(row), let crop = opponentSprites[row] {
                bankedTapRows.insert(row)
                if NativeReferenceStore.bank(species: name, crop: crop) {
                    pipelineReloadRequested = true
                }
            }
        }
        recomputeScoutReport()
        recomputeDossiersIfNeeded()
    }

    private var bankedTapRows: Set<Int> = []
    private var pipelineReloadRequested = false

    private func consumePipelineReload() -> Bool {
        defer { pipelineReloadRequested = false }
        return pipelineReloadRequested
    }

    private func recomputeScoutReport() {
        let top1 = lastConsensusTop1
        guard top1.count == 6 else { return }
        let overrides = speciesOverrides
        let theirs = (0..<6).compactMap { overrides[$0] ?? top1[$0] }
        let mine = TeamManager.shared.monSpecs   // configured team (m9)
        guard !mine.isEmpty else {
            publishScout(nil, status: "No team configured — add one in Settings (⌘,).")
            return
        }
        scoutStatus = "Computing…"
        Task.detached(priority: .userInitiated) { [weak self, engineBox] in
            do {
                let report = try await engineBox.report(mine: mine, theirs: theirs)
                await self?.publishScout(report, status: nil)
            } catch {
                await self?.publishScout(nil, status: "Engine error: \(error.localizedDescription)")
            }
        }
    }

    private func publishScout(_ report: ScoutReportData?, status: String?) {
        if let report { scoutReport = report }
        scoutStatus = status
        // m12-A: auto-scout once per preview, riding the freshest heuristic
        // report (which recomputes exactly when the consensus stabilizes or
        // changes). Gated to preview time — before this battle's first event
        // or after the previous battle ended.
        if report != nil, autoPreviewScout, !previewAdviceAskedForThisPreview,
           battleEvents.isEmpty || battleOutcome != nil {
            requestPreviewAdvice()
        }
    }

    // MARK: "What do I bring" — the agentic preview scout (m12-A)

    private func clearPreviewAdvice() {
        previewAdviceAskedForThisPreview = false
        previewAdviceText = nil
        previewAdviceStatus = nil
        previewAdviceTrace = []
        previewAdviceMeta = nil
        previewAdviceProgress = []
        previewAdviceThoughts = []
    }

    /// m12-E: fold one live readout event into a progress feed (the last
    /// line updates in place while thinking/answer text streams).
    private func applyAdvisorProgress(_ p: AdvisorProgress, preview: Bool) {
        var lines = preview ? previewAdviceProgress : adviceProgress
        if p.replacesPrevious, !lines.isEmpty {
            lines[lines.count - 1] = p.line
        } else {
            lines.append(p.line)
        }
        if lines.count > 40 { lines.removeFirst(lines.count - 40) }
        if preview { previewAdviceProgress = lines } else { adviceProgress = lines }
    }

    /// One TEAM PREVIEW tool loop on the current consensus: the same
    /// battle-static capsule prefix the turn advisor uses (so this ask WARMS
    /// the cache for the battle's turn asks), with the heuristic scout
    /// report as the baseline to beat. The deterministic report stays on
    /// screen throughout — this is the toggle-on layer.
    func requestPreviewAdvice() {
        guard !previewAdviceInFlight else { return }
        guard AdvisorClient.hasKey else {
            previewAdviceStatus = "No API key — add your Anthropic key in Settings (⌘,)."
            return
        }
        guard let scout = scoutReport, lastConsensusTop1.count == 6 else {
            previewAdviceStatus = "No stable opponent read yet."
            return
        }
        previewAdviceInFlight = true
        previewAdviceAskedForThisPreview = true
        previewAdviceStatus = "Scouting…"
        previewAdviceProgress = []
        previewAdviceThoughts = []
        // Same species list the scout report used: pins beat voted top-1s.
        let top1 = lastConsensusTop1
        let overrides = speciesOverrides
        let theirs = (0..<6).compactMap { overrides[$0] ?? top1[$0] }
        let team = TeamManager.shared.team.members
        let teamVocab = TeamManager.shared.vocab
        let monSpecs = TeamManager.shared.monSpecs
        let previewContext = AdvisorContext.buildPreview(scout: scout)
        // m12-E: live readout sink — built here (strong self) so the nested
        // Task captures an immutable self, keeping Swift 6 strict-concurrency
        // clean inside the detached loop below.
        let progressSink: @Sendable (AdvisorProgress) -> Void = { [weak self] progress in
            guard let self else { return }
            Task { @MainActor in self.applyAdvisorProgress(progress, preview: true) }
        }
        Task.detached(priority: .userInitiated) { [weak self, engineBox] in
            do {
                let capsules = (try? await engineBox.capsules(species: theirs,
                                                              team: monSpecs)) ?? []
                let staticContext = AdvisorContext.buildStatic(
                    yourTeam: team, teamVocab: teamVocab, capsules: capsules)
                let tools = try AdvisorToolCatalog.bundled()
                let advice = try await AdvisorClient.forPreview().advise(
                    staticContext: staticContext, turnContext: previewContext,
                    tools: tools, volatileLabel: "TEAM PREVIEW",
                    question: AdvisorContext.previewQuestion,
                    onProgress: progressSink) { calls in
                        await engineBox.runTools(calls, team: monSpecs)
                    }
                await self?.publishPreviewAdvice(advice, status: nil)
            } catch {
                await self?.publishPreviewAdvice(nil, status: error.localizedDescription)
            }
        }
    }

    private func publishPreviewAdvice(_ advice: AgenticAdvice?, status: String?) {
        previewAdviceInFlight = false
        previewAdviceProgress = []
        if let advice {
            previewAdviceText = advice.text
            previewAdviceTrace = advice.trace
            previewAdviceThoughts = advice.thoughts
            let checks = advice.trace.filter { $0.tool != "commit_play" }.count
            previewAdviceMeta = "\(advice.iterations) round-trip\(advice.iterations == 1 ? "" : "s")"
                + (checks > 0 ? " · \(checks) engine check\(checks == 1 ? "" : "s")" : " · no checks needed")
                + String(format: " · %.1fs", advice.elapsed)
                + (advice.cacheReadTokens > 0 ? " · cache hit" : "")
            // m13-C: a scout answer landing AFTER the battle started still
            // belongs to this battle's archive (the battle-start snapshot
            // ran before the loop finished).
            if battleStartedAt != nil {
                archivedPreviewAdvice = (advice.text, previewAdviceMeta)
            }
        }
        previewAdviceStatus = status
    }

    // MARK: opponent dossiers (m12-C)

    /// Who the dossiers cover, in display order. Mid-battle the reconciler
    /// is authoritative (actives first, then bench — corroboration
    /// corrections flow in, same doctrine as the advisor's capsuleSpecies);
    /// otherwise the preview consensus, where pins beat voted top-1s.
    private func dossierSpecies() -> [(species: String, active: Bool)] {
        if !battleEvents.isEmpty, battleOutcome == nil {
            var seen = Set<String>()
            var out: [(species: String, active: Bool)] = []
            for mon in advisorState.oppSide.active where mon.speciesId != "unknown" {
                if seen.insert(mon.speciesId).inserted { out.append((mon.speciesId, true)) }
            }
            for mon in advisorState.oppSide.bench where mon.speciesId != "unknown" {
                if seen.insert(mon.speciesId).inserted { out.append((mon.speciesId, false)) }
            }
            if !out.isEmpty { return out }
        }
        return opponentRead
            .sorted { $0.row < $1.row }
            .compactMap { row in
                (speciesOverrides[row.row] ?? row.speciesTop.first?.name)
                    .map { ($0, false) }
            }
    }

    /// Your current on-field mons' identity keys (lowercased species AND
    /// display names — the membersByIdentity convention), for the ACTIVE
    /// flags on the your-team card. Empty outside a live battle.
    private func yourActiveKeys() -> Set<String> {
        guard !battleEvents.isEmpty, battleOutcome == nil else { return [] }
        var keys = Set<String>()
        for s in advisorSnapshots where s.side == "you" && s.species != "unknown" {
            keys.insert(s.species.lowercased())
            keys.insert(s.displayName.lowercased())
        }
        return keys
    }

    /// Rebuild the dossier + your-team cards when the KNOWN-mon picture
    /// changes (opponent species set, either side's active split, or a
    /// forced refresh after a team/meta swap) — not on every frame; the
    /// JSC hop is cheap but the cards should never flicker under a
    /// stable read.
    private func recomputeDossiersIfNeeded(force: Bool = false) {
        let ordered = dossierSpecies()
        let activeKeys = yourActiveKeys()
        let signature = ordered.map { "\($0.species)\($0.active ? "*" : "")" }
            .joined(separator: "|")
            + "‖you:" + activeKeys.sorted().joined(separator: "|")
        guard force || signature != lastDossierSignature else { return }
        lastDossierSignature = signature
        let members = TeamManager.shared.team.members
        let team = TeamManager.shared.monSpecs
        guard !ordered.isEmpty || !members.isEmpty else {
            dossiers = []
            teamTypes = []
            return
        }
        Task.detached(priority: .utility) { [weak self, engineBox] in
            let dossiers = ordered.isEmpty
                ? [] : (try? await engineBox.dossiers(for: ordered, team: team)) ?? []
            let teamTypes = members.isEmpty
                ? [] : (try? await engineBox.teamTypes(members: members,
                                                       activeKeys: activeKeys,
                                                       team: team)) ?? []
            await self?.publishDossiers(dossiers, teamTypes: teamTypes)
        }
    }

    private func publishDossiers(_ result: [OpponentDossier],
                                 teamTypes teamResult: [TeamTypeEntry]) {
        dossiers = result
        teamTypes = teamResult
    }

    // MARK: battle log plumbing

    /// User-requested reset (Battle Log window button); consumed by the poll loop.
    func resetBattleLog() {
        // m13-C: a Reset can be discarding a real battle (battle 8's
        // forfeit was exactly this shape) — archive it first; the ≥8-event
        // bar keeps accidental resets out of the archive.
        archiveCurrentBattle()
        endBattleSession()
        battleResetRequested = true
        battleEvents = []
        battleStateLines = []
        battleOutcome = nil
        battleLogMarkdown = ""
        nicknameBinds = nil
        pendingNicknameBinds = []
        battleRoster = []
        adviceText = nil
        adviceStatus = nil
        adviceTurn = nil
        adviceTrace = []
        adviceMeta = nil
        adviceProgress = []
        adviceThoughts = []
        advicePlay = nil
        adviceLintWarnings = []
        battleTurn = 0
        lastAdvisedTurn = -1
        advicePromptShown = false
        clearPreviewAdvice()
        recomputeDossiersIfNeeded()   // source flips back to the preview read
    }

    private func consumeBattleReset() -> Bool {
        defer { battleResetRequested = false }
        return battleResetRequested
    }

    /// m13-D: pilot bind from the Battle Log card ("Toucan sam is…
    /// Toucannon"). Queued here, consumed by the poll loop (the reconciler
    /// lives on the capture task), applied before the next ingest — the
    /// resolved identity publishes on the same tick.
    func bindNickname(display: String, species: String) {
        pendingNicknameBinds.append((display, species))
    }

    private func consumeNicknameBinds() -> [(display: String, species: String)] {
        defer { pendingNicknameBinds = [] }
        return pendingNicknameBinds
    }

    /// m12-B: one damage observation → engine hypothesis grid → verdict
    /// summary (nil = engine skipped it: spread slipped the reconciler's
    /// both-fell gate, unknown species, …). Nonisolated — runs on the poll
    /// task, reading the team through the lock-protected Feed (the m9
    /// no-actor-hop doctrine).
    nonisolated private func inferVerdict(
        for obs: BattleReconciler.DamageObservation) async -> String? {
        // Defender = our mon: the configured slot (spread ground truth)
        // with the mega-resolved species and the observed live extras.
        var defender: [String: Any]
        if let member = TeamManager.Feed.shared.monSpec(forIdentity: obs.defenderSpecies)
            ?? TeamManager.Feed.shared.monSpec(forIdentity: obs.defenderDisplay) {
            defender = member.asDictionary
        } else {
            defender = [:]
        }
        defender["species"] = obs.defenderSpecies
        if !obs.defenderBoosts.isEmpty { defender["boosts"] = obs.defenderBoosts }
        if let status = obs.defenderStatus { defender["status"] = status }

        var field: [String: Any] = [:]
        if let w = obs.field.weather { field["weather"] = w }
        if !obs.field.screensYou.isEmpty { field["screensYou"] = obs.field.screensYou }

        var input: [String: Any] = [
            "attacker": obs.attackerSpecies,
            "move": obs.move,
            "defender": defender,
            "observedDamage": obs.observedDamage,
            "field": field,
        ]
        if !obs.attackerBoosts.isEmpty { input["attackerBoosts"] = obs.attackerBoosts }
        if obs.attackerMega { input["mega"] = true }

        guard let result = try? await engineBox.inferAttack(input),
              result["skipped"] == nil,
              result["conclusive"] as? Bool == true else { return nil }
        return result["summary"] as? String
    }

    private func publishBattle(events: [BattleEvent], stateLines: [String],
                               outcome: String?, markdown: String,
                               nickBinds: BattleReconciler.NicknameBindState? = nil,
                               roster: [BattleReconciler.RosterEntry] = []) {
        // m13-C battle boundaries. A shrinking log means a fresh reconciler
        // replaced this battle (next preview after a result, or a >60s
        // preview gap) — archive what we watched BEFORE the new battle
        // overwrites the published state. Mid-battle Reset archives in
        // resetBattleLog instead (the log is cleared there, not shrunk).
        if !battleEvents.isEmpty, events.count < battleEvents.count {
            archiveCurrentBattle()
            endBattleSession()
        }
        if battleStartedAt == nil, !events.isEmpty {
            battleStartedAt = Date()
            // The preview scout answered before the battle started (its
            // published fields survive until the NEXT preview clears them).
            archivedPreviewAdvice = previewAdviceText.map { ($0, previewAdviceMeta) }
        }
        battleEvents = events
        battleStateLines = stateLines
        battleOutcome = outcome
        battleLogMarkdown = markdown
        nicknameBinds = nickBinds
        battleRoster = roster
        // The clean boundary: the outcome banner landed. Archive with the
        // final log/state; battleArchived keeps later publishes (and the
        // next battle's shrink check) from double-saving.
        if outcome != nil { archiveCurrentBattle() }
    }

    // MARK: battle archive (m13-C)

    /// Persist the CURRENT published battle. Completed battles always
    /// archive; an unfinished one needs a real log behind it (≥8 events)
    /// so classifier misfires and accidental Resets don't clutter the
    /// archive. Failures are silent by design — archiving must never take
    /// the live tracker down with it.
    private func archiveCurrentBattle() {
        guard !battleArchived, !battleEvents.isEmpty else { return }
        guard battleOutcome != nil || battleEvents.count >= 8 else { return }
        battleArchived = true
        let record = BattleRecord(
            id: UUID(),
            startedAt: battleStartedAt ?? Date(),
            endedAt: Date(),
            outcome: battleOutcome ?? "abandoned",
            turns: advisorState.turn,
            yourTeam: TeamManager.shared.monSpecs.map(\.species),
            opponentSpecies: archivedOpponentSpecies(),
            stateLines: battleStateLines,
            logMarkdown: battleLogMarkdown,
            previewAdvice: archivedPreviewAdvice?.text,
            previewAdviceMeta: archivedPreviewAdvice?.meta,
            advice: adviceLog,
            appBuild: Self.buildStamp)
        BattleArchiveStore.save(record)
    }

    /// m15-A: "which build watched this battle" — dev builds don't bump
    /// CFBundleVersion, so the binary's modification time is the honest
    /// stamp (the stale-instance discipline: pilot reports start here).
    private static let buildStamp: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let mtime = Bundle.main.executableURL
            .flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }
            .flatMap { $0[.modificationDate] as? Date }
            .map { ISO8601DateFormatter().string(from: $0) } ?? "mtime unknown"
        return "\(version) · binary \(mtime)"
    }()

    private func endBattleSession() {
        battleStartedAt = nil
        battleArchived = false
        adviceLog = []
        archivedPreviewAdvice = nil
    }

    /// The archived opponent roster: the reconciler's corrected identities
    /// when the battle revealed any (same doctrine as the advisor's
    /// capsules), else the preview consensus with pins applied.
    private func archivedOpponentSpecies() -> [String] {
        let known = capsuleSpecies()
        if !known.isEmpty { return known }
        return opponentRead
            .sorted { $0.row < $1.row }
            .compactMap { speciesOverrides[$0.row] ?? $0.speciesTop.first?.name }
    }

    /// Recompute the live matchup when the picture actually changes: actives,
    /// revealed info, HP (bucketed to 5% so plate animation doesn't thrash
    /// the JSC engine), status, boosts, or the field.
    private func recomputeMatchupIfNeeded(snapshots: [BattleReconciler.ActiveSnapshot],
                                          field: LiveFieldSpec,
                                          state: BattleState) {
        advisorSnapshots = snapshots
        advisorField = field
        advisorState = state
        recomputeDossiersIfNeeded()
        // BACKLOG P2: the turn moved — a previous turn's committed play must
        // never present as current. Curtain it NOW (not when fresh advice
        // lands 10–15s later); the new turn's auto-ask fires below.
        let turnChanged = state.turn != battleTurn
        if turnChanged {
            if state.turn < battleTurn { lastAdvisedTurn = -1 }  // new battle, no Reset pressed
            battleTurn = state.turn
            curtainStaleAdvice()
        }
        let members = TeamManager.shared.membersByIdentity
        func spec(_ s: BattleReconciler.ActiveSnapshot) -> MonSpec {
            var spec = MonSpec(species: s.species,
                               item: s.item,
                               ability: s.ability,
                               moves: s.revealedMoves.isEmpty ? nil : s.revealedMoves,
                               boosts: s.boosts.isEmpty ? nil : s.boosts,
                               curPct: s.curPct,
                               status: s.status)
            // Your side is fully known (m9): the configured slot supplies the
            // whole set + real spread; live observations still win where they
            // exist (e.g. a revealed item after a swap). Revealed moves the
            // config doesn't list (stale team) are kept via ordered union.
            if s.side == "you",
               let member = members[s.species.lowercased()]
                         ?? members[s.displayName.lowercased()] {
                if spec.item == nil { spec.item = member.item }
                if spec.ability == nil { spec.ability = member.ability }
                if !member.moves.isEmpty {
                    spec.moves = member.moves
                        + s.revealedMoves.filter { !member.moves.contains($0) }
                }
                spec.evs = member.evs
                spec.ivs = member.ivs
                spec.nature = member.nature
                spec.level = member.level
                spec.teraType = member.teraType
            }
            return spec
        }
        let mine = snapshots.filter { $0.side == "you" && $0.species != "unknown" }.map(spec)
        let theirs = snapshots.filter { $0.side == "opp" && $0.species != "unknown" }.map(spec)
        guard !mine.isEmpty, !theirs.isEmpty else {
            if liveMatchup != nil { liveMatchup = nil; lastMatchupSignature = "" }
            return
        }
        let signature = (mine + theirs).map {
            "\($0.species)|\(Int(($0.curPct ?? 100) / 5))|\($0.moves?.joined(separator: ",") ?? "")"
            + "|\($0.item ?? "")|\($0.ability ?? "")|\($0.status ?? "")"
            + "|\($0.boosts?.sorted(by: { $0.key < $1.key }).map { "\($0.key)\($0.value)" }.joined() ?? "")"
        }.joined(separator: "§") + "‖" + field.signature
        guard signature != lastMatchupSignature else {
            // BACKLOG P2: a turn can advance WITHOUT the matchup picture
            // changing (resolution already moved the HP; the checkpoint
            // just increments the counter) — the new turn still gets its
            // ask. Previously this path silently dropped it.
            if turnChanged { autoAdviseIfDue() }
            return
        }
        lastMatchupSignature = signature

        Task.detached(priority: .utility) { [weak self, engineBox] in
            let result = try? await engineBox.liveMatchup(mine: mine, theirs: theirs, field: field)
            await self?.publishMatchup(result)
        }
    }

    private func publishMatchup(_ data: LiveMatchupData?) {
        if let data { liveMatchup = data }
        // Auto-advise once per turn, on the freshest board math (nil = the
        // matchup engine hiccuped — the turn's ask still fires; the advisor
        // has its own tools).
        autoAdviseIfDue()
    }

    /// The single auto-advise gate (BACKLOG P2): turn increments, fresh
    /// matchup math, and late-answer re-asks all funnel here. In-flight
    /// asks stay blocked; publishAdvice re-checks when they land.
    private func autoAdviseIfDue() {
        guard autoAdvise, battleOutcome == nil,
              advisorState.turn > 0, advisorState.turn != lastAdvisedTurn,
              !adviceInFlight else { return }
        requestAdvice()
    }

    /// BACKLOG P2 fix 1: clear a shown play the instant the turn moves on,
    /// replacing it with an ask prompt. An in-flight ask keeps streaming —
    /// publishAdvice stale-marks (and auto re-asks) its late answer.
    private func curtainStaleAdvice() {
        guard adviceText != nil || advicePlay != nil || advicePromptShown else { return }
        adviceText = nil
        advicePlay = nil
        adviceTurn = nil
        adviceTrace = []
        adviceThoughts = []
        adviceMeta = nil
        adviceLintWarnings = []
        guard !adviceInFlight else { return }
        if battleTurn > 0, battleOutcome == nil {
            adviceStatus = "Turn \(battleTurn) — ask for the play."
            advicePromptShown = true
        } else {
            adviceStatus = nil
            advicePromptShown = false
        }
    }

    // MARK: "What's the play" (m8; agentic tool loop since m11)

    /// The species the meta capsules cover: every opponent the reconciler
    /// knows — actives + bench, which includes unclaimed preview rows at
    /// their best-guess identity. Sourced from the reconciler (not the raw
    /// preview consensus) so battle-corroboration corrections flow in
    /// (battle 6: Farigiraf→Oranguru gets the RIGHT capsule), and a
    /// no-preview bootstrap (battle 7) still gets capsules for whatever
    /// species the narration has revealed.
    private func capsuleSpecies() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for mon in advisorState.oppSide.active + advisorState.oppSide.bench {
            guard mon.speciesId != "unknown", seen.insert(mon.speciesId).inserted else { continue }
            out.append(mon.speciesId)
        }
        return out
    }

    /// One advisor tool-use loop on the current board. The deterministic
    /// matchup + meta capsules are the input; the model runs targeted engine
    /// checks (damage/speed/meta hypotheticals) and picks a line — it never
    /// does the math itself.
    func requestAdvice() {
        guard !adviceInFlight else { return }
        guard AdvisorClient.hasKey else {
            adviceStatus = "No API key — add your Anthropic key in Settings (⌘,)."
            return
        }
        guard !advisorSnapshots.isEmpty else {
            adviceStatus = "No live battle state yet."
            return
        }
        adviceInFlight = true
        adviceStatus = "Thinking…"
        advicePromptShown = false
        adviceProgress = []
        adviceThoughts = []
        lastAdvisedTurn = advisorState.turn
        // m15-B: capture the board's value-typed inputs here; BOTH context
        // blocks (and the lint context) now build inside the detached task,
        // AFTER the capsules exist — buildTurn needs them for the
        // speed-ceiling doomed tiers.
        let snapshots = advisorSnapshots
        let field = advisorField
        let matchup = liveMatchup
        let state = advisorState
        let events = battleEvents
        let oppSpecies = capsuleSpecies()
        let team = TeamManager.shared.team.members
        let teamVocab = TeamManager.shared.vocab
        let monSpecs = TeamManager.shared.monSpecs
        var configuredBuilder: [String: LintContext.ConfiguredMon] = [:]
        for member in team {
            let mon = LintContext.ConfiguredMon(moves: member.moves, item: member.item)
            configuredBuilder[member.species.lowercased()] = mon
            configuredBuilder[member.displayName(vocab: teamVocab).lowercased()] = mon
        }
        let configured = configuredBuilder
        let turn = advisorState.turn
        let progressSink: @Sendable (AdvisorProgress) -> Void = { [weak self] progress in
            guard let self else { return }
            Task { @MainActor in self.applyAdvisorProgress(progress, preview: false) }
        }
        Task.detached(priority: .userInitiated) { [weak self, engineBox] in
            do {
                // Capsules are deterministic per species set → the static
                // block is byte-identical across a battle's turns → cached.
                let capsules = (try? await engineBox.capsules(species: oppSpecies,
                                                              team: monSpecs)) ?? []
                let staticContext = AdvisorContext.buildStatic(
                    yourTeam: team, teamVocab: teamVocab, capsules: capsules)
                let turnContext = AdvisorContext.buildTurn(
                    snapshots: snapshots, field: field, matchup: matchup,
                    state: state, recentEvents: events,
                    yourBench: state.yourSide.bench,
                    oppBench: state.oppSide.bench,
                    capsules: capsules)
                let lintContext = LintContext.build(
                    snapshots: snapshots, field: field, matchup: matchup,
                    state: state, yourBench: state.yourSide.bench,
                    configured: configured, capsules: capsules)
                let tools = try AdvisorToolCatalog.bundled()
                let client = AdvisorClient()
                let advice = try await client.advise(
                    staticContext: staticContext, turnContext: turnContext,
                    tools: tools,
                    // m15-C: the verify-and-repair hook — a violating
                    // commit bounces back once for a repair round-trip.
                    lintPlay: { play in PlayLint.lint(play: play, context: lintContext) },
                    onProgress: progressSink) { calls in
                        await engineBox.runTools(calls, team: monSpecs)
                    }
                await self?.publishAdvice(advice, turn: turn, status: nil,
                                          staticContext: staticContext,
                                          turnContext: turnContext,
                                          model: client.model,
                                          lintContext: lintContext)
            } catch {
                await self?.publishAdvice(nil, turn: turn,
                                          status: error.localizedDescription)
            }
        }
    }

    private func publishAdvice(_ advice: AgenticAdvice?, turn: Int, status: String?,
                               staticContext: String? = nil,
                               turnContext: String? = nil,
                               model: String? = nil,
                               lintContext: LintContext? = nil) {
        adviceInFlight = false
        adviceProgress = []
        if let advice {
            adviceText = advice.text
            adviceTurn = turn
            adviceTrace = advice.trace
            adviceThoughts = advice.thoughts
            advicePlay = advice.play
            // m15-C: unresolved violations show under the chips; a clean
            // repair earns a quiet meta note instead.
            let violations = advice.lintFindings.filter { $0.severity == .violation }
            adviceLintWarnings = violations.map(\.message)
            let checks = advice.trace.filter { $0.tool != "commit_play" && $0.tool != "play_lint" }.count
            adviceMeta = "\(advice.iterations) round-trip\(advice.iterations == 1 ? "" : "s")"
                + (checks > 0 ? " · \(checks) engine check\(checks == 1 ? "" : "s")" : " · no checks needed")
                + String(format: " · %.1fs", advice.elapsed)
                + (advice.cacheReadTokens > 0 ? " · cache hit" : "")
                + (advice.lintRepaired && violations.isEmpty ? " · 🧯 repaired after rule check" : "")
            // m13-C: every answered ask is a decision point for the archive.
            // m15-A: the entry now carries the EXACT prompt blocks and the
            // model id, so the eval harness can replay it byte-for-byte,
            // and empty verdict fields awaiting the pilot's 👍/👎.
            // m15-B: plus the structured play, the board facts it was
            // checked against, and the lint's verdict (m15-C: from the
            // loop itself — repair included) — every archived decision is
            // re-lintable offline, forever.
            let lintFindings: [PlayLint.Finding]? =
                advice.play == nil ? nil : advice.lintFindings
            adviceLog.append(BattleRecord.AdviceEntry(
                turn: turn,
                askedAt: Date(),
                text: advice.text,
                playLines: advice.play?.actions.map {
                    $0.displayLine + ($0.note.map { n in " — \(n)" } ?? "")
                } ?? [],
                thoughts: advice.thoughts,
                trace: advice.trace.map {
                    .init(tool: $0.tool, input: $0.inputSummary,
                          result: $0.resultSummary, isError: $0.isError)
                },
                meta: adviceMeta,
                staticContext: staticContext,
                turnContext: turnContext,
                model: model,
                play: advice.play,
                lintContext: lintContext,
                lintFindings: lintFindings))
        }
        adviceStatus = status
        advicePromptShown = false
        // BACKLOG P2: the answer raced a turn change — it arrives already
        // stale (views mark it via adviceTurn != battleTurn). With auto on,
        // ask again for the CURRENT turn right away: the turn-change trigger
        // was blocked by this very ask being in flight. With auto off,
        // restore the ask prompt so the staleness is actionable.
        if turn != battleTurn, battleOutcome == nil {
            autoAdviseIfDue()
            if !autoAdvise, status == nil, battleTurn > 0 {
                adviceStatus = "Turn \(battleTurn) — ask for the play."
                advicePromptShown = true
            }
        }
    }

    /// Compact per-side summary lines for the Battle Log header.
    nonisolated static func summarize(_ state: BattleState) -> [String] {
        var lines: [String] = []
        var headline = "Turn \(state.turn)"
        if state.weather.kind != "none" {
            headline += " · \(state.weather.kind)"
            if let left = state.weather.turnsLeft { headline += " (\(left))" }
        }
        if state.field.trickRoom == true { headline += " · Trick Room" }
        lines.append(headline)
        for (tag, side) in [("you", state.yourSide), ("opp", state.oppSide)] {
            let actives = side.active.map { mon in
                var bits = mon.describeName
                if let hp = mon.hp { bits += " \(hp.display)" }
                if let s = mon.status { bits += " \(s)" }
                if !mon.boosts.isNeutral { bits += " \(mon.boosts.display)" }
                return bits
            }
            let fainted = side.bench.filter { $0.hp?.isFainted == true }.count
            var line = "[\(tag)] " + (actives.isEmpty ? "—" : actives.joined(separator: "  ·  "))
            if fainted > 0 { line += "   (\(fainted) fainted)" }
            lines.append(line)
        }
        return lines
    }

    private func publish(result: ScreenStateClassification, preview: CGImage,
                         info: CaptureCandidate) {
        current = result
        previewImage = preview
        statusLine = "Tracking @ \(Int(fps)) fps"
        windowLine = Self.describe(info)
        if result.primary.rawValue != lastPrimaryRaw {
            transitions.insert(TransitionEntry(
                time: Date(),
                from: lastPrimaryRaw ?? "start",
                to: result.primary.rawValue,
                confidence: result.confidence
            ), at: 0)
            if transitions.count > maxLogEntries {
                transitions.removeLast(transitions.count - maxLogEntries)
            }
            lastPrimaryRaw = result.primary.rawValue
        }
    }

    nonisolated private static func describe(_ c: CaptureCandidate) -> String {
        "\(c.appName) — “\(c.title)” \(Int(c.frame.width))×\(Int(c.frame.height)) pt"
    }
}

// MARK: - View

public struct LiveTrackerView: View {
    @ObservedObject private var model = LiveTrackerModel.shared
    @Environment(\.openWindow) private var openWindow
    @State private var autoOpenedReport = false
    @State private var autoOpenedBattleLog = false
    @AppStorage("overlayAutoOpensOnBattle") private var overlayAutoOpen = true


    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HStack(alignment: .top, spacing: 16) {
                statePanel
                    .frame(minWidth: 240)
                if !model.opponentRead.isEmpty {
                    opponentPanel
                        .frame(minWidth: 250)
                }
                transitionLog
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 420)
        .onDisappear { model.stop() }
        // The first ready report is the milestone moment — surface it once.
        .onChange(of: model.scoutReport != nil) { _, ready in
            if ready && !autoOpenedReport {
                autoOpenedReport = true
                openWindow(id: "scout-report")
            }
        }
        // First battle event of the session → surface the live log once,
        // and the glanceable overlay (m10-A) when enabled.
        .onChange(of: model.battleEvents.isEmpty) { _, empty in
            if !empty && !autoOpenedBattleLog {
                autoOpenedBattleLog = true
                openWindow(id: "battle-log")
            }
            if !empty && overlayAutoOpen {
                OverlayHUDController.shared.show()
            }
        }
    }

    /// Frame-voted opponent team read (fills in during team preview).
    private var opponentPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Opponent read · \(model.opponentFrameCount) frames")
                .font(.headline)
            ForEach(model.opponentRead, id: \.row) { row in
                HStack(spacing: 8) {
                    if let sprite = model.opponentSprites[row.row] {
                        Image(decorative: sprite, scale: 2)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            if let species = row.speciesTop.first?.name {
                                EntryLink(name: species, kind: .species, font: .callout, weight: .semibold)
                            } else {
                                Text("?")
                                    .font(.callout.weight(.semibold))
                            }
                            Text(genderGlyph(row.gender))
                                .font(.caption)
                                .foregroundStyle(row.gender == "female" ? .pink : .blue)
                        }
                        Text("\(row.typePair.joined(separator: "/"))  ·  \(Int(row.typeStability * 100))% stable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if row.speciesTop.count > 1 {
                            Text(row.speciesTop.dropFirst().map(\.name).joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Row \(row.row + 1): \(row.speciesTop.first?.name ?? "unknown"), "
                    + "types \(row.typePair.joined(separator: " ")), \(row.gender)"
                )
            }
            Spacer(minLength: 0)
        }
    }

    private func genderGlyph(_ g: String) -> String {
        switch g {
        case "male": "♂"
        case "female": "♀"
        default: "—"
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(model.isRunning ? "Stop" : "Start") {
                model.isRunning ? model.stop() : model.start()
            }
            .keyboardShortcut(model.isRunning ? .cancelAction : .defaultAction)
            .accessibilityLabel(model.isRunning ? "Stop tracking" : "Start tracking")

            Button("Scout Report") { openWindow(id: "scout-report") }
                .disabled(model.scoutReport == nil)
                .accessibilityLabel("Open scout report window")

            Button("Battle Log") { openWindow(id: "battle-log") }
                .accessibilityLabel("Open battle log window")

            Button("Dossiers") { openWindow(id: "dossier") }
                .accessibilityLabel("Open the opponent dossier window")
                .help("Likely sets with plain-English effects for every known opponent (⇧⌘K)")

            Button("Overlay") { OverlayHUDController.shared.toggle() }
                .accessibilityLabel("Toggle the floating overlay HUD")
                .help("Compact always-on-top matchup + advice panel")

            Button("Archive") { openWindow(id: "battle-archive") }
                .accessibilityLabel("Open the battle archive window")
                .help("Review past battles: logs, plays, and why-traces (⇧⌘A)")

            VStack(alignment: .leading, spacing: 2) {
                Text(model.statusLine)
                    .font(.callout)
                if !model.windowLine.isEmpty {
                    Text(model.windowLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(AppBuildStamp.display)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .help("When this binary was built. If a new feature seems missing, quit and relaunch — a running app instance outlives rebuilds.")
                .accessibilityLabel("App \(AppBuildStamp.display)")
        }
    }

    private var statePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let preview = model.previewImage {
                Image(decorative: preview, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                    .accessibilityLabel("Live viewport preview")
            }

            if let r = model.current {
                Text(r.primary.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .accessibilityLabel("Current state: \(r.primary.rawValue)")

                if !r.overlays.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(r.overlays.map(\.rawValue).sorted(), id: \.self) { overlay in
                            Text(overlay)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(.blue.opacity(0.15)))
                        }
                    }
                    .accessibilityLabel("Overlays: \(r.overlays.map(\.rawValue).joined(separator: ", "))")
                }

                ProgressView(value: r.confidence) {
                    Text("confidence \(r.confidence, format: .number.precision(.fractionLength(2)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 320)
                .accessibilityLabel("Confidence \(Int(r.confidence * 100)) percent")
            } else {
                Text("—")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var transitionLog: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Transitions")
                .font(.headline)
            List(model.transitions) { entry in
                HStack(spacing: 8) {
                    Text(entry.time, format: .dateTime.hour().minute().second())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(entry.from) → \(entry.to)")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Text(entry.confidence, format: .number.precision(.fractionLength(2)))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .listStyle(.inset)
            .frame(minHeight: 240)
        }
    }
}

#Preview {
    LiveTrackerView()
}
