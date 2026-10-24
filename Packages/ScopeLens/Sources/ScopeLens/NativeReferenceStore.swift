//
//  NativeReferenceStore.swift
//  Scope Lens
//
//  Phase 3, m7a: confirm-taps permanently teach the species matcher. When the
//  user pins a row to a species, the row's current sprite crop is banked into
//  Application Support (the app is sandboxed) as a native reference: the PNG
//  for the offline harvest to import later, and its precomputed feature in an
//  overlay JSON that PreviewPipeline merges on load — so the very next battle
//  already benefits.
//
//  Offline twin: Tools/ScopeLensDiagnostics/NativeReferenceHarvest.swift (repo-side banking
//  from truth tables + battle corroboration). Schema matches
//  native-features.json: {Species: [{source, fg[576], color[1728]}]}.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

nonisolated public enum NativeReferenceStore {

    static var baseDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScopeLens", isDirectory: true)
    }
    /// The bank's layout under a base directory — shared with the offline
    /// import (Diagnostics `import-live`) so the schema is defined once.
    public static func cropsDir(in base: URL) -> URL {
        base.appendingPathComponent("native-crops", isDirectory: true)
    }
    public static func overlayURL(in base: URL) -> URL {
        base.appendingPathComponent("native-features-live.json")
    }
    static var cropsDir: URL { cropsDir(in: baseDir) }
    static var overlayURL: URL { overlayURL(in: baseDir) }

    /// Bank one confirmed (species ↔ crop) pair. Returns false when the crop
    /// yields no feature (occluded/empty) — nothing is written.
    @discardableResult
    public static func bank(species: String, crop: CGImage) -> Bool {
        bank(species: species, crop: crop, into: baseDir)
    }

    /// baseDir-injectable twin (the import-live simulation banks through the
    /// app's REAL code path so schema/filename fidelity is by construction).
    @discardableResult
    public static func bank(species: String, crop: CGImage, into base: URL) -> Bool {
        guard let buf = RGBABuffer(crop),
              let feature = SpeciesCore.feature(buf: buf, useAlpha: false) else { return false }

        let cropsDir = cropsDir(in: base)
        let overlayURL = overlayURL(in: base)
        let fm = FileManager.default
        let speciesDir = cropsDir.appendingPathComponent(species, isDirectory: true)
        try? fm.createDirectory(at: speciesDir, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let pngURL = speciesDir.appendingPathComponent("live-tap_\(stamp).png")
        if let dest = CGImageDestinationCreateWithURL(
            pngURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, crop, nil)
            CGImageDestinationFinalize(dest)
        }

        // Append the feature to the overlay (same schema the bundle uses).
        var overlay: [String: [[String: Any]]] = [:]
        if let data = try? Data(contentsOf: overlayURL),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]] {
            overlay = parsed
        }
        var colors: [Int] = []
        colors.reserveCapacity(feature.color.count * 3)
        for c in feature.color {
            colors.append(Int(c.0.rounded()))
            colors.append(Int(c.1.rounded()))
            colors.append(Int(c.2.rounded()))
        }
        overlay[species, default: []].append([
            "source": "live-tap",
            "fg": feature.fg.map { $0 ? 1 : 0 },
            "color": colors,
        ])
        guard let out = try? JSONSerialization.data(withJSONObject: overlay, options: [.sortedKeys]) else {
            return false
        }
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        do {
            try out.write(to: overlayURL)
            return true
        } catch {
            return false
        }
    }

    /// The live overlay for pipeline loading (nil until the first tap banks).
    public static func overlayData() -> Data? {
        try? Data(contentsOf: overlayURL)
    }
}
