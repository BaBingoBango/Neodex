//
//  NativeReferenceHarvest.swift
//  ScopeLens Diagnostics — Phase 2 m5: the Champions-native sprite reference
//  set (the m4 brief's stretch D, the "structural fix" for species ID).
//
//  Both existing references are approximations (menu-icon poses / HOME
//  palettes); the crops the preview pipeline sees ARE the native art. This
//  tool banks confirmed (species ↔ sprite crop) pairs and precomputes their
//  features for a third, decisive ensemble tier.
//
//  Confirmation sources (strict provenance — no guessed labels):
//    • still fixtures with committed truth rows (user-verified tables in
//      PreviewPipelineHarness.swift)
//    • recorded battles whose rows the m4 replay corroborated from narration
//      (identityResolved events) or user confirm-taps
//
//  Build & run (from repo root):
//    swiftc -O Tools/ScopeLensDiagnostics/NativeReferenceHarvest.swift "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
//      -o /tmp/nativeharvest
//    /tmp/nativeharvest still "Team Preview Initial" 0=Whimsicott 1=Farigiraf …
//    /tmp/nativeharvest video --video "…/Example Battle 3.mov" --start 106 --duration 100 \
//      --labels 0=Staraptor 3=Garchomp 4=Whimsicott
//    /tmp/nativeharvest features      # → Packages/ScopeLens/Sources/ScopeLens/Resources/PreviewPipeline/native-features.json
//    /tmp/nativeharvest calibrate     # same-species vs cross-species distance stats
//    /tmp/nativeharvest import-live [--from PATH] [--dry-run] [--skip-rebuild]
//                                     # pull the app's confirm-tap bank (m9)
//
//  Crops land in Fixtures/reference/native/<Species>/<source>_row<r>[_tNNN].png
//  (gitignored, like dex-sprites); only the precomputed features JSON is
//  committed/bundled.
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
struct NativeReferenceHarvest {

    static let repoRoot = FileManager.default.currentDirectoryPath
    static var nativeDir: String { "\(scopeLensFixturesRoot)/reference/native" }
    static var featuresPath: String { "\(repoRoot)/Packages/ScopeLens/Sources/ScopeLens/Resources/PreviewPipeline/native-features.json" }
    static var fixturesDir: String { "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max" }

    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        guard !args.isEmpty else {
            fputs("usage: nativeharvest still|video|features|calibrate …\n", stderr)
            exit(2)
        }
        let mode = args.removeFirst()
        do {
            switch mode {
            case "still": try still(args: args)
            case "video": try await video(args: args)
            case "features": try features()
            case "calibrate": try calibrate()
            case "import-live": try importLive(args: args)
            default:
                fputs("unknown mode \(mode)\n", stderr)
                exit(2)
            }
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    // MARK: import-live — pull the app's confirm-tap bank into the repo (m9)

    /// The app banks confirm-tap crops into its sandbox container
    /// (NativeReferenceStore). This mode copies them into the repo bank and
    /// rebuilds the committed features JSON, closing the flywheel: a tap made
    /// during a live battle permanently teaches the committed matcher.
    ///
    /// Each tap becomes its own source (`live-tap-<stamp>`), which keeps the
    /// LOFO measurement honest by construction: live sessions are never eval
    /// fixtures, so an imported tap can only ever help OTHER sources' reads.
    ///
    /// If enumerating the container hangs, macOS is waiting on an "access
    /// data from other apps" consent — approve it (or give the terminal Full
    /// Disk Access), or pass --from with a copy of the ScopeLens folder.
    static func importLive(args argsIn: [String]) throws {
        var from: String?
        var dryRun = false
        var skipRebuild = false
        var args = argsIn
        while !args.isEmpty {
            let flag = args.removeFirst()
            func value() -> String? { args.isEmpty ? nil : args.removeFirst() }
            switch flag {
            case "--from": from = value()
            case "--dry-run": dryRun = true
            case "--skip-rebuild": skipRebuild = true
            default: fputs("unknown flag \(flag)\n", stderr); exit(2)
            }
        }

        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidates = [
            from,
            "\(home)/Library/Containers/com.ethan-marshall.Scope-Lens/Data/Library/Application Support/ScopeLens",
            "\(home)/Library/Application Support/ScopeLens",
        ].compactMap { $0 }
        guard let bankBase = candidates.first(where: {
            fm.fileExists(atPath: "\($0)/native-crops")
        }) else {
            fputs("""
            no live-tap bank found. Looked in:
            \(candidates.map { "  - \($0)/native-crops" }.joined(separator: "\n"))
            (Taps bank when you pin a species row in the app. If the container
            path exists but reads hang, approve the macOS consent dialog or
            pass --from a copied folder.)\n
            """, stderr)
            exit(1)
        }
        print("importing from \(bankBase)")

        var imported = 0, skipped = 0, failed = 0
        let cropsRoot = "\(bankBase)/native-crops"
        for species in (try fm.contentsOfDirectory(atPath: cropsRoot)).sorted()
        where !species.hasPrefix(".") {
            let srcDir = "\(cropsRoot)/\(species)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: srcDir, isDirectory: &isDir), isDir.boolValue else { continue }
            for file in (try fm.contentsOfDirectory(atPath: srcDir)).sorted()
            where file.hasSuffix(".png") {
                // "live-tap_2026-07-03T12-01-05Z.png" → source slug per tap,
                // "_row0" suffix so the features builder's source derivation
                // (filename up to "_row") applies unchanged.
                let stamp = sourceSlug((file as NSString).deletingPathExtension
                    .replacingOccurrences(of: "_", with: "-"))
                let destDir = "\(nativeDir)/\(species)"
                let destPath = "\(destDir)/\(stamp)_row0.png"
                if fm.fileExists(atPath: destPath) {
                    skipped += 1
                    continue
                }
                if dryRun {
                    print("  would import \(species)/\(file)")
                    imported += 1
                    continue
                }
                // Feature-decode gate: never bank a crop the pipeline can't
                // featurize (same rule the app applies at tap time).
                guard let img = loadImage("\(srcDir)/\(file)"),
                      let buf = RGBABuffer(img),
                      SpeciesCore.feature(buf: buf, useAlpha: false) != nil else {
                    print("  ⚠️ no feature from \(species)/\(file) — not imported")
                    failed += 1
                    continue
                }
                try fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
                try fm.copyItem(atPath: "\(srcDir)/\(file)", toPath: destPath)
                print("  imported \(species)/\(file) → \(species)/\(stamp)_row0.png")
                imported += 1
            }
        }
        print("import-live: \(imported) imported, \(skipped) already present, \(failed) unfeaturizable")
        if dryRun || skipRebuild || imported == 0 {
            if !dryRun, imported > 0 { print("(--skip-rebuild: run `features` + `calibrate` before committing)") }
            return
        }
        print("\nrebuilding features…")
        try features()
        print("\ncalibrating (eyeball the extremes — cross-label collisions are label bugs):")
        try calibrate()
    }

    static func parseLabels(_ args: [String]) -> [Int: String] {
        var labels: [Int: String] = [:]
        for a in args where a.contains("=") {
            let parts = a.split(separator: "=", maxSplits: 1)
            if parts.count == 2, let row = Int(parts[0]) { labels[row] = String(parts[1]) }
        }
        return labels
    }

    static func sourceSlug(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    static func saveCrop(_ crop: CGImage, species: String, source: String, row: Int, t: Double? = nil) throws {
        let dir = "\(nativeDir)/\(species)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let stamp = t.map { String(format: "_t%04.0f", $0 * 10) } ?? ""
        let url = URL(fileURLWithPath: "\(dir)/\(source)_row\(row)\(stamp).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "harvest", code: 3)
        }
        CGImageDestinationAddImage(dest, crop, nil)
        CGImageDestinationFinalize(dest)
        print("  saved \(species)/\(url.lastPathComponent)")
    }

    // MARK: still — harvest labeled rows from a fixture PNG

    static func still(args argsIn: [String]) throws {
        guard let stem = argsIn.first(where: { !$0.contains("=") }) else {
            fputs("usage: nativeharvest still <fixtureStem> row=Species …\n", stderr)
            exit(2)
        }
        let labels = parseLabels(argsIn)
        guard !labels.isEmpty else { fputs("no row=Species labels given\n", stderr); exit(2) }

        // Fixture folders are Mode-named; search for the stem (HEIC or PNG).
        let fm = FileManager.default
        var path: String?
        let exts = ["HEIC", "heic", "png", "PNG"]
        if let subdirs = try? fm.contentsOfDirectory(atPath: fixturesDir) {
            for location in subdirs.map({ "\(fixturesDir)/\($0)" }) + [fixturesDir] {
                for ext in exts {
                    let candidate = "\(location)/\(stem).\(ext)"
                    if fm.fileExists(atPath: candidate) { path = candidate; break }
                }
                if path != nil { break }
            }
        }
        guard let path, let image = loadImage(path), let buf = RGBABuffer(image) else {
            fputs("fixture '\(stem)' not found or unreadable under \(fixturesDir)\n", stderr)
            exit(2)
        }
        guard let (layout, geos) = TeamPreviewRowDetector.detectRows(in: buf) else {
            fputs("no opponent column detected in \(stem)\n", stderr)
            exit(1)
        }
        print("\(stem): layout \(layout ? "submitted" : "pre-submit"), \(geos.count) rows")
        let source = sourceSlug(stem)
        for g in geos {
            guard let species = labels[g.row], let crop = image.cropping(to: g.sprite) else { continue }
            try saveCrop(crop, species: species, source: source, row: g.row)
        }
    }

    // MARK: video — harvest labeled rows across a preview segment

    static func video(args argsIn: [String]) async throws {
        var videoPath = ""
        var start = 0.0, duration = Double.infinity, everySeconds = 2.0
        var labelArgs: [String] = []
        var args = argsIn
        while !args.isEmpty {
            let flag = args.removeFirst()
            func value() -> String? { args.isEmpty ? nil : args.removeFirst() }
            switch flag {
            case "--video": videoPath = value() ?? ""
            case "--start": start = value().flatMap(Double.init) ?? start
            case "--duration": duration = value().flatMap(Double.init) ?? duration
            case "--every": everySeconds = value().flatMap(Double.init) ?? everySeconds
            case "--labels": break // labels follow as row=Species tokens
            default: if flag.contains("=") { labelArgs.append(flag) }
            }
        }
        let labels = parseLabels(labelArgs)
        guard !videoPath.isEmpty, !labels.isEmpty else {
            fputs("usage: nativeharvest video --video PATH [--start S --duration S --every S] --labels r=Species …\n", stderr)
            exit(2)
        }

        let url = URL(fileURLWithPath: videoPath)
        let source = sourceSlug(url.deletingPathExtension().lastPathComponent)
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "harvest", code: 4, userInfo: [NSLocalizedDescriptionKey: "no video track"])
        }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: duration.isFinite ? CMTime(seconds: duration, preferredTimescale: 600) : .positiveInfinity)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()

        let ciContext = CIContext(options: [.cacheIntermediates: false])
        var nextSample = start
        var saved = 0
        while reader.status == .reading {
            guard let sb = output.copyNextSampleBuffer() else { break }
            try autoreleasepool {
                defer { CMSampleBufferInvalidate(sb) }
                let pts = CMSampleBufferGetPresentationTimeStamp(sb).seconds
                guard pts >= nextSample, let pb = CMSampleBufferGetImageBuffer(sb) else { return }
                nextSample = pts + everySeconds
                let ci = CIImage(cvPixelBuffer: pb)
                guard let frame = ciContext.createCGImage(ci, from: ci.extent),
                      let buf = RGBABuffer(frame),
                      let (_, geos) = TeamPreviewRowDetector.detectRows(in: buf) else { return }
                for g in geos {
                    guard let species = labels[g.row], let crop = frame.cropping(to: g.sprite) else { continue }
                    try saveCrop(crop, species: species, source: source, row: g.row, t: pts)
                    saved += 1
                }
            }
        }
        print("done: \(saved) crops from \(source)")
    }

    // MARK: features — precompute the bundled JSON from all banked crops

    static func features() throws {
        let fm = FileManager.default
        guard let speciesDirs = try? fm.contentsOfDirectory(atPath: nativeDir).sorted() else {
            fputs("nothing harvested yet under \(nativeDir)\n", stderr)
            exit(1)
        }
        var out: [String: [[String: Any]]] = [:]
        var count = 0
        for species in speciesDirs where !species.hasPrefix(".") {
            let dir = "\(nativeDir)/\(species)"
            for file in (try fm.contentsOfDirectory(atPath: dir)).sorted() where file.hasSuffix(".png") {
                guard let img = loadImage("\(dir)/\(file)"), let buf = RGBABuffer(img),
                      let f = SpeciesCore.feature(buf: buf, useAlpha: false) else {
                    print("  skip (no feature): \(species)/\(file)")
                    continue
                }
                // source = filename up to "_row"
                let source = file.components(separatedBy: "_row").first ?? "unknown"
                var colors: [Int] = []
                colors.reserveCapacity(f.color.count * 3)
                for c in f.color {
                    colors.append(Int(c.0.rounded())); colors.append(Int(c.1.rounded())); colors.append(Int(c.2.rounded()))
                }
                out[species, default: []].append([
                    "source": source,
                    "fg": f.fg.map { $0 ? 1 : 0 },
                    "color": colors,
                ])
                count += 1
            }
        }
        let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: featuresPath))
        let kb = data.count / 1024
        print("wrote \(featuresPath) — \(out.count) species, \(count) features, \(kb)KB")
    }

    // MARK: calibrate — distance separation between same/cross species

    static func calibrate() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: featuresPath))
        let core = try NativeFeatureSet(json: data)
        var same: [Double] = []      // same species, DIFFERENT source
        var cross: [Double] = []     // different species
        let entries = core.all
        for i in 0..<entries.count {
            for j in (i + 1)..<entries.count {
                let a = entries[i], b = entries[j]
                let d = SpeciesCore.matchScore(a.feature, b.feature)
                if a.species == b.species {
                    if a.source != b.source { same.append(d) }
                } else {
                    cross.append(d)
                }
            }
        }
        func stats(_ v: [Double], _ label: String) {
            guard !v.isEmpty else { print("\(label): none"); return }
            let s = v.sorted()
            func pct(_ p: Double) -> Double { s[min(s.count - 1, Int(Double(s.count) * p))] }
            print(String(format: "%@: n=%d  min %.3f  p10 %.3f  median %.3f  p90 %.3f  max %.3f",
                         label, s.count, s[0], pct(0.10), pct(0.50), pct(0.90), s.last!))
        }
        stats(same, "same-species cross-source")
        stats(cross, "cross-species          ")

        // Extremes — mislabeled or junk-component crops show up here.
        var samePairs: [(Double, String)] = [], crossPairs: [(Double, String)] = []
        for i in 0..<entries.count {
            for j in (i + 1)..<entries.count {
                let a = entries[i], b = entries[j]
                let d = SpeciesCore.matchScore(a.feature, b.feature)
                let tag = "\(a.species)(\(a.source)) ↔ \(b.species)(\(b.source))"
                if a.species == b.species, a.source != b.source { samePairs.append((d, tag)) }
                if a.species != b.species { crossPairs.append((d, tag)) }
            }
        }
        print("\nworst same-species pairs:")
        for (d, tag) in samePairs.sorted(by: { $0.0 > $1.0 }).prefix(5) {
            print(String(format: "  %.3f  %@", d, tag))
        }
        print("closest cross-species pairs:")
        for (d, tag) in crossPairs.sorted(by: { $0.0 < $1.0 }).prefix(8) {
            print(String(format: "  %.3f  %@", d, tag))
        }
        if let sMax = same.max(), let cMin = cross.min() {
            print(String(format: "separation: same p90 vs cross min → gap %+.3f%@",
                         cMin - same.sorted()[min(same.count - 1, Int(Double(same.count) * 0.9))],
                         sMax < cMin ? "  (CLEAN SPLIT)" : ""))
        }
    }
}

/// Parsed native features with source tags (mirrors what SpeciesCore loads).
nonisolated struct NativeFeatureSet {
    struct Entry {
        let species: String
        let source: String
        let feature: SpriteFeature
    }
    let all: [Entry]

    init(json: Data) throws {
        guard let obj = try JSONSerialization.jsonObject(with: json) as? [String: [[String: Any]]] else {
            throw NSError(domain: "harvest", code: 5, userInfo: [NSLocalizedDescriptionKey: "bad native-features.json"])
        }
        var entries: [Entry] = []
        for (species, list) in obj {
            for e in list {
                guard let fgArr = e["fg"] as? [Int], let colArr = e["color"] as? [Int],
                      fgArr.count == SpeciesCore.grid * SpeciesCore.grid,
                      colArr.count == fgArr.count * 3 else { continue }
                var f = SpriteFeature(fg: fgArr.map { $0 > 0 },
                                      color: .init(repeating: (0, 0, 0), count: fgArr.count))
                for i in 0..<fgArr.count {
                    f.color[i] = (Double(colArr[i * 3]), Double(colArr[i * 3 + 1]), Double(colArr[i * 3 + 2]))
                }
                entries.append(Entry(species: species, source: e["source"] as? String ?? "unknown", feature: f))
            }
        }
        all = entries
    }
}

/// Orientation-aware load: iPhone HEIC screenshots carry EXIF orientation
/// that must be baked in before pixel geometry (same as the pipeline harness).
func loadImage(_ path: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
    let raw = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
    if let o = CGImagePropertyOrientation(rawValue: raw), o != .up {
        let ci = CIImage(cgImage: img).oriented(o)
        return CIContext().createCGImage(ci, from: ci.extent)
    }
    return img
}
