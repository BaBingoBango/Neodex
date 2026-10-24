//
//  BattleReplayHarness.swift
//  ScopeLens Diagnostics — Phase 2 m4: the paper replay.
//
//  Streams a recorded battle through classifier → BattleEventParser →
//  BattleReconciler and writes the human-readable battle log + final
//  BattleState + events JSON. This is the offline twin of the Phase-3 live
//  tracker loop, and the m4 "done when": battles 2 & 3 produce plausible
//  logs Ethan can eyeball.
//
//  Build & run (from repo root):
//    swiftc -O Tools/ScopeLensDiagnostics/BattleReplayHarness.swift \
//      "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleVocabulary.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/BattleState.swift" "Packages/ScopeLens/Sources/ScopeLens/BattleEventParser.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/BattleReconciler.swift" "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
//      "Packages/ScopeLens/Sources/ScopeLens/TeamStore.swift" \
//      -o /tmp/battlereplay && /tmp/battlereplay replay --video "\(scopeLensFixturesRoot)/…/Example Battle 3.mov"
//
//  Modes:
//    replay    [--video PATH] [--fps N] [--scale X] [--start S] [--duration S]
//              [--out DIR] [--dump]
//              → <out>/battle-log.md, events.json, battlestate.json
//              (--dump adds observations.jsonl: per-frame parser output)
//    fixtures  run the committed token fixtures under
//              Tools/ScopeLensDiagnostics/fixtures/battle-events/ — the m4 regression stage
//              of verify-all.sh. Exit 0 iff all pass.
//
//  During the video's teamPreview segment the PreviewPipeline votes a
//  consensus (≤1 Hz, full-res frames) which seeds the reconciler's opponent
//  bench — exactly what the live tracker does. Videos without a preview
//  (battle 2 starts mid-battle) bootstrap from narration alone.
//

import Foundation
import AVFoundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

@main
struct BattleReplayHarness {

    static let repoRoot = FileManager.default.currentDirectoryPath

    /// The pilot's team, from the committed default paste (m9) — the same
    /// file the app bundles, so replays and live runs agree by construction.
    /// (TeamStore.swift compiles here without pulling in JavaScriptCore.)
    static let yourTeamSeeds: [(species: String, display: String)] = {
        guard let (team, vocab, issues) = try? Team.fromRepoDefault(root: repoRoot),
              !issues.contains(where: { $0.severity == .error }) else {
            fputs("error: cannot load \(Team.defaultPasteRepoPath) — run from the repo root\n", stderr)
            exit(2)
        }
        return team.teamSeeds(vocab: vocab)
    }()

    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        let mode = args.isEmpty ? "replay" : args.removeFirst()
        do {
            switch mode {
            case "replay": try await replay(args: args)
            case "fixtures": try fixtures()
            default:
                fputs("usage: battlereplay replay|fixtures [flags]\n", stderr)
                exit(2)
            }
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    // MARK: - replay

    static func replay(args argsIn: [String]) async throws {
        var videoPath = "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max/Example Battle 3.mov"
        var fps = 2.0, scale = 0.5, startAt = 0.0, duration = Double.infinity
        var outDir: String?
        var dump = false

        var args = argsIn
        while !args.isEmpty {
            let flag = args.removeFirst()
            func value() -> String? { args.isEmpty ? nil : args.removeFirst() }
            switch flag {
            case "--video": videoPath = value() ?? videoPath
            case "--fps": fps = value().flatMap(Double.init) ?? fps
            case "--scale": scale = value().flatMap(Double.init) ?? scale
            case "--start": startAt = value().flatMap(Double.init) ?? startAt
            case "--duration": duration = value().flatMap(Double.init) ?? duration
            case "--out": outDir = value()
            case "--dump": dump = true
            default: fputs("unknown flag \(flag)\n", stderr); exit(2)
            }
        }

        let videoURL = URL(fileURLWithPath: videoPath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            fputs("error: video not found at \(videoURL.path) — run from the repo root\n", stderr)
            exit(2)
        }

        let stem = videoURL.deletingPathExtension().lastPathComponent
            .lowercased().replacingOccurrences(of: " ", with: "-")
        let stamp: String = {
            let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; return f.string(from: Date())
        }()
        let sessionDir = URL(fileURLWithPath: outDir ?? "\(scopeLensFixturesRoot)/harvest/replay-\(stem)_\(stamp)")
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        let vocabulary = try BattleVocabulary.fromRepo(root: repoRoot)
        let classifier = ScreenStateClassifier()
        let observer = VisionFrameObserver()
        let parser = BattleEventParser(vocabulary: vocabulary)
        let reconciler = BattleReconciler(
            vocabulary: vocabulary,
            yourTeam: yourTeamSeeds.map { .init(species: $0.species, display: $0.display) })

        // Preview pipeline is optional — resources may be absent (gitignored
        // dex features); the replay then runs narration-bootstrap only.
        let pipeline: PreviewPipeline? = {
            do {
                let templates = try Data(contentsOf: URL(fileURLWithPath: "\(scopeLensFixturesRoot)/type-templates/templates.json"))
                let index = try Data(contentsOf: URL(fileURLWithPath: "\(scopeLensFixturesRoot)/reference/species-index.json"))
                guard let sheet = loadImage("\(scopeLensFixturesRoot)/reference/pokemonicons-sheet.png") else { return nil }
                let dexFeatures = try? Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Packages/ScopeLens/Sources/ScopeLens/Resources/PreviewPipeline/dex-features.json"))
                let nativeFeatures = try? Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Packages/ScopeLens/Sources/ScopeLens/Resources/PreviewPipeline/native-features.json"))
                return PreviewPipeline(
                    typeCore: try TypeIconCore(templatesJSON: templates),
                    speciesCore: try SpeciesCore(indexJSON: index, sheet: sheet,
                                                 dexFeaturesJSON: dexFeatures,
                                                 nativeFeaturesJSON: nativeFeatures))
            } catch {
                fputs("note: preview pipeline unavailable (\(error)) — narration bootstrap only\n", stderr)
                return nil
            }
        }()

        print("replay: \(videoURL.lastPathComponent)")
        print("out:    \(sessionDir.path)")
        print("fps \(fps) · OCR scale \(scale)\(pipeline == nil ? " · NO preview pipeline" : "")\n")

        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "replay", code: 1, userInfo: [NSLocalizedDescriptionKey: "no video track"])
        }
        let reader = try AVAssetReader(asset: asset)
        if startAt > 0 || duration.isFinite {
            reader.timeRange = CMTimeRange(
                start: CMTime(seconds: startAt, preferredTimescale: 600),
                duration: duration.isFinite ? CMTime(seconds: duration, preferredTimescale: 600) : .positiveInfinity)
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()

        let ciContext = CIContext(options: [.cacheIntermediates: false])
        var nextSampleTime = startAt
        let sampleInterval = 1.0 / fps
        var aggregate = PreviewAggregate()
        var lastPreviewPipelineRun = -10.0
        var previewSeeded = false
        var framesSincePreview = 0
        var dumpLines: [String] = []
        var sampleCount = 0
        let wallStart = Date()

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            autoreleasepool {
                defer { CMSampleBufferInvalidate(sampleBuffer) }
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                guard pts >= nextSampleTime,
                      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                nextSampleTime += sampleInterval
                if nextSampleTime < pts { nextSampleTime = pts + sampleInterval }

                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                guard let full = ciContext.createCGImage(ciImage, from: ciImage.extent),
                      let small = downscale(full, by: CGFloat(scale)),
                      let tokens = try? observer.observe(small) else { return }
                sampleCount += 1

                let classification = classifier.classify(tokens: tokens)
                let obs = parser.observe(tokens: tokens, classification: classification, t: pts)

                // Preview consensus (live-tracker twin): vote at ≤1 Hz on
                // full-res frames while the preview is up; seed when it ends.
                if classification.primary == .teamPreview, let pipeline {
                    framesSincePreview = 0
                    if pts - lastPreviewPipelineRun >= 1.0, let read = pipeline.read(frame: full) {
                        aggregate.add(read)
                        lastPreviewPipelineRun = pts
                    }
                } else if aggregate.frameCount >= 3, !previewSeeded {
                    framesSincePreview += 1
                    if framesSincePreview >= 4 { // preview confidently over
                        previewSeeded = true
                        let seeds = aggregate.consensus.map {
                            BattleReconciler.PreviewSeed(
                                row: $0.row, speciesTop: $0.speciesTop.map(\.name), types: $0.typePair)
                        }
                        reconciler.seedPreview(seeds, t: pts)
                        print(String(format: "  %@  preview consensus seeded (%d rows, %d frames)",
                                     mmss(pts), seeds.count, aggregate.frameCount))
                    }
                }

                reconciler.ingest(obs)

                if dump {
                    var line: [String: Any] = ["t": round2(pts), "primary": classification.primary.rawValue]
                    if let b = obs.banner { line["banner"] = b }
                    if !obs.chips.isEmpty { line["chips"] = obs.chips.map { "\($0.sideHint):\($0.subjectRaw)/\($0.thingRaw)" } }
                    if !obs.hpReads.isEmpty { line["hp"] = obs.hpReads.map { "\($0.side):\($0.nameRaw)=\($0.hp.display)\($0.bench ? " (bench)" : "")" } }
                    if !obs.fieldStatuses.isEmpty { line["field"] = obs.fieldStatuses.map { "\($0.name) \($0.remaining)/\($0.total)" } }
                    if let d = try? JSONSerialization.data(withJSONObject: line, options: [.sortedKeys]),
                       let s = String(data: d, encoding: .utf8) { dumpLines.append(s) }
                }

                if sampleCount % 120 == 0 {
                    let rate = Double(sampleCount) / max(Date().timeIntervalSince(wallStart), 0.001)
                    print(String(format: "  … t=%@  %d samples  %d events  (%.1f samples/s)",
                                 mmss(pts), sampleCount, reconciler.events.count, rate))
                }
            }
        }
        if reader.status == .failed { throw reader.error ?? NSError(domain: "replay", code: 2) }

        // ---- outputs ------------------------------------------------------
        let log = reconciler.renderLog(title: videoURL.lastPathComponent)
        try log.write(to: sessionDir.appendingPathComponent("battle-log.md"),
                      atomically: true, encoding: .utf8)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(reconciler.events).write(to: sessionDir.appendingPathComponent("events.json"))
        try encoder.encode(reconciler.state).write(to: sessionDir.appendingPathComponent("battlestate.json"))
        if dump {
            try dumpLines.joined(separator: "\n")
                .write(to: sessionDir.appendingPathComponent("observations.jsonl"),
                       atomically: true, encoding: .utf8)
        }

        let unrecognized = reconciler.events.filter { $0.kind == .note && $0.detail == nil }.count
        print("\ndone: \(sampleCount) samples → \(reconciler.events.count) events "
              + "(\(unrecognized) unrecognized banners, \(reconciler.anomalies.count) anomalies, "
              + "\(reconciler.corrections.count) preview corrections)")
        print("log: \(sessionDir.appendingPathComponent("battle-log.md").path)")
    }

    // MARK: - fixtures (verify-all stage)

    struct TokenFixture: Codable {
        struct Token: Codable {
            let text: String
            let conf: Float
            let x: Double, y: Double, w: Double, h: Double
        }
        struct Frame: Codable {
            let t: Double?
            let tokens: [Token]
            /// m13-D: a scripted pilot bind ("Toucan sam" → Toucannon),
            /// applied AFTER this frame's observations — mirrors how the
            /// Battle Log card's tap reaches the reconciler mid-stream.
            let bindNickname: BindAction?
        }
        struct BindAction: Codable {
            let display: String
            let species: String
        }
        struct Expectation: Codable {
            let kind: String
            let side: String?
            let subject: String?
            let species: String?
            let detail: String?
            let value: String?
        }
        struct PreviewSeedFixture: Codable {
            let row: Int
            let speciesTop: [String]
            let types: [String]
        }
        /// Final-state assertion against activeSnapshots() (m12-D): only
        /// the provided fields are checked, matched by species.
        struct SnapshotExpectation: Codable {
            let species: String
            let protectedLastTurn: Bool?
            let protectStreak: Int?
            let choiceLockedMove: String?
            /// Non-zero stages, exact match ({} = all neutral) — m13-F
            /// pins the White Herb restore.
            let boosts: [String: Int]?
        }
        let name: String
        let notes: String?
        let synthetic: Bool?
        let previewSeeds: [PreviewSeedFixture]?
        let frames: [Frame]
        let expectEvents: [Expectation]
        let expectAnomalyContains: String?
        let forbidEventKinds: [String]?
        let forbidEvents: [Expectation]?   // full field-match forbids (e.g. a kind allowed on one side only)
        let expectExactKindCounts: [String: Int]?   // dedup assertions ("exactly one megaEvolved")
        let expectSnapshots: [SnapshotExpectation]? // final active-snapshot state (m12-D)
    }

    static func fixtures() throws {
        let dir = "\(repoRoot)/Tools/ScopeLensDiagnostics/fixtures/battle-events"
        let files = (try FileManager.default.contentsOfDirectory(atPath: dir))
            .filter { $0.hasSuffix(".json") }.sorted()
        guard !files.isEmpty else {
            fputs("no fixtures under \(dir)\n", stderr)
            exit(1)
        }

        let vocabulary = try BattleVocabulary.fromRepo(root: repoRoot)
        let classifier = ScreenStateClassifier()
        let parser = BattleEventParser(vocabulary: vocabulary)
        var passed = 0, failed = 0

        for file in files {
            let fixture = try JSONDecoder().decode(
                TokenFixture.self,
                from: Data(contentsOf: URL(fileURLWithPath: "\(dir)/\(file)")))
            let reconciler = BattleReconciler(
                vocabulary: vocabulary,
                yourTeam: yourTeamSeeds.map { .init(species: $0.species, display: $0.display) })
            if let seeds = fixture.previewSeeds {
                reconciler.seedPreview(seeds.map {
                    .init(row: $0.row, speciesTop: $0.speciesTop, types: $0.types)
                }, t: 0)
            }

            var t = 0.0
            for frame in fixture.frames {
                let at = frame.t ?? t
                t = at + 0.5
                let tokens = frame.tokens.map {
                    OCRToken(text: $0.text, confidence: $0.conf,
                             center: CGPoint(x: $0.x, y: $0.y),
                             size: CGSize(width: $0.w, height: $0.h))
                }
                let classification = classifier.classify(tokens: tokens)
                reconciler.ingest(parser.observe(tokens: tokens, classification: classification, t: at))
                if let bind = frame.bindNickname {
                    reconciler.bindNickname(displayName: bind.display,
                                            species: bind.species, t: at)
                }
            }

            var problems: [String] = []
            var cursor = 0
            for expect in fixture.expectEvents {
                var hit = false
                while cursor < reconciler.events.count {
                    let e = reconciler.events[cursor]
                    cursor += 1
                    if matches(e, expect) { hit = true; break }
                }
                if !hit {
                    problems.append("missing event \(expect.kind)"
                        + (expect.detail.map { " (\($0))" } ?? "")
                        + (expect.subject.map { " for \($0)" } ?? ""))
                }
            }
            if let needle = fixture.expectAnomalyContains,
               !reconciler.anomalies.contains(where: { $0.localizedCaseInsensitiveContains(needle) }) {
                problems.append("missing anomaly containing “\(needle)”")
            }
            for forbidden in fixture.forbidEventKinds ?? [] {
                if reconciler.events.contains(where: { $0.kind.rawValue == forbidden }) {
                    problems.append("forbidden event \(forbidden) was emitted")
                }
            }
            for forbidden in fixture.forbidEvents ?? [] {
                if reconciler.events.contains(where: { matches($0, forbidden) }) {
                    problems.append("forbidden event \(forbidden.kind)"
                        + (forbidden.side.map { "/\($0)" } ?? "") + " was emitted")
                }
            }
            for (kind, expected) in fixture.expectExactKindCounts ?? [:] {
                let actual = reconciler.events.filter { $0.kind.rawValue == kind }.count
                if actual != expected {
                    problems.append("expected exactly \(expected) \(kind), got \(actual)")
                }
            }
            if let snapshotExpectations = fixture.expectSnapshots {
                let snapshots = reconciler.activeSnapshots()
                for expect in snapshotExpectations {
                    guard let s = snapshots.first(where: { $0.species == expect.species }) else {
                        problems.append("no active snapshot for \(expect.species)")
                        continue
                    }
                    if let want = expect.protectedLastTurn, s.protectedLastTurn != want {
                        problems.append("\(expect.species) protectedLastTurn: expected \(want), got \(s.protectedLastTurn)")
                    }
                    if let want = expect.protectStreak, s.protectStreak != want {
                        problems.append("\(expect.species) protectStreak: expected \(want), got \(s.protectStreak)")
                    }
                    if let want = expect.choiceLockedMove, s.choiceLockedMove != want {
                        problems.append("\(expect.species) choiceLockedMove: expected \(want), got \(s.choiceLockedMove ?? "nil")")
                    }
                    if let want = expect.boosts, s.boosts != want {
                        problems.append("\(expect.species) boosts: expected \(want), got \(s.boosts)")
                    }
                }
            }

            if problems.isEmpty {
                passed += 1
                print("PASS \(fixture.name)")
            } else {
                failed += 1
                print("FAIL \(fixture.name)")
                for p in problems { print("       - \(p)") }
                print("       emitted: " + reconciler.events.map {
                    "\($0.kind.rawValue)\($0.detail.map { d in "(\(d))" } ?? "")"
                }.joined(separator: ", "))
            }
        }

        print("\nbattle-event fixtures: \(passed)/\(passed + failed) passed")
        exit(failed == 0 ? 0 : 1)
    }

    static func matches(_ e: BattleEvent, _ x: TokenFixture.Expectation) -> Bool {
        guard e.kind.rawValue == x.kind else { return false }
        if let v = x.side, e.side != v { return false }
        if let v = x.subject, e.subject != v { return false }
        if let v = x.species, e.species != v { return false }
        if let v = x.detail, e.detail != v { return false }
        if let v = x.value, e.value != v { return false }
        return true
    }

    // MARK: - helpers

    static func loadImage(_ path: String) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return img
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

    static func mmss(_ t: Double) -> String {
        String(format: "%02d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60))
    }

    static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
}
