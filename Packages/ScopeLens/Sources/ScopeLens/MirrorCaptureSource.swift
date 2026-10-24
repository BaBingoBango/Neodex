//
//  MirrorCaptureSource.swift
//  Scope Lens
//
//  Phase 2, milestone 2: the §4.2 capture adapter for the wired-iPhone
//  QuickTime mirror. One adapter per source; everything downstream of
//  `FrameObserver`/`ScreenStateClassifier` never knows how frames arrive.
//
//  Responsibilities:
//  - Discover the QuickTime mirror window among shareable windows.
//  - One-shot capture (probe/calibration) and throttled continuous capture.
//  - Viewport detection: trim window chrome/letterboxing to the game rect,
//    auto-calibrated per source (spec §4.2), so downstream sees only game
//    pixels and normalized coordinates stay source-independent.
//

import Foundation
import CoreGraphics
import ScreenCaptureKit

// MARK: - Window discovery

nonisolated public struct CaptureCandidate: Sendable {
    public let windowID: CGWindowID
    public let appName: String
    public let bundleID: String
    public let title: String
    public let frame: CGRect // screen points
    public let isOnScreen: Bool
}

nonisolated public enum MirrorCapture {

    /// All plausible capture targets (normal-layer, non-tiny). Includes windows
    /// on other Spaces / full-screen Spaces — desktop-independent window capture
    /// works across Spaces, so discovery must see them too.
    public static func shareableWindows() async throws -> [(SCWindow, CaptureCandidate)] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true, onScreenWindowsOnly: false
        )
        return content.windows.compactMap { w in
            guard w.windowLayer == 0,
                  w.frame.width >= 200, w.frame.height >= 150 else { return nil }
            let candidate = CaptureCandidate(
                windowID: w.windowID,
                appName: w.owningApplication?.applicationName ?? "?",
                bundleID: w.owningApplication?.bundleIdentifier ?? "?",
                title: w.title ?? "",
                frame: w.frame,
                isOnScreen: w.isOnScreen
            )
            return (w, candidate)
        }
    }

    /// Best guess for the QuickTime mirror window. The LIVE device mirror is
    /// titled "Movie Recording"; after stopping/saving a recording, QuickTime
    /// turns that window into a movie *document* (titled "Untitled"/filename)
    /// whose playback would otherwise be captured as if it were live — prefer
    /// the mirror title, fall back to the largest QuickTime window. Callers
    /// may override by window ID (probe `--window`).
    public static func findQuickTimeMirror(
        in windows: [(SCWindow, CaptureCandidate)]
    ) -> (SCWindow, CaptureCandidate)? {
        let quicktime = windows.filter { $0.1.bundleID.contains("com.apple.QuickTimePlayer") }
        let byArea: ((SCWindow, CaptureCandidate), (SCWindow, CaptureCandidate)) -> Bool = {
            $0.1.frame.width * $0.1.frame.height < $1.1.frame.width * $1.1.frame.height
        }
        return quicktime.filter { $0.1.title == "Movie Recording" }.max(by: byArea)
            ?? quicktime.max(by: byArea)
    }

    /// One-shot window capture at native (Retina) pixel resolution.
    public static func captureOnce(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let cfg = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale > 0 ? filter.pointPixelScale : 2)
        cfg.width = Int(filter.contentRect.width * scale)
        cfg.height = Int(filter.contentRect.height * scale)
        cfg.showsCursor = false
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: cfg
        )
    }
}

// MARK: - Viewport detection

/// Finds the game viewport inside a captured mirror window: trims window
/// chrome and letterbox bars, then snaps to the game's aspect ratio.
/// Calibrate once per source on a stable frame; re-run on window resize.
nonisolated public struct ViewportDetector {

    /// Champions on iPhone 17 Pro Max: 2868×1320.
    public static let gameAspect: CGFloat = 2868.0 / 1320.0

    /// Pixel rect of the game content inside `image`, or nil if none found.
    ///
    /// Strategy: the mirror content is aspect-fit against near-black bars and
    /// window chrome. Scan from each edge for rows/columns that are almost
    /// entirely near-black or chrome-uniform; the surviving interior is the
    /// content box, which is then snapped to `gameAspect` (centered) to shed
    /// any residual chrome the scan missed.
    public static func detect(in image: CGImage) -> CGRect? {
        guard let luma = Luma(image: image) else { return nil }
        let w = luma.width, h = luma.height

        // A row/column is "bar" if ≥97% of its sampled pixels are dark, or it
        // is extremely uniform (title bars / chrome are flat gray).
        func isBarRow(_ y: Int) -> Bool { luma.rowStats(y: y).isBarLike }
        func isBarCol(_ x: Int) -> Bool { luma.colStats(x: x).isBarLike }

        var top = 0, bottom = h - 1, left = 0, right = w - 1
        while top < h / 3, isBarRow(top) { top += 1 }
        while bottom > h * 2 / 3, isBarRow(bottom) { bottom -= 1 }
        while left < w / 3, isBarCol(left) { left += 1 }
        while right > w * 2 / 3, isBarCol(right) { right -= 1 }

        var content = CGRect(
            x: left, y: top, width: right - left + 1, height: bottom - top + 1
        )
        guard content.width > 100, content.height > 60 else { return nil }

        // Snap to the game aspect, centered in the surviving box.
        let boxAspect = content.width / content.height
        if abs(boxAspect - gameAspect) / gameAspect > 0.01 {
            if boxAspect > gameAspect {
                // too wide → trim sides
                let targetW = content.height * gameAspect
                content.origin.x += (content.width - targetW) / 2
                content.size.width = targetW
            } else {
                // too tall → trim top/bottom
                let targetH = content.width / gameAspect
                content.origin.y += (content.height - targetH) / 2
                content.size.height = targetH
            }
        }
        return content.integral
    }

    /// Crop helper for feeding the classifier.
    public static func cropToViewport(_ image: CGImage) -> CGImage? {
        guard let rect = detect(in: image) else { return nil }
        return image.cropping(to: rect)
    }
}

// MARK: - Scaling

nonisolated extension CGImage {
    /// Downscaled copy (e.g. 0.5 for the harness-validated OCR input size).
    func scopeScaled(by scale: CGFloat) -> CGImage? {
        guard scale < 1.0 else { return self }
        let w = max(1, Int(CGFloat(width) * scale))
        let h = max(1, Int(CGFloat(height) * scale))
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(self, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}

/// Downsampled grayscale plane for cheap bar/uniformity scans.
nonisolated private struct Luma {
    let width: Int
    let height: Int
    private let pixels: [UInt8]
    private let stride: Int

    init?(image: CGImage) {
        // Downsample long edge to ~600 px — bar detection needs no detail.
        let scale = min(1.0, 600.0 / CGFloat(max(image.width, image.height)))
        let w = max(1, Int(CGFloat(image.width) * scale))
        let h = max(1, Int(CGFloat(image.height) * scale))
        var buf = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Store at capture resolution semantics: remember the scale factor so
        // detected coordinates map back to source pixels.
        self.pixels = buf
        self.stride = w
        self.width = image.width
        self.height = image.height
        self.sampleW = w
        self.sampleH = h
    }

    private let sampleW: Int
    private let sampleH: Int

    struct LineStats {
        let darkFraction: Double
        let range: Int // max-min luma
        var isBarLike: Bool { darkFraction >= 0.97 || range <= 12 }
    }

    /// Stats for the sampled row nearest to source row `y`.
    func rowStats(y: Int) -> LineStats {
        let sy = min(sampleH - 1, y * sampleH / height)
        var dark = 0, lo = 255, hi = 0
        for sx in 0..<sampleW {
            let v = Int(pixels[sy * stride + sx])
            if v <= 24 { dark += 1 }
            lo = min(lo, v); hi = max(hi, v)
        }
        return LineStats(darkFraction: Double(dark) / Double(sampleW), range: hi - lo)
    }

    /// Stats for the sampled column nearest to source column `x`.
    func colStats(x: Int) -> LineStats {
        let sx = min(sampleW - 1, x * sampleW / width)
        var dark = 0, lo = 255, hi = 0
        for sy in 0..<sampleH {
            let v = Int(pixels[sy * stride + sx])
            if v <= 24 { dark += 1 }
            lo = min(lo, v); hi = max(hi, v)
        }
        return LineStats(darkFraction: Double(dark) / Double(sampleH), range: hi - lo)
    }
}
