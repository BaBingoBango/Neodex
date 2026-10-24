//
//  SessionRecorder.swift
//  ScopeLens Diagnostics — offline session recorder (Phase 2, milestone 1B).
//
//  Streams a recorded battle video through ScreenStateClassifier at ~2 fps and
//  produces a state timeline plus a keyframe PNG at every confirmed state
//  transition — the fixture auto-harvest loop (spec §11 Phase 2). Later these
//  keyframes also feed the Champions-native sprite reference set.
//
//  Build & run (from repo root):
//    swiftc -O Tools/ScopeLensDiagnostics/SessionRecorder.swift "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" \
//      -o /tmp/sessionrecorder && /tmp/sessionrecorder
//
//  Options:
//    --video PATH      input movie (default: the gitignored full-battle .mov)
//    --fps N           sampling rate, default 2.0
//    --scale X         OCR downscale factor, default 0.5 (harness-validated)
//    --start S         skip into the video (seconds)
//    --duration S      only process this many seconds
//    --out DIR         session dir (default Fixtures/harvest/<stem>_<stamp>/)
//
//  The video is decoded sequentially (AVAssetReader) and sampled by
//  presentation timestamp — QuickTime mirror recordings are variable frame
//  rate, so frame counting would drift. Keyframes are written at full
//  resolution; OCR runs on a downscaled copy for speed.
//

import Foundation
import AVFoundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

// MARK: - Timeline records

struct Sample: Codable {
    let t: Double
    let primary: String
    let overlays: [String]
    let confidence: Double
}

struct Transition: Codable {
    let t: Double
    let from: String
    let to: String
    let keyframe: String
}

struct Segment: Codable {
    let primary: String
    let start: Double
    let end: Double
}

struct Timeline: Codable {
    let video: String
    let fps: Double
    let scale: Double
    let confirmSamples: Int
    let generatedAt: String
    var samples: [Sample]
    var transitions: [Transition]
    var segments: [Segment]
    var unknownGaps: [Segment]
}

// MARK: - Entry

@main
struct SessionRecorder {

    static func main() async {
        var videoPath = "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max/Full Battle Video from QuickTime.mov"
        var fps = 2.0
        var scale = 0.5
        var startAt = 0.0
        var duration = Double.infinity
        var outDir: String?

        var args = Array(CommandLine.arguments.dropFirst())
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
            default:
                fputs("unknown flag \(flag)\n", stderr)
                exit(2)
            }
        }

        let videoURL = URL(fileURLWithPath: videoPath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            fputs("error: video not found at \(videoURL.path) — run from the repo root\n", stderr)
            exit(2)
        }

        let stamp: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"
            return f.string(from: Date())
        }()
        let stem = videoURL.deletingPathExtension().lastPathComponent
            .lowercased().replacingOccurrences(of: " ", with: "-")
        let sessionDir = URL(fileURLWithPath: outDir ?? "\(scopeLensFixturesRoot)/harvest/\(stem)_\(stamp)")
        let keyframeDir = sessionDir.appendingPathComponent("keyframes")
        try! FileManager.default.createDirectory(at: keyframeDir, withIntermediateDirectories: true)

        print("session: \(sessionDir.path)")
        print("video:   \(videoPath)")
        print("fps \(fps) · OCR scale \(scale) · start \(startAt)s · duration \(duration.isFinite ? "\(duration)s" : "full")\n")

        do {
            try await record(videoURL: videoURL, fps: fps, scale: CGFloat(scale), startAt: startAt,
                             duration: duration, sessionDir: sessionDir, keyframeDir: keyframeDir)
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    // MARK: Core loop

    static func record(videoURL: URL, fps: Double, scale: CGFloat, startAt: Double,
                       duration: Double, sessionDir: URL, keyframeDir: URL) async throws {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "SessionRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "no video track"])
        }

        let reader = try AVAssetReader(asset: asset)
        if startAt > 0 || duration.isFinite {
            let start = CMTime(seconds: startAt, preferredTimescale: 600)
            let dur = duration.isFinite
                ? CMTime(seconds: duration, preferredTimescale: 600)
                : CMTime.positiveInfinity
            reader.timeRange = CMTimeRange(start: start, duration: dur)
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()

        let ciContext = CIContext(options: [.cacheIntermediates: false])
        let classifier = ScreenStateClassifier()
        let sampleInterval = 1.0 / fps
        let confirmSamples = 2 // state must hold this many consecutive samples (1s at 2 fps)
        let maxKeyframes = 500 // safety valve against a misbehaving classifier flooding the disk

        var timeline = Timeline(
            video: videoURL.lastPathComponent, fps: fps, scale: Double(scale),
            confirmSamples: confirmSamples,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            samples: [], transitions: [], segments: [], unknownGaps: []
        )

        var nextSampleTime = startAt
        var confirmed: (state: ScreenState, since: Double)? = nil
        var candidate: (state: ScreenState, since: Double, count: Int, image: CGImage)? = nil
        var keyframeCount = 0
        let wallStart = Date()

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            autoreleasepool {
                defer { CMSampleBufferInvalidate(sampleBuffer) }
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                guard pts >= nextSampleTime,
                      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                nextSampleTime += sampleInterval
                // A VFR stall can jump past several sample slots; realign.
                if nextSampleTime < pts { nextSampleTime = pts + sampleInterval }

                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                guard let full = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
                guard let small = downscale(full, by: scale) else { return }

                guard let result = try? classifier.classify(image: small) else { return }
                timeline.samples.append(Sample(
                    t: round2(pts), primary: result.primary.rawValue,
                    overlays: result.overlays.map(\.rawValue).sorted(),
                    confidence: result.confidence
                ))

                // Debounce: a new primary must hold `confirmSamples` consecutive
                // samples before it becomes a transition + harvested keyframe.
                if result.primary == confirmed?.state {
                    candidate = nil
                } else if candidate?.state == result.primary {
                    candidate!.count += 1
                    // Keep the newest frame: the run's first frame is often a
                    // mid-fade/transition frame — the confirming one harvests better.
                    candidate!.image = full
                    if candidate!.count >= confirmSamples {
                        let from = confirmed?.state.rawValue ?? "start"
                        if let prev = confirmed {
                            timeline.segments.append(Segment(
                                primary: prev.state.rawValue,
                                start: round2(prev.since), end: round2(candidate!.since)
                            ))
                        }
                        keyframeCount += 1
                        // mm-ss stamp, colon-free for Finder/export friendliness
                        let stamp = mmss(candidate!.since).replacingOccurrences(of: ":", with: "-")
                        let name = String(format: "%03d_%@_%@.png",
                                          keyframeCount, stamp, result.primary.rawValue)
                        let url = keyframeDir.appendingPathComponent(name)
                        if keyframeCount <= maxKeyframes {
                            // unknown keyframes are eyeball-only (gap analysis) —
                            // half res keeps the harvest dir manageable; real
                            // fixtures re-extract from the .mov by timestamp.
                            let img = result.primary == .unknown
                                ? (downscale(candidate!.image, by: 0.5) ?? candidate!.image)
                                : candidate!.image
                            writePNG(img, to: url)
                        }
                        timeline.transitions.append(Transition(
                            t: round2(candidate!.since), from: from,
                            to: result.primary.rawValue, keyframe: "keyframes/\(name)"
                        ))
                        print(String(format: "  %@  %@ → %@", mmss(candidate!.since), from, result.primary.rawValue))
                        confirmed = (result.primary, candidate!.since)
                        candidate = nil
                    }
                } else {
                    candidate = (result.primary, pts, 1, full)
                }

                let n = timeline.samples.count
                if n % 120 == 0 {
                    let rate = Double(n) / max(Date().timeIntervalSince(wallStart), 0.001)
                    print(String(format: "  … t=%@  %d samples  (%.1f samples/s wall)", mmss(pts), n, rate))
                }
            }
        }
        if reader.status == .failed {
            throw reader.error ?? NSError(domain: "SessionRecorder", code: 2,
                                          userInfo: [NSLocalizedDescriptionKey: "reader failed"])
        }

        // Close the final open segment.
        if let last = confirmed, let lastT = timeline.samples.last?.t {
            timeline.segments.append(Segment(primary: last.state.rawValue,
                                             start: round2(last.since), end: lastT))
        }
        timeline.unknownGaps = timeline.segments.filter {
            $0.primary == ScreenState.unknown.rawValue && $0.end - $0.start >= 3.0
        }

        try writeOutputs(timeline: timeline, sessionDir: sessionDir)
        print("\ndone: \(timeline.samples.count) samples, \(timeline.transitions.count) transitions, "
              + "\(timeline.unknownGaps.count) persistent unknown gaps")
        print("report: \(sessionDir.appendingPathComponent("report.md").path)")
    }

    // MARK: Outputs

    static func writeOutputs(timeline: Timeline, sessionDir: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(timeline).write(to: sessionDir.appendingPathComponent("timeline.json"))

        var md = "# Session report — \(timeline.video)\n\n"
        md += "- generated: \(timeline.generatedAt)\n"
        md += "- sampling: \(timeline.fps) fps, OCR scale \(timeline.scale), confirm ≥\(timeline.confirmSamples) samples\n"
        md += "- samples: \(timeline.samples.count) · transitions: \(timeline.transitions.count)\n\n"

        md += "## State timeline (confirmed segments)\n\n"
        md += "| start | end | state | duration |\n|---|---|---|---|\n"
        for s in timeline.segments {
            md += "| \(mmss(s.start)) | \(mmss(s.end)) | \(s.primary) | \(String(format: "%.1f", s.end - s.start))s |\n"
        }

        md += "\n## Transitions & harvested keyframes\n\n"
        md += "| t | from → to | keyframe |\n|---|---|---|\n"
        for tr in timeline.transitions {
            md += "| \(mmss(tr.t)) | \(tr.from) → \(tr.to) | \(tr.keyframe) |\n"
        }

        md += "\n## Persistent unknown gaps (≥3s — fixture-gap candidates)\n\n"
        if timeline.unknownGaps.isEmpty {
            md += "None — every ≥3s segment classified.\n"
        } else {
            for g in timeline.unknownGaps {
                md += "- \(mmss(g.start))–\(mmss(g.end)) (\(String(format: "%.1f", g.end - g.start))s)\n"
            }
            md += "\nShorter unknown blips are expected transition animations (cutscenes carry no text).\n"
        }

        let lowConf = timeline.samples.filter { $0.primary != "unknown" && $0.confidence < 0.35 }
        md += "\n## Low-confidence non-unknown samples: \(lowConf.count)\n"
        for s in lowConf.prefix(20) {
            md += "- t=\(mmss(s.t)) \(s.primary) conf \(s.confidence)\n"
        }

        try md.write(to: sessionDir.appendingPathComponent("report.md"),
                     atomically: true, encoding: .utf8)
    }

    // MARK: Helpers

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

    static func writePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    static func mmss(_ t: Double) -> String {
        String(format: "%02d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60))
    }

    static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
}
