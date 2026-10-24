//
//  EvalHarness.swift
//  ScopeLens Diagnostics — m15-B: the advisor eval set (SESSION-10 Task A).
//
//  Replays decision points through the REAL advisor loop and scores the
//  committed play two ways: (a) deterministic PlayLint findings — the
//  objective tier that runs on every case, and (b) per-case assertions
//  hand-derived from pilot verdicts (forbid/require patterns). Advisor
//  quality becomes a number; every doctrine/prompt/effort change is gated
//  on it instead of vibes.
//
//  Case sources (Tools/ScopeLensDiagnostics/eval/cases/*.json):
//    {"video": path, "at": seconds}  — replay committed fixture footage
//                                      through the full parser→reconciler→
//                                      engine pipeline (context changes
//                                      flow through automatically).
//    {"inline": {...}}               — verbatim contexts + lintContext
//                                      (reconstructed boards, e.g. the
//                                      pilot's Solar Beam forfeit — his
//                                      archive predates m15-A context
//                                      capture).
//    {"archive": file, "ask": N}     — an m15-A+ record's stored contexts,
//                                      replayed byte-for-byte.
//
//  Deliberately NOT in verify-all: live asks cost real API tokens. Run via
//  Tools/ScopeLensDiagnostics/eval-advisor.sh. `--dry-run` still evaluates the
//  deterministic assertions (doomedFlag/noDoomedFlag) for free; `--sweep`
//  lints every archived committed play offline.
//
//  Flags: --cases DIR · --case NAME (repeatable filter) · --runs N ·
//  --model ID · --dry-run · --sweep · --archive-dir PATH
//

import Foundation
import AVFoundation
import CoreGraphics
import CoreImage

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

@main
struct EvalHarness {

    static let repoRoot = FileManager.default.currentDirectoryPath

    // MARK: Case schema

    struct EvalCase: Decodable {
        struct Inline: Decodable {
            let staticContext: String
            let turnContext: String
            let lintContext: LintContext?
        }
        struct Source: Decodable {
            let video: String?
            let at: Double?
            let inline: Inline?
            let archive: String?
            let ask: Int?
        }
        struct Assertion: Decodable {
            let type: String       // commit | lintClean | forbid | require | doomedFlag | noDoomedFlag
            let pokemon: String?
            let move: String?
            let anyOf: [String]?
            let species: String?
            let tier: String?
        }
        let name: String
        let description: String?
        let source: Source
        let assertions: [Assertion]
    }

    /// Everything a case run needs, however it was sourced.
    struct PreparedBoard {
        let staticContext: String
        let turnContext: String
        let lintContext: LintContext?
        let sourceLabel: String
    }

    // MARK: Entry

    static func main() async {
        var casesDir = "\(repoRoot)/Tools/ScopeLensDiagnostics/eval/cases"
        var nameFilters: [String] = []
        var runs = 1
        var dryRun = false
        var sweep = false
        var model: String?
        var thinking: String?
        var effort: String?
        var archiveDir = ("~/Library/Containers/com.ethan-marshall.Scope-Lens/Data/Library/Application Support/BattleArchive" as NSString).expandingTildeInPath

        var args = Array(CommandLine.arguments.dropFirst())
        while !args.isEmpty {
            let flag = args.removeFirst()
            func value() -> String? { args.isEmpty ? nil : args.removeFirst() }
            switch flag {
            case "--cases": casesDir = value() ?? casesDir
            case "--case": if let v = value() { nameFilters.append(v) }
            case "--runs": runs = value().flatMap(Int.init) ?? runs
            case "--dry-run": dryRun = true
            case "--sweep": sweep = true
            case "--model": model = value()
            case "--thinking": thinking = value()   // adaptive | disabled (m15-E)
            case "--effort": effort = value()       // low | medium | high | xhigh | max
            case "--archive-dir": archiveDir = value() ?? archiveDir
            default: fputs("unknown flag \(flag)\n", stderr); exit(2)
            }
        }

        if sweep {
            sweepArchive(dir: archiveDir)
            return
        }

        let files = ((try? FileManager.default.contentsOfDirectory(atPath: casesDir)) ?? [])
            .filter { $0.hasSuffix(".json") }.sorted()
        guard !files.isEmpty else {
            fputs("no case files in \(casesDir)\n", stderr)
            exit(2)
        }
        var cases: [EvalCase] = []
        for file in files {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: "\(casesDir)/\(file)"))
                let parsed = try JSONDecoder().decode(EvalCase.self, from: data)
                if nameFilters.isEmpty || nameFilters.contains(parsed.name) {
                    cases.append(parsed)
                }
            } catch {
                fputs("case \(file) failed to parse: \(error)\n", stderr)
                exit(2)
            }
        }

        var passedCases = 0
        var failures: [String] = []
        for evalCase in cases {
            let ok = await run(evalCase, runs: runs, dryRun: dryRun,
                               modelOverride: model, thinkingOverride: thinking,
                               effortOverride: effort, archiveDir: archiveDir)
            if ok { passedCases += 1 } else { failures.append(evalCase.name) }
        }

        print("\n════════ EVAL SUMMARY ════════")
        print("cases: \(passedCases)/\(cases.count) green"
              + (dryRun ? " (dry run — API assertions skipped)" : ""))
        for name in failures { print("  ❌ \(name)") }
        exit(passedCases == cases.count ? 0 : 1)
    }

    // MARK: One case

    static func run(_ evalCase: EvalCase, runs: Int, dryRun: Bool,
                    modelOverride: String?, thinkingOverride: String? = nil,
                    effortOverride: String? = nil, archiveDir: String) async -> Bool {
        print("\n── \(evalCase.name)")
        if let description = evalCase.description { print("   \(description)") }

        let board: PreparedBoard
        do {
            board = try await prepare(evalCase.source, archiveDir: archiveDir)
        } catch {
            print("   ❌ board preparation failed: \(error.localizedDescription)")
            return false
        }
        print("   source: \(board.sourceLabel)")

        // Deterministic assertions run first — free, and they pin the flag
        // computation itself (doomedSlots regressions fail here without a
        // single API token).
        var deterministicOK = true
        for assertion in evalCase.assertions where ["doomedFlag", "noDoomedFlag"].contains(assertion.type) {
            let ok = checkDeterministic(assertion, lintContext: board.lintContext)
            deterministicOK = deterministicOK && ok
            print("   \(ok ? "✅" : "❌") \(describe(assertion))")
        }

        let apiAssertions = evalCase.assertions.filter { !["doomedFlag", "noDoomedFlag"].contains($0.type) }
        if dryRun {
            if !apiAssertions.isEmpty {
                print("   (dry run — \(apiAssertions.count) API assertion\(apiAssertions.count == 1 ? "" : "s") skipped)")
            }
            return deterministicOK
        }
        guard !apiAssertions.isEmpty else { return deterministicOK }

        guard let key = envLocalKey() ?? AdvisorClient.resolveKey() else {
            print("   ❌ no ANTHROPIC_API_KEY in .env.local or environment")
            return false
        }
        guard let tools = try? AdvisorToolCatalog.fromRepo(root: repoRoot) else {
            print("   ❌ tool-schemas.json unreadable")
            return false
        }
        let executor: AdvisorToolExecutor?
        do { executor = try makeExecutor() } catch {
            print("   ⚠️ engine unavailable for tool calls: \(error.localizedDescription)")
            return false
        }

        var allRunsOK = deterministicOK
        for runIndex in 1...max(1, runs) {
            var client = AdvisorClient()
            if let modelOverride { client.model = modelOverride }
            if let thinkingOverride { client.thinkingMode = thinkingOverride }
            if let effortOverride { client.effort = effortOverride }
            let started = Date()
            let advice: AgenticAdvice
            do {
                // The lint hook makes the eval exercise the SAME
                // verify-and-repair loop the app runs (m15-C).
                let lintHook: (@Sendable (AdvisorPlay) -> [PlayLint.Finding])? =
                    board.lintContext.map { context in
                        { @Sendable play in PlayLint.lint(play: play, context: context) }
                    }
                advice = try await client.advise(
                    staticContext: board.staticContext,
                    turnContext: board.turnContext,
                    tools: tools, apiKey: key,
                    lintPlay: lintHook) { calls in
                        calls.map {
                            let result = executor!.execute(name: $0.name, arguments: $0.input)
                            return AdvisorToolResult(id: $0.id, text: result.text, isError: result.isError)
                        }
                    }
            } catch {
                print("   run \(runIndex)/\(runs): ❌ ask died — \(error.localizedDescription)")
                allRunsOK = false
                continue
            }

            let playLine = advice.play?.actions.map(\.displayLine).joined(separator: " · ")
                ?? "(prose only)"
            let findings = advice.lintFindings
            let violations = findings.filter { $0.severity == .violation }
            print(String(format: "   run %d/%d (%.1fs, %d RT%@): %@",
                         runIndex, runs, Date().timeIntervalSince(started),
                         advice.iterations,
                         advice.lintRepaired ? ", 🧯 repair bounced" : "",
                         playLine))
            for finding in findings {
                print("     [\(finding.severity.rawValue)] \(finding.rule): \(finding.message)")
            }

            for assertion in apiAssertions {
                let ok = check(assertion, advice: advice, violations: violations,
                               lintContext: board.lintContext)
                allRunsOK = allRunsOK && ok
                print("   \(ok ? "✅" : "❌") \(describe(assertion))")
            }
        }
        print(allRunsOK ? "   PASS" : "   FAIL")
        return allRunsOK
    }

    // MARK: Assertions

    static func describe(_ a: EvalCase.Assertion) -> String {
        switch a.type {
        case "commit": return "commit — a structured play must be committed"
        case "lintClean": return "lintClean — no PlayLint violations"
        case "forbid": return "forbid — \(a.pokemon ?? "anyone") must not use \(a.move ?? "?")"
        case "require": return "require — \(a.pokemon ?? "?") must \(a.anyOf?.joined(separator: " / ") ?? "?")"
        case "doomedFlag": return "doomedFlag — \(a.species ?? "?") flagged\(a.tier.map { " (\($0))" } ?? "")"
        case "noDoomedFlag": return "noDoomedFlag — no slot flagged doomed"
        default: return "unknown assertion \(a.type)"
        }
    }

    static func checkDeterministic(_ a: EvalCase.Assertion, lintContext: LintContext?) -> Bool {
        guard let doomed = lintContext?.doomed else { return false }
        switch a.type {
        case "doomedFlag":
            return doomed.contains {
                $0.species == (a.species ?? "") && (a.tier == nil || $0.tier.rawValue == a.tier)
            }
        case "noDoomedFlag":
            return doomed.isEmpty
        default:
            return false
        }
    }

    static func check(_ a: EvalCase.Assertion, advice: AgenticAdvice,
                      violations: [PlayLint.Finding], lintContext: LintContext?) -> Bool {
        func matches(_ pattern: String?, _ value: String?) -> Bool {
            guard let pattern else { return true }   // unspecified matches all
            guard let value else { return false }
            let p = PlayLint.matchKey(pattern), v = PlayLint.matchKey(value)
            return p == v || v.hasPrefix(p) || p.hasPrefix(v)
        }
        switch a.type {
        case "commit":
            return advice.play != nil
        case "lintClean":
            guard lintContext != nil else { return false }   // unlintable = not clean
            return advice.play != nil && violations.isEmpty
        case "forbid":
            let actions = advice.play?.actions ?? []
            return !actions.contains { matches(a.pokemon, $0.pokemon) && matches(a.move, $0.move) }
        case "require":
            let actions = advice.play?.actions ?? []
            guard let options = a.anyOf, !options.isEmpty else { return false }
            return actions.contains { action in
                guard matches(a.pokemon, action.pokemon) else { return false }
                return options.contains { option in
                    option.lowercased() == "switch"
                        ? action.verb == "switch"
                        : matches(option, action.move)
                }
            }
        default:
            return false
        }
    }

    // MARK: Board preparation

    static func prepare(_ source: EvalCase.Source, archiveDir: String) async throws -> PreparedBoard {
        if let inline = source.inline {
            return PreparedBoard(staticContext: inline.staticContext,
                                 turnContext: inline.turnContext,
                                 lintContext: inline.lintContext,
                                 sourceLabel: "inline (reconstructed board)")
        }
        if let archive = source.archive {
            let url = URL(fileURLWithPath: archiveDir).appendingPathComponent(archive)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let record = try decoder.decode(BattleRecord.self, from: Data(contentsOf: url))
            let index = source.ask ?? 0
            guard record.advice.indices.contains(index) else {
                throw HarnessError("record \(archive) has no ask #\(index)")
            }
            let entry = record.advice[index]
            guard let staticContext = entry.staticContext, let turnContext = entry.turnContext else {
                throw HarnessError("record \(archive) ask #\(index) predates m15-A context capture — use an inline reconstruction instead")
            }
            return PreparedBoard(staticContext: staticContext, turnContext: turnContext,
                                 lintContext: entry.lintContext,
                                 sourceLabel: "archive \(archive) ask #\(index) (turn \(entry.turn))")
        }
        guard let video = source.video, let at = source.at else {
            throw HarnessError("case source needs video+at, inline, or archive")
        }
        return try await replay(videoPath: resolveFixturePath(video), at: at)
    }

    /// Case files name fixtures the way the standalone repo laid them out (`Fixtures/…`); those
    /// live under SCOPELENS_FIXTURES now. Absolute paths pass through; anything else is repo-relative.
    static func resolveFixturePath(_ path: String) -> String {
        if path.hasPrefix("/") { return path }
        if path.hasPrefix("Fixtures/") { return "\(scopeLensFixturesRoot)/" + path.dropFirst("Fixtures/".count) }
        return "\(repoRoot)/\(path)"
    }

    /// The AdvisorHarness replay, condensed: footage → parser → reconciler
    /// → engine → the exact contexts the app would send at that moment,
    /// plus the LintContext built from the same inputs.
    static func replay(videoPath: String, at: Double) async throws -> PreparedBoard {
        let vocabulary = try BattleVocabulary.fromRepo(root: repoRoot)
        let classifier = ScreenStateClassifier()
        let observer = VisionFrameObserver()
        let parser = BattleEventParser(vocabulary: vocabulary)
        let (team, teamVocab) = try loadTeam()
        let reconciler = BattleReconciler(
            vocabulary: vocabulary,
            yourTeam: team.teamSeeds(vocab: teamVocab).map {
                .init(species: $0.species, display: $0.display)
            })

        let pipeline: PreviewPipeline? = {
            guard let templates = try? Data(contentsOf: URL(fileURLWithPath: "\(scopeLensFixturesRoot)/type-templates/templates.json")),
                  let index = try? Data(contentsOf: URL(fileURLWithPath: "\(scopeLensFixturesRoot)/reference/species-index.json")),
                  let sheet = loadCG("\(scopeLensFixturesRoot)/reference/pokemonicons-sheet.png"),
                  let typeCore = try? TypeIconCore(templatesJSON: templates),
                  let speciesCore = try? SpeciesCore(
                      indexJSON: index, sheet: sheet,
                      dexFeaturesJSON: try? Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Packages/ScopeLens/Sources/ScopeLens/Resources/PreviewPipeline/dex-features.json")),
                      nativeFeaturesJSON: try? Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Packages/ScopeLens/Sources/ScopeLens/Resources/PreviewPipeline/native-features.json")))
            else { return nil }
            return PreviewPipeline(typeCore: typeCore, speciesCore: speciesCore)
        }()

        let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw HarnessError("no video track at \(videoPath)")
        }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: .zero,
                                       duration: CMTime(seconds: at, preferredTimescale: 600))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()

        let ciContext = CIContext(options: [.cacheIntermediates: false])
        var nextSample = 0.0
        var aggregate = PreviewAggregate()
        var lastPipelineRun = -10.0
        var previewSeeded = false
        var framesSincePreview = 0

        while reader.status == .reading {
            guard let sb = output.copyNextSampleBuffer() else { break }
            autoreleasepool {
                defer { CMSampleBufferInvalidate(sb) }
                let pts = CMSampleBufferGetPresentationTimeStamp(sb).seconds
                guard pts >= nextSample, let pb = CMSampleBufferGetImageBuffer(sb) else { return }
                nextSample = pts + 0.5
                let ci = CIImage(cvPixelBuffer: pb)
                guard let full = ciContext.createCGImage(ci, from: ci.extent),
                      let small = downscale(full, by: 0.5),
                      let tokens = try? observer.observe(small) else { return }
                let classification = classifier.classify(tokens: tokens)

                if classification.primary == .teamPreview, let pipeline {
                    framesSincePreview = 0
                    if pts - lastPipelineRun >= 1.0, let read = pipeline.read(frame: full) {
                        aggregate.add(read)
                        lastPipelineRun = pts
                    }
                } else if aggregate.frameCount >= 3, !previewSeeded {
                    framesSincePreview += 1
                    if framesSincePreview >= 4 {
                        previewSeeded = true
                        reconciler.seedPreview(aggregate.consensus.map {
                            .init(row: $0.row, speciesTop: $0.speciesTop.map(\.name),
                                  types: $0.typePair)
                        }, t: pts)
                    }
                }
                reconciler.ingest(parser.observe(tokens: tokens, classification: classification, t: pts))
            }
        }

        // ── engine + contexts, exactly as the app builds them ───────────
        let snapshots = reconciler.activeSnapshots()
        guard !snapshots.isEmpty else {
            throw HarnessError("no actives at t=\(at) — pick a mid-turn moment")
        }
        let field = reconciler.liveFieldSpec()
        let state = reconciler.state

        var membersByIdentity: [String: TeamMember] = [:]
        for member in team.members {
            membersByIdentity[member.species.lowercased()] = member
            membersByIdentity[member.displayName(vocab: teamVocab).lowercased()] = member
        }
        func spec(_ s: BattleReconciler.ActiveSnapshot) -> MonSpec {
            var spec = MonSpec(species: s.species, item: s.item, ability: s.ability,
                    moves: s.revealedMoves.isEmpty ? nil : s.revealedMoves,
                    boosts: s.boosts.isEmpty ? nil : s.boosts,
                    curPct: s.curPct, status: s.status)
            if s.side == "you",
               let member = membersByIdentity[s.species.lowercased()]
                         ?? membersByIdentity[s.displayName.lowercased()] {
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

        let executor = try makeExecutor()
        let engine = executor.engine

        for obs in reconciler.drainPendingInferences() {
            var defender: [String: Any]
            if let member = membersByIdentity[obs.defenderSpecies.lowercased()]
                ?? membersByIdentity[obs.defenderDisplay.lowercased()] {
                defender = member.monSpec.asDictionary
            } else {
                defender = [:]
            }
            defender["species"] = obs.defenderSpecies
            if !obs.defenderBoosts.isEmpty { defender["boosts"] = obs.defenderBoosts }
            if let status = obs.defenderStatus { defender["status"] = status }
            var fieldDict: [String: Any] = [:]
            if let w = obs.field.weather { fieldDict["weather"] = w }
            if !obs.field.screensYou.isEmpty { fieldDict["screensYou"] = obs.field.screensYou }
            var input: [String: Any] = [
                "attacker": obs.attackerSpecies, "move": obs.move,
                "defender": defender, "observedDamage": obs.observedDamage,
                "field": fieldDict,
            ]
            if !obs.attackerBoosts.isEmpty { input["attackerBoosts"] = obs.attackerBoosts }
            if obs.attackerMega { input["mega"] = true }
            guard let result = (try? engine.inferAttack(input)) ?? nil,
                  result["skipped"] == nil,
                  result["conclusive"] as? Bool == true,
                  let summary = result["summary"] as? String else { continue }
            reconciler.recordInferenceVerdict(for: obs, summary: summary)
        }

        let matchup = (mine.isEmpty || theirs.isEmpty)
            ? nil : try engine.liveMatchup(mine: mine, theirs: theirs, field: field)

        var seenSpecies = Set<String>()
        var capsuleSpecies: [String] = []
        for mon in state.oppSide.active + state.oppSide.bench {
            guard mon.speciesId != "unknown",
                  seenSpecies.insert(mon.speciesId).inserted else { continue }
            capsuleSpecies.append(mon.speciesId)
        }
        let capsules = executor.buildCapsules(species: capsuleSpecies)
        let staticContext = AdvisorContext.buildStatic(
            yourTeam: team.members, teamVocab: teamVocab, capsules: capsules)
        let freshSnapshots = reconciler.activeSnapshots()   // inference hints included
        let turnContext = AdvisorContext.buildTurn(
            snapshots: freshSnapshots,
            field: field, matchup: matchup, state: state,
            recentEvents: reconciler.events,
            yourBench: state.yourSide.bench, oppBench: state.oppSide.bench,
            capsules: capsules)

        var configured: [String: LintContext.ConfiguredMon] = [:]
        for member in team.members {
            let mon = LintContext.ConfiguredMon(moves: member.moves, item: member.item)
            configured[member.species.lowercased()] = mon
            configured[member.displayName(vocab: teamVocab).lowercased()] = mon
        }
        let lintContext = LintContext.build(
            snapshots: freshSnapshots, field: field, matchup: matchup,
            state: state, yourBench: state.yourSide.bench,
            configured: configured, capsules: capsules)

        return PreparedBoard(staticContext: staticContext, turnContext: turnContext,
                             lintContext: lintContext,
                             sourceLabel: "\(URL(fileURLWithPath: videoPath).lastPathComponent) @ \(Int(at))s (turn \(state.turn))")
    }

    // MARK: Offline sweep (every archived play, re-linted)

    static func sweepArchive(dir: String) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [])
            .filter { $0.hasSuffix(".json") }.sorted()
        var lintable = 0, entries = 0, violationCount = 0
        for file in files {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(dir)/\(file)")),
                  let record = try? decoder.decode(BattleRecord.self, from: data) else { continue }
            for (index, entry) in record.advice.enumerated() {
                entries += 1
                guard let play = entry.play, let context = entry.lintContext else { continue }
                lintable += 1
                let findings = PlayLint.lint(play: play, context: context)
                for finding in findings {
                    if finding.severity == .violation { violationCount += 1 }
                    print("\(finding.severity == .violation ? "❌" : "⚠️") \(file) ask#\(index) turn \(entry.turn)"
                          + " [\(finding.rule)] \(finding.message)")
                }
            }
        }
        print("\narchive sweep: \(files.count) records · \(entries) decision points · "
              + "\(lintable) lintable (m15-A+) · \(violationCount) violations")
        if lintable == 0 {
            print("(records predate m15-B play/lintContext capture — the supply starts with the pilot's next session)")
        }
    }

    // MARK: Plumbing

    struct HarnessError: Error, LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    static func loadTeam() throws -> (Team, TeamVocab) {
        guard let (team, vocab, issues) = try? Team.fromRepoDefault(root: repoRoot),
              !issues.contains(where: { $0.severity == .error }) else {
            throw HarnessError("cannot load the default team paste — run from the repo root")
        }
        return (team, vocab)
    }

    static func makeExecutor() throws -> AdvisorToolExecutor {
        let engineSource = try String(
            contentsOf: URL(fileURLWithPath: "\(repoRoot)/Tools/ScopeLensEngine/dist/engine.js"), encoding: .utf8)
        let meta = try? Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Tools/ScopeLensEngine/data/meta-regmbs3.json"))
        let engine = try ScoutEngine(engineSource: engineSource, metaJSON: meta)
        let vocabulary = try BattleVocabulary.fromRepo(root: repoRoot)
        let (team, _) = try loadTeam()
        return AdvisorToolExecutor(engine: engine, vocabulary: vocabulary,
                                   configuredTeam: team.members.map(\.monSpec))
    }

    static func envLocalKey() -> String? {
        guard let text = try? String(contentsOf: URL(fileURLWithPath: "\(repoRoot)/.env.local"),
                                     encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("ANTHROPIC_API_KEY") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    static func loadCG(_ path: String) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    static func downscale(_ image: CGImage, by scale: CGFloat) -> CGImage? {
        if scale >= 1.0 { return image }
        let w = Int(CGFloat(image.width) * scale), h = Int(CGFloat(image.height) * scale)
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}
