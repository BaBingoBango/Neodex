//
//  AdvisorHarness.swift
//  ScopeLens Diagnostics — Phase 3 m8→m11: offline proof of the LLM advisor.
//
//  Replays a recorded battle up to a chosen moment, builds the EXACT context
//  the app's agentic advisor sends (battle-static meta capsules + volatile
//  turn state), and runs the REAL tool-use loop — Anthropic API round-trips
//  with the six engine tools executed against the local JSC engine — so
//  "what's the play" is verified end-to-end before any live battle.
//  Unsandboxed, so the key comes from the repo's .env.local
//  (ANTHROPIC_API_KEY=…; never printed).
//
//  Build & run (from repo root):
//    swiftc -O Tools/ScopeLensDiagnostics/AdvisorHarness.swift \
//      "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleVocabulary.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleEventParser.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/BattleReconciler.swift" "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/ScoutEngine.swift" "Packages/ScopeLens/Sources/ScopeLens/AdvisorContext.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/AdvisorClient.swift" "Packages/ScopeLens/Sources/ScopeLens/AdvisorTools.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" "Packages/ScopeLens/Sources/ScopeLens/PlayLint.swift" \
//      -o /tmp/advisorharness && /tmp/advisorharness --video "…/Example Battle 5.mov" --at 190
//
//  Flags: --video PATH · --at SECONDS (build context at this moment;
//  default 190) · --dry-run (print contexts, skip the API call) ·
//  --preview (m12-A: ignore the reconciler and ask the TEAM PREVIEW
//  question from the frame-voted consensus — the aggregate persists after
//  the preview segment ends, so any --at past preview works) ·
//  --nudge TEXT (append a pilot note to the volatile block)
//

import Foundation
import AVFoundation
import CoreGraphics
import CoreImage

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

@main
struct AdvisorHarness {

    static let repoRoot = FileManager.default.currentDirectoryPath

    /// The pilot's team from the committed default paste (m9) — identical to
    /// what the app's TeamManager falls back to, so the harness context
    /// matches the live advisor context byte-for-byte.
    static let loadedTeam: (team: Team, vocab: TeamVocab) = {
        guard let (team, vocab, issues) = try? Team.fromRepoDefault(root: repoRoot),
              !issues.contains(where: { $0.severity == .error }) else {
            fputs("error: cannot load \(Team.defaultPasteRepoPath) — run from the repo root\n", stderr)
            exit(2)
        }
        return (team, vocab)
    }()

    static var yourTeamSeeds: [(species: String, display: String)] {
        loadedTeam.team.teamSeeds(vocab: loadedTeam.vocab)
    }

    static func main() async {
        var videoPath = "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max/Example Battle 5.mov"
        var at = 190.0
        var dryRun = false
        var preview = false
        var nudge: String?
        var args = Array(CommandLine.arguments.dropFirst())
        while !args.isEmpty {
            let flag = args.removeFirst()
            func value() -> String? { args.isEmpty ? nil : args.removeFirst() }
            switch flag {
            case "--video": videoPath = value() ?? videoPath
            case "--at": at = value().flatMap(Double.init) ?? at
            case "--dry-run": dryRun = true
            case "--preview": preview = true
            // Harness-only probe: extra instruction appended to the turn
            // context — e.g. force tool verification to exercise the loop
            // machinery on boards the context alone would decide.
            case "--nudge": nudge = value()
            default: fputs("unknown flag \(flag)\n", stderr); exit(2)
            }
        }

        do {
            try await run(videoPath: videoPath, at: at, dryRun: dryRun,
                          preview: preview, nudge: nudge)
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    static func run(videoPath: String, at: Double, dryRun: Bool,
                    preview: Bool = false, nudge: String? = nil) async throws {
        // ---- replay to the chosen moment --------------------------------
        let vocabulary = try BattleVocabulary.fromRepo(root: repoRoot)
        let classifier = ScreenStateClassifier()
        let observer = VisionFrameObserver()
        let parser = BattleEventParser(vocabulary: vocabulary)
        let reconciler = BattleReconciler(
            vocabulary: vocabulary,
            yourTeam: yourTeamSeeds.map { .init(species: $0.species, display: $0.display) })

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

        print("replaying \(URL(fileURLWithPath: videoPath).lastPathComponent) to t=\(at)s…")
        let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "advisor", code: 1, userInfo: [NSLocalizedDescriptionKey: "no video track"])
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

        // ---- m12-A: the TEAM PREVIEW ask ---------------------------------
        // Ignores the reconciler entirely — preview is decided from the
        // frame-voted consensus + capsules alone, exactly like the app at
        // preview time.
        if preview {
            try await runPreview(aggregate: aggregate, vocabulary: vocabulary,
                                 dryRun: dryRun, nudge: nudge)
            return
        }

        // ---- deterministic matchup ---------------------------------------
        let snapshots = reconciler.activeSnapshots()
        let field = reconciler.liveFieldSpec()
        guard !snapshots.isEmpty else {
            throw NSError(domain: "advisor", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "no actives at t=\(at) — pick a mid-turn moment"])
        }
        // Mirror of the live tracker's m9 team merge: your side's configured
        // slot supplies the full set + real spread; observations still win.
        var membersByIdentity: [String: TeamMember] = [:]
        for m in loadedTeam.team.members {
            membersByIdentity[m.species.lowercased()] = m
            membersByIdentity[m.displayName(vocab: loadedTeam.vocab).lowercased()] = m
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

        let engineSource = try String(
            contentsOf: URL(fileURLWithPath: "\(repoRoot)/Tools/ScopeLensEngine/dist/engine.js"), encoding: .utf8)
        let meta = try? Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Tools/ScopeLensEngine/data/meta-regmbs3.json"))
        let engine = try ScoutEngine(engineSource: engineSource, metaJSON: meta)

        // ---- m12-B: reverse damage inference (offline twin of the app's
        // poll-loop drain) — verdicts land on entities BEFORE the turn
        // context renders, so the advisor sees the 🔎 hints.
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
            print("🔎 \(obs.attackerSpecies) \(obs.move) → \(obs.defenderDisplay) "
                  + "(\(obs.observedDamage) HP): \(summary)")
        }

        let matchup = (mine.isEmpty || theirs.isEmpty)
            ? nil : try engine.liveMatchup(mine: mine, theirs: theirs, field: field)

        let state = reconciler.state

        // ---- m11: static prefix (capsules) + volatile turn block ---------
        // Capsule species come from the reconciler (actives + bench incl.
        // unclaimed preview rows) — same source as the app, corrections
        // included.
        var seenSpecies = Set<String>()
        var capsuleSpecies: [String] = []
        for mon in state.oppSide.active + state.oppSide.bench {
            guard mon.speciesId != "unknown",
                  seenSpecies.insert(mon.speciesId).inserted else { continue }
            capsuleSpecies.append(mon.speciesId)
        }
        let executor = AdvisorToolExecutor(
            engine: engine, vocabulary: vocabulary,
            configuredTeam: loadedTeam.team.members.map(\.monSpec))
        let capsules = executor.buildCapsules(species: capsuleSpecies)
        let staticContext = AdvisorContext.buildStatic(
            yourTeam: loadedTeam.team.members, teamVocab: loadedTeam.vocab,
            capsules: capsules)
        let freshSnapshots = reconciler.activeSnapshots()  // m12-B hints included
        var turnContext = AdvisorContext.buildTurn(
            snapshots: freshSnapshots,
            field: field, matchup: matchup, state: state,
            recentEvents: reconciler.events,
            yourBench: state.yourSide.bench, oppBench: state.oppSide.bench,
            capsules: capsules)
        if let nudge { turnContext += "\n\nNOTE FROM THE PILOT: \(nudge)" }

        // m15-C: the same verify-and-repair hook the app passes.
        var configured: [String: LintContext.ConfiguredMon] = [:]
        for member in loadedTeam.team.members {
            let mon = LintContext.ConfiguredMon(moves: member.moves, item: member.item)
            configured[member.species.lowercased()] = mon
            configured[member.displayName(vocab: loadedTeam.vocab).lowercased()] = mon
        }
        let lintContext = LintContext.build(
            snapshots: freshSnapshots, field: field, matchup: matchup,
            state: state, yourBench: state.yourSide.bench,
            configured: configured, capsules: capsules)

        print("\n════════ BATTLE-STATIC CONTEXT (cacheable prefix) ════════")
        print(staticContext)
        print("\n════════ TURN CONTEXT (turn \(state.turn)) ════════")
        print(turnContext)

        guard !dryRun else {
            print("\n(dry run — no API call)")
            return
        }

        // ---- the real tool-use loop ---------------------------------------
        guard let key = envLocalKey() ?? AdvisorClient.resolveKey() else {
            throw NSError(domain: "advisor", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "no ANTHROPIC_API_KEY in .env.local or environment"])
        }
        let tools = try AdvisorToolCatalog.fromRepo(root: repoRoot)
        print("\n════════ AGENTIC LOOP (\(AdvisorClient().model), \(tools.count) tools) ════════")
        let advice = try await AdvisorClient().advise(
            staticContext: staticContext, turnContext: turnContext,
            tools: tools, apiKey: key,
            lintPlay: { play in PlayLint.lint(play: play, context: lintContext) },
            onProgress: { p in
                // m12-E live readout: replaces-previous updates rewrite the
                // terminal line in place (\r), appends get their own line.
                if p.replacesPrevious {
                    print("\r  ⋮ \(p.line)\u{1B}[K", terminator: "")
                } else {
                    print("\n  ⋮ \(p.line)", terminator: "")
                }
                fflush(stdout)
            }) { calls in
                // Offline executor: same handlers the app runs, called
                // directly — the harness is single-threaded around awaits.
                calls.map {
                    let r = executor.execute(name: $0.name, arguments: $0.input)
                    return AdvisorToolResult(id: $0.id, text: r.text, isError: r.isError)
                }
            }
        print("")

        for (i, thought) in advice.thoughts.enumerated() {
            print("🧠 [\(i + 1)] \(thought)")
        }
        if advice.trace.isEmpty {
            print("(no tool calls — answered from context)")
        }
        for entry in advice.trace {
            print("⚙️ \(entry.tool)\(entry.isError ? " [ERROR]" : "")")
            print("   in:  \(entry.inputSummary)")
            print("   out: \(entry.resultSummary)")
        }
        if let play = advice.play {
            print("\n════════ COMMITTED PLAY (m12-F) ════════"
                  + (advice.lintRepaired ? "  🧯 repaired after rule check" : ""))
            for action in play.actions {
                print("▶︎ \(action.displayLine)"
                      + (action.note.map { "   — \($0)" } ?? ""))
            }
            for finding in advice.lintFindings {
                print("\(finding.severity == .violation ? "❌" : "⚠️") [\(finding.rule)] \(finding.message)")
            }
        }
        print("\n════════ WHAT'S THE PLAY ════════")
        print(advice.text)
        print(String(format: "\n(%d round-trips · %d tool calls · %.1fs · " +
                     "tokens in %d / out %d · cache read %d / write %d)",
                     advice.iterations, advice.trace.count, advice.elapsed,
                     advice.inputTokens, advice.outputTokens,
                     advice.cacheReadTokens, advice.cacheWriteTokens))
    }

    /// m12-A: the agentic preview scout, offline. Consensus → heuristic
    /// baseline + capsules → the TEAM PREVIEW tool loop; prints both answers
    /// side by side so the heuristic-vs-agentic comparison is one eyeball.
    static func runPreview(aggregate: PreviewAggregate,
                           vocabulary: BattleVocabulary,
                           dryRun: Bool, nudge: String?) async throws {
        let consensus = aggregate.consensus.sorted { $0.row < $1.row }
        guard aggregate.frameCount >= 5, consensus.count == 6,
              consensus.allSatisfy({ !$0.speciesTop.isEmpty }) else {
            throw NSError(domain: "advisor", code: 4, userInfo: [NSLocalizedDescriptionKey:
                "preview consensus not stable (\(aggregate.frameCount) frames, \(consensus.count) rows) — the video's preview segment must be inside --at"])
        }
        let theirs = consensus.map { $0.speciesTop[0].name }
        print("preview consensus (\(aggregate.frameCount) frames): \(theirs.joined(separator: ", "))")

        let engineSource = try String(
            contentsOf: URL(fileURLWithPath: "\(repoRoot)/Tools/ScopeLensEngine/dist/engine.js"), encoding: .utf8)
        let meta = try? Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Tools/ScopeLensEngine/data/meta-regmbs3.json"))
        let engine = try ScoutEngine(engineSource: engineSource, metaJSON: meta)

        let mine = loadedTeam.team.members.map(\.monSpec)
        let scout = try engine.report(mine: mine, theirs: theirs)

        let executor = AdvisorToolExecutor(
            engine: engine, vocabulary: vocabulary, configuredTeam: mine)
        let capsules = executor.buildCapsules(species: theirs)
        let staticContext = AdvisorContext.buildStatic(
            yourTeam: loadedTeam.team.members, teamVocab: loadedTeam.vocab,
            capsules: capsules)
        var previewContext = AdvisorContext.buildPreview(scout: scout)
        if let nudge { previewContext += "\n\nNOTE FROM THE PILOT: \(nudge)" }

        print("\n════════ BATTLE-STATIC CONTEXT (cacheable prefix) ════════")
        print(staticContext)
        print("\n════════ TEAM PREVIEW CONTEXT ════════")
        print(previewContext)

        guard !dryRun else {
            print("\n(dry run — no API call)")
            return
        }

        guard let key = envLocalKey() ?? AdvisorClient.resolveKey() else {
            throw NSError(domain: "advisor", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "no ANTHROPIC_API_KEY in .env.local or environment"])
        }
        let tools = try AdvisorToolCatalog.fromRepo(root: repoRoot)
        let client = AdvisorClient.forPreview()
        print("\n════════ AGENTIC PREVIEW LOOP (\(client.model), \(tools.count) tools, "
              + "≤\(client.maxIterations) round-trips, \(Int(client.softDeadline))s budget) ════════")
        let advice = try await client.advise(
            staticContext: staticContext, turnContext: previewContext,
            tools: tools, volatileLabel: "TEAM PREVIEW",
            question: AdvisorContext.previewQuestion, apiKey: key,
            onProgress: { p in
                if p.replacesPrevious {
                    print("\r  ⋮ \(p.line)\u{1B}[K", terminator: "")
                } else {
                    print("\n  ⋮ \(p.line)", terminator: "")
                }
                fflush(stdout)
            }) { calls in
                calls.map {
                    let r = executor.execute(name: $0.name, arguments: $0.input)
                    return AdvisorToolResult(id: $0.id, text: r.text, isError: r.isError)
                }
            }
        print("")

        for (i, thought) in advice.thoughts.enumerated() {
            print("🧠 [\(i + 1)] \(thought)")
        }
        if advice.trace.isEmpty {
            print("(no tool calls — answered from context)")
        }
        for entry in advice.trace {
            print("⚙️ \(entry.tool)\(entry.isError ? " [ERROR]" : "")")
            print("   in:  \(entry.inputSummary)")
            print("   out: \(entry.resultSummary)")
        }
        print("\n════════ WHAT DO I BRING ════════")
        print("heuristic: bring \(scout.safeFour.joined(separator: ", ")) — leads \(scout.leads.joined(separator: " + "))")
        print("agentic:   \(advice.text)")
        print(String(format: "\n(%d round-trips · %d tool calls · %.1fs · " +
                     "tokens in %d / out %d · cache read %d / write %d)",
                     advice.iterations, advice.trace.count, advice.elapsed,
                     advice.inputTokens, advice.outputTokens,
                     advice.cacheReadTokens, advice.cacheWriteTokens))
    }

    /// ANTHROPIC_API_KEY from the repo's .env.local — value is returned,
    /// never printed.
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
