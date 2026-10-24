//
//  LiveCaptureProbe.swift
//  ScopeLens Diagnostics — live-capture spike harness (Phase 2, milestone 2).
//
//  Drives the app-target MirrorCaptureSource + ScreenStateClassifier against
//  the real QuickTime mirror window.
//
//  Build & run (from repo root):
//    swiftc -O Tools/ScopeLensDiagnostics/LiveCaptureProbe.swift \
//      "Packages/ScopeLens/Sources/ScopeLens/MirrorCaptureSource.swift" "Packages/ScopeLens/Sources/ScopeLens/ScreenStateClassifier.swift" \
//      -o /tmp/liveprobe && /tmp/liveprobe list
//
//  Modes:
//    list                         print shareable windows (find the mirror)
//    shot [--window ID]           capture once → raw + viewport PNGs + classify both
//    stream [--seconds N] [--fps N] [--window ID]
//                                 poll-capture, classify, print states + transitions
//
//  Output artifacts land in Fixtures/harvest/live-probe/ (gitignored).
//  First run triggers the macOS Screen Recording permission prompt.
//
//  Note: capture uses SCScreenshotManager polling — at a 2 fps advisory
//  cadence this is simpler than SCStream and costs nothing; the in-app
//  adapter can move to SCStream when we want event-driven frames.
//

import AppKit
import Foundation
import CoreGraphics
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

@main
struct LiveCaptureProbe {

    static let outDir = URL(fileURLWithPath: "\(scopeLensFixturesRoot)/harvest/live-probe")

    static func main() async {
        // CLI processes have no WindowServer connection; SCScreenshotManager
        // asserts (CGS_REQUIRE_INIT) without one. NSApplication bootstraps it.
        _ = NSApplication.shared
        var args = Array(CommandLine.arguments.dropFirst())
        let mode = args.isEmpty ? "list" : args.removeFirst()

        var windowID: UInt32?
        var seconds = 30.0
        var fps = 2.0
        while !args.isEmpty {
            let flag = args.removeFirst()
            func value() -> String? { args.isEmpty ? nil : args.removeFirst() }
            switch flag {
            case "--window": windowID = value().flatMap(UInt32.init)
            case "--seconds": seconds = value().flatMap(Double.init) ?? seconds
            case "--fps": fps = value().flatMap(Double.init) ?? fps
            default: fputs("unknown flag \(flag)\n", stderr); exit(2)
            }
        }

        do {
            switch mode {
            case "list": try await list()
            case "shot": try await shot(windowID: windowID)
            case "stream": try await stream(windowID: windowID, seconds: seconds, fps: fps)
            default: fputs("usage: liveprobe list|shot|stream [flags]\n", stderr); exit(2)
            }
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    // MARK: list

    static func list() async throws {
        let windows = try await MirrorCapture.shareableWindows()
        print("shareable windows (\(windows.count)):")
        for (_, c) in windows.sorted(by: { $0.1.appName < $1.1.appName }) {
            print(String(format: "  id %-8d %-28s %-24s %4.0f×%-4.0f %@ \"%@\"",
                         c.windowID, (c.appName as NSString).utf8String!,
                         (c.bundleID as NSString).utf8String!,
                         c.frame.width, c.frame.height,
                         c.isOnScreen ? "on-screen " : "off-screen", c.title))
        }
        if let (_, mirror) = MirrorCapture.findQuickTimeMirror(in: windows) {
            print("\nauto-pick QuickTime mirror → id \(mirror.windowID) \"\(mirror.title)\" \(Int(mirror.frame.width))×\(Int(mirror.frame.height)) pt")
        } else {
            print("\nno QuickTime window found — is the mirror up? (pass --window ID to override)")
        }
    }

    // MARK: shot

    static func resolveWindow(_ windowID: UInt32?) async throws -> (SCWindow, CaptureCandidate) {
        let windows = try await MirrorCapture.shareableWindows()
        if let id = windowID {
            guard let match = windows.first(where: { $0.1.windowID == id }) else {
                throw NSError(domain: "LiveCaptureProbe", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "window id \(id) not shareable"])
            }
            return match
        }
        guard let mirror = MirrorCapture.findQuickTimeMirror(in: windows) else {
            throw NSError(domain: "LiveCaptureProbe", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "no QuickTime window — run 'list'"])
        }
        return mirror
    }

    static func shot(windowID: UInt32?) async throws {
        let (window, c) = try await resolveWindow(windowID)
        print("capturing id \(c.windowID) \"\(c.title)\" (\(c.appName)) \(Int(c.frame.width))×\(Int(c.frame.height)) pt …")

        let raw = try await MirrorCapture.captureOnce(window)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let rawURL = outDir.appendingPathComponent("probe_raw.png")
        writePNG(raw, to: rawURL)
        print("raw capture: \(raw.width)×\(raw.height) px → \(rawURL.path)")

        let classifier = ScreenStateClassifier()
        let rawResult = try classifier.classify(image: raw)
        print("classify(raw):      \(describe(rawResult))")

        if let rect = ViewportDetector.detect(in: raw) {
            print(String(format: "viewport: (%.0f, %.0f, %.0f×%.0f) px  aspect %.3f (game %.3f)",
                         rect.origin.x, rect.origin.y, rect.width, rect.height,
                         rect.width / rect.height, ViewportDetector.gameAspect))
            if let cropped = raw.cropping(to: rect) {
                let vpURL = outDir.appendingPathComponent("probe_viewport.png")
                writePNG(cropped, to: vpURL)
                print("viewport crop → \(vpURL.path)")
                let vpResult = try classifier.classify(image: cropped)
                print("classify(viewport): \(describe(vpResult))")
            }
        } else {
            print("viewport: NOT FOUND — inspect probe_raw.png")
        }
    }

    // MARK: stream

    static func stream(windowID: UInt32?, seconds: Double, fps: Double) async throws {
        let (window, c) = try await resolveWindow(windowID)
        print("streaming id \(c.windowID) \"\(c.title)\" @ \(fps) fps for \(Int(seconds))s …")

        // Calibrate the viewport once on the first frame (§4.2: once per source).
        let first = try await MirrorCapture.captureOnce(window)
        guard let viewport = ViewportDetector.detect(in: first) else {
            throw NSError(domain: "LiveCaptureProbe", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "viewport not found on first frame"])
        }
        print(String(format: "viewport calibrated: (%.0f, %.0f, %.0f×%.0f) px\n",
                     viewport.origin.x, viewport.origin.y, viewport.width, viewport.height))

        // Live keyframe harvest, mirroring SessionRecorder's debounce: a new
        // primary must hold 2 consecutive samples; the confirming frame is
        // saved (unknowns half-res). This is how never-seen screens (e.g. the
        // post-battle rating screen) become fixtures automatically.
        let stamp: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"
            return f.string(from: Date())
        }()
        let harvestDir = outDir.appendingPathComponent("live-\(stamp)")
        try FileManager.default.createDirectory(at: harvestDir, withIntermediateDirectories: true)
        print("harvesting transition keyframes → \(harvestDir.path)\n")

        let classifier = ScreenStateClassifier()
        var lastPrimary: ScreenState?
        var confirmed: ScreenState?
        var candidate: (state: ScreenState, count: Int)?
        var keyframeCount = 0
        let interval = 1.0 / fps
        let deadline = Date().addingTimeInterval(seconds)

        while Date() < deadline {
            let tick = Date()
            do {
                let frame = try await MirrorCapture.captureOnce(window)
                guard let cropped = frame.cropping(to: viewport) else { continue }
                let r = try classifier.classify(image: cropped)
                let marker = r.primary != lastPrimary ? "▶" : " "
                print("\(marker) \(hhmmss()) \(describe(r))")
                lastPrimary = r.primary

                if r.primary == confirmed {
                    candidate = nil
                } else if candidate?.state == r.primary {
                    candidate!.count += 1
                    if candidate!.count >= 2 {
                        keyframeCount += 1
                        let name = String(format: "%03d_%@_%@.png", keyframeCount,
                                          hhmmss().replacingOccurrences(of: ":", with: "-"),
                                          r.primary.rawValue)
                        let img = r.primary == .unknown
                            ? (cropped.scopeScaled(by: 0.5) ?? cropped) : cropped
                        writePNG(img, to: harvestDir.appendingPathComponent(name))
                        confirmed = r.primary
                        candidate = nil
                    }
                } else {
                    candidate = (r.primary, 1)
                }
            } catch {
                print("  \(hhmmss()) capture error: \(error.localizedDescription)")
            }
            let elapsed = Date().timeIntervalSince(tick)
            if elapsed < interval {
                try await Task.sleep(nanoseconds: UInt64((interval - elapsed) * 1e9))
            }
        }
        print("\nstream done — \(keyframeCount) keyframes in \(harvestDir.path)")
    }

    // MARK: helpers

    static func describe(_ r: ScreenStateClassification) -> String {
        let overlays = r.overlays.isEmpty
            ? "" : " +[\(r.overlays.map(\.rawValue).sorted().joined(separator: ","))]"
        return "\(r.primary.rawValue)\(overlays) (conf \(String(format: "%.2f", r.confidence)))"
    }

    static func hhmmss() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.S"
        return f.string(from: Date())
    }

    static func writePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
