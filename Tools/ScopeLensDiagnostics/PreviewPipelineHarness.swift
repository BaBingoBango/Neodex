//
//  PreviewPipelineHarness.swift
//  ScopeLens Diagnostics — proves the app-target PreviewPipeline port is
//  faithful to the verified Phase-1 CLI chain, and precomputes the dex-render
//  features the app bundles instead of the 96MB sprite folder.
//
//  Build & run (from repo root):
//    swiftc -O Tools/ScopeLensDiagnostics/PreviewPipelineHarness.swift "Packages/ScopeLens/Sources/ScopeLens/PreviewPipeline.swift" \
//      -o /tmp/pipelineharness && /tmp/pipelineharness verify
//
//  Modes:
//    precompute   Fixtures/reference/dex-sprites/*.png → 24×24 features →
//                 "Packages/ScopeLens/Sources/ScopeLens/Resources/PreviewPipeline/dex-features.json"
//    verify       run the port on the 7 preview fixtures; score against the
//                 same truth tables the CLIs used. Acceptance = outcome parity:
//                 type holdout 12/12 (overall within 1 of 40/41 — ±1px crop
//                 rounding can flip one knife-edge slot) and species
//                 top-1 ≥ 14/25, top-3 ≥ 22/25.
//

import Foundation
import AVFoundation
import CoreGraphics
import CoreImage
import ImageIO

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

let repoRoot = FileManager.default.currentDirectoryPath
let previewDir = "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max/Team Preview"
let refDir = "\(scopeLensFixturesRoot)/reference"
let templatesPath = "\(scopeLensFixturesRoot)/type-templates/templates.json"
let outFeaturesPath = "\(repoRoot)/Packages/ScopeLens/Sources/ScopeLens/Resources/PreviewPipeline/dex-features.json"
let nativeFeaturesPath = "\(repoRoot)/Packages/ScopeLens/Sources/ScopeLens/Resources/PreviewPipeline/native-features.json"

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

func slug(_ name: String) -> String {
    name.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "_" }.joined()
}

// Truth tables carried over verbatim from the Phase-1 CLIs.
let typeLabels: [String: String] = [
    // harvest set (train)
    "Team Preview Initial/0/1": "Grass",    "Team Preview Initial/0/2": "Fairy",
    "Team Preview Initial/1/1": "Normal",   "Team Preview Initial/1/2": "Psychic",
    "Team Preview Initial/2/1": "Fire",     "Team Preview Initial/2/2": "Flying",
    "Team Preview Initial/3/1": "Water",    "Team Preview Initial/3/2": "Flying",
    "Team Preview Initial/4/1": "Steel",    "Team Preview Initial/4/2": "Dragon",
    "Team Preview Initial/5/1": "Grass",    "Team Preview Initial/5/2": "Poison",
    "Team Preview Submitted/0/2": "Fighting",
    "Team Preview Submitted/1/1": "Normal", "Team Preview Submitted/1/2": "Psychic",
    "Team Preview Submitted/2/1": "Rock",   "Team Preview Submitted/2/2": "Flying",
    "Team Preview Submitted/3/2": "Fairy",
    "Team Preview Submitted/4/1": "Dark",   "Team Preview Submitted/4/2": "Steel",
    "Team Preview Submitted/5/1": "Dragon", "Team Preview Submitted/5/2": "Ground",
    "Extra Team Example 2/0/1": "Bug",      "Extra Team Example 2/0/2": "Steel",
    "Team with Ice Type/0/1": "Ice",        "Team with Ice Type/0/2": "Ghost",
    "Extra Team Example 2/3/1": "Fire",     "Extra Team Example 2/3/2": "Dark",
    "Extra Team Example 2/4/1": "Dark",     "Extra Team Example 2/4/2": "Ghost",
    "Extra Team Example 2/5/2": "Water",
    // Team with Electric Type (2026-07-02): the 18th template's fixture.
    "Team with Electric Type/0/2": "Electric",
    "Team with Electric Type/1/1": "Steel", "Team with Electric Type/1/2": "Fairy",
    "Team with Electric Type/2/1": "Grass", "Team with Electric Type/2/2": "Ghost",
    "Team with Electric Type/3/1": "Fire",  "Team with Electric Type/3/2": "Ghost",
    "Team with Electric Type/4/2": "Water",
    "Team with Electric Type/5/1": "Fire",  "Team with Electric Type/5/2": "Dark",
]
let typeHoldout: [String: String] = [
    "Team Preview Selected with Summary/0/1": "Grass",  "Team Preview Selected with Summary/0/2": "Fairy",
    "Team Preview Selected with Summary/1/1": "Normal", "Team Preview Selected with Summary/1/2": "Psychic",
    "Team Preview Selected with Summary/2/1": "Fire",   "Team Preview Selected with Summary/2/2": "Flying",
    "Team Preview Selected with Summary/3/1": "Water",  "Team Preview Selected with Summary/3/2": "Flying",
    "Team Preview Selected with Summary/4/1": "Steel",  "Team Preview Selected with Summary/4/2": "Dragon",
    "Team Preview Selected with Summary/5/1": "Grass",  "Team Preview Selected with Summary/5/2": "Poison",
]
let speciesTruth: [String: [String?]] = [
    "Team Preview Initial": ["Whimsicott", "Farigiraf", "Charizard", nil, "Archaludon", "Venusaur"],
    "Team Preview Selected with Summary": ["Whimsicott", "Farigiraf", "Charizard", nil, "Archaludon", "Venusaur"],
    "Team Preview Submitted": ["Falinks", "Farigiraf", "Aerodactyl", "Sylveon", "Kingambit", "Garchomp"],
    "Extra Team Example 1": ["Charizard", "Garchomp", nil, "Whimsicott", nil, "Kingambit"],
    "Extra Team Example 2": ["Scizor", nil, "Swampert", "Incineroar", "Sableye", "Politoed"],
    "Team with Electric Type": ["Raichu", "Mawile", nil, "Ceruledge", "Milotic", nil],
]

@main
struct PreviewPipelineHarness {
    static func main() async throws {
        let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "verify"
        switch mode {
        case "precompute": try precompute()
        case "verify": try verify()
        case "video": try await video()
        default:
            FileHandle.standardError.write("usage: pipelineharness precompute|verify|video\n".data(using: .utf8)!)
            exit(2)
        }
    }

    // MARK: video — frame-voting validation on the recorded battle's preview

    static func video() async throws {
        var path = "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max/Full Battle Video from QuickTime.mov"
        var start = 11.0, duration = 30.0, fps = 2.0
        var args = Array(CommandLine.arguments.dropFirst(2))
        while !args.isEmpty {
            let flag = args.removeFirst()
            func value() -> String? { args.isEmpty ? nil : args.removeFirst() }
            switch flag {
            case "--video": path = value() ?? path
            case "--start": start = value().flatMap(Double.init) ?? start
            case "--duration": duration = value().flatMap(Double.init) ?? duration
            case "--fps": fps = value().flatMap(Double.init) ?? fps
            default: break
            }
        }

        let templates = try Data(contentsOf: URL(fileURLWithPath: templatesPath))
        let index = try Data(contentsOf: URL(fileURLWithPath: "\(refDir)/species-index.json"))
        guard let sheet = loadImage("\(refDir)/pokemonicons-sheet.png") else { fatalError("missing sheet") }
        let dexFeatures = try? Data(contentsOf: URL(fileURLWithPath: outFeaturesPath))
        let nativeFeatures = try? Data(contentsOf: URL(fileURLWithPath: nativeFeaturesPath))
        let pipeline = PreviewPipeline(
            typeCore: try TypeIconCore(templatesJSON: templates),
            speciesCore: try SpeciesCore(indexJSON: index, sheet: sheet,
                                         dexFeaturesJSON: dexFeatures,
                                         nativeFeaturesJSON: nativeFeatures)
        )
        // Honest scoring: crops this very video contributed are held out.
        pipeline.speciesCore.evalExcludeNativeSource = URL(fileURLWithPath: path)
            .deletingPathExtension().lastPathComponent.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { fatalError("no track") }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                       duration: CMTime(seconds: duration, preferredTimescale: 600))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()

        let ciContext = CIContext(options: [.cacheIntermediates: false])
        var aggregate = PreviewAggregate()
        var nextSample = start
        let interval = 1.0 / fps

        while reader.status == .reading {
            guard let sb = output.copyNextSampleBuffer() else { break }
            autoreleasepool {
                defer { CMSampleBufferInvalidate(sb) }
                let pts = CMSampleBufferGetPresentationTimeStamp(sb).seconds
                guard pts >= nextSample, let pb = CMSampleBufferGetImageBuffer(sb) else { return }
                nextSample += interval
                if nextSample < pts { nextSample = pts + interval }
                let ci = CIImage(cvPixelBuffer: pb)
                guard let frame = ciContext.createCGImage(ci, from: ci.extent),
                      let read = pipeline.read(frame: frame) else {
                    print(String(format: "  t=%5.1f  (no read)", pts))
                    return
                }
                aggregate.add(read)
                let brief = read.rows.map { r in
                    let t = [r.type1?.type, r.type2?.type].compactMap { $0 }.joined(separator: "/")
                    return "\(r.row):\(t.isEmpty ? "?" : t):\(r.speciesTop.first?.name ?? "?")"
                }.joined(separator: " ")
                print(String(format: "  t=%5.1f  %@ %@", pts, read.layoutSubmitted ? "SUB" : "PRE", brief))
            }
        }

        print("\nconsensus after \(aggregate.frameCount) frames:")
        for c in aggregate.consensus {
            let types = c.typePair.joined(separator: "/")
            let sp = c.speciesTop.map { String(format: "%@ (%.0f)", $0.name, $0.votes) }.joined(separator: " | ")
            print(String(format: "  row %d [%@ %.0f%%, %d frames] %@  %@",
                         c.row, types, c.typeStability * 100, c.framesSeen, c.gender, sp))
        }
    }

    // MARK: precompute

    static func precompute() throws {
        let idxData = try Data(contentsOf: URL(fileURLWithPath: "\(refDir)/species-index.json"))
        let idx = try JSONSerialization.jsonObject(with: idxData) as! [[String: Any]]
        var out: [String: [String: [Double]]] = [:]
        var missing: [String] = []
        for entry in idx {
            let name = entry["name"] as! String
            guard let img = loadImage("\(refDir)/dex-sprites/\(slug(name)).png"),
                  let buf = RGBABuffer(img),
                  let f = SpeciesCore.feature(buf: buf, useAlpha: true) else {
                missing.append(name)
                continue
            }
            var colors: [Double] = []
            colors.reserveCapacity(24 * 24 * 3)
            for c in f.color {
                colors.append((c.0 * 10).rounded() / 10)
                colors.append((c.1 * 10).rounded() / 10)
                colors.append((c.2 * 10).rounded() / 10)
            }
            out[name] = ["fg": f.fg.map { $0 ? 1.0 : 0.0 }, "color": colors]
        }
        try FileManager.default.createDirectory(
            atPath: (outFeaturesPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: outFeaturesPath))
        print("precomputed \(out.count) dex features (\(missing.count) missing — expected per dex-missing.json)")
        print("→ \(outFeaturesPath) (\(data.count / 1024) KB)")
    }

    // MARK: verify

    static func verify() throws {
        let templates = try Data(contentsOf: URL(fileURLWithPath: templatesPath))
        let index = try Data(contentsOf: URL(fileURLWithPath: "\(refDir)/species-index.json"))
        guard let sheet = loadImage("\(refDir)/pokemonicons-sheet.png") else {
            fatalError("missing icon sheet")
        }
        let dexFeatures = try? Data(contentsOf: URL(fileURLWithPath: outFeaturesPath))
        if dexFeatures == nil {
            print("⚠️ no dex-features.json — run precompute first (verifying pixel-only)")
        }
        // Native features (m5): scored leave-one-source-out — when a fixture
        // is being evaluated, crops harvested FROM that fixture are held out,
        // so every native hit is a genuine "seen this species elsewhere".
        let nativeFeatures = try? Data(contentsOf: URL(fileURLWithPath: nativeFeaturesPath))
        let pipeline = PreviewPipeline(
            typeCore: try TypeIconCore(templatesJSON: templates),
            speciesCore: try SpeciesCore(indexJSON: index, sheet: sheet,
                                         dexFeaturesJSON: dexFeatures,
                                         nativeFeaturesJSON: nativeFeatures)
        )

        var typeOKHoldout = 0, typeNHoldout = 0
        var typeOKTrain = 0, typeNTrain = 0
        var missedSlots: [String] = []
        var spTop1 = 0, spTop3 = 0, spN = 0
        var nativeDecisive = 0
        var rowCountsOK = true

        let fixtures = try FileManager.default.contentsOfDirectory(atPath: previewDir)
            .filter { $0.lowercased().hasSuffix(".heic") }.sorted()
        for file in fixtures {
            let stem = (file as NSString).deletingPathExtension
            pipeline.speciesCore.evalExcludeNativeSource = stem.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            guard let img = loadImage("\(previewDir)/\(file)"),
                  let read = pipeline.read(frame: img) else {
                print("❌ \(stem): pipeline returned nil")
                rowCountsOK = false
                continue
            }
            if read.rows.count != 6 {
                print("❌ \(stem): \(read.rows.count) rows (expected 6)")
                rowCountsOK = false
            }
            for r in read.rows {
                for (slot, tr) in [(1, r.type1), (2, r.type2)] {
                    let key = "\(stem)/\(r.row)/\(slot)"
                    let truth = typeHoldout[key] ?? typeLabels[key]
                    if let truth {
                        let isHoldout = typeHoldout[key] != nil
                        if isHoldout { typeNHoldout += 1 } else { typeNTrain += 1 }
                        if tr?.type == truth {
                            if isHoldout { typeOKHoldout += 1 } else { typeOKTrain += 1 }
                        } else {
                            missedSlots.append("\(key): \(tr?.type ?? "EMPTY") ≠ \(truth)")
                        }
                    }
                }
                if let truth = speciesTruth[stem]?[r.row] ?? nil {
                    spN += 1
                    let names = r.speciesTop.map(\.name)
                    if r.speciesTop.first?.fusedRank == -1 { nativeDecisive += 1 }
                    if names.first == truth { spTop1 += 1 }
                    if names.contains(truth) { spTop3 += 1 }
                    else { print("  species miss \(stem)/\(r.row): \(names.joined(separator: " | ")) [truth \(truth)]") }
                }
            }
        }

        for m in missedSlots { print("  type miss \(m)") }
        let typeOK = typeOKHoldout + typeOKTrain, typeN = typeNHoldout + typeNTrain
        print("""

        port outcomes vs Phase-1 verified:
          type holdout:  \(typeOKHoldout)/\(typeNHoldout)   (CLI: 12/12)
          type overall:  \(typeOK)/\(typeN)   (CLI: 52/53)
          species top-1: \(spTop1)/\(spN)  (pre-native baseline: 16/29)
          species top-3: \(spTop3)/\(spN)  (pre-native baseline: 24/29)
          dex reference: \(pipeline.speciesCore.hasDexReference ? "loaded" : "MISSING (pixel-only)")
          native tier:   \(pipeline.speciesCore.hasNativeReference ? "loaded, LOFO, \(nativeDecisive) decisive rows" : "not banked yet")
        """)

        // Baselines re-pinned 2026-07-03 with the m5 native tier (scored
        // leave-one-source-out): 23/29 top-1, 25/29 top-3. The four remaining
        // misses (Scizor, Sylveon, Raichu, Milotic) are species with no
        // cross-source native crops yet — live confirm-taps will bank them.
        // Floors keep 1 slack on top-1 for ±1px crop-rounding flips.
        let pass = rowCountsOK && typeOKHoldout == typeNHoldout && typeOK >= typeN - 2
            && spTop1 >= 22 && spTop3 >= 24
        print(pass ? "\n✅ PORT FAITHFUL" : "\n❌ PORT DIVERGES")
        exit(pass ? 0 : 1)
    }
}
