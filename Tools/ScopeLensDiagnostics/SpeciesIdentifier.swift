import Foundation
import AppKit
import CoreImage
import ImageIO

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

// SpeciesIdentifier — matches each opponent preview sprite against reference
// menu icons (Fixtures/reference/), constrained by the classified type pair.

let repoRoot = FileManager.default.currentDirectoryPath
let previewDir = "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max/Team Preview"
let manifestPath = "\(scopeLensFixturesRoot)/preview/manifest.json"
let typesPath = "\(scopeLensFixturesRoot)/preview/types.json"
let refDir = "\(scopeLensFixturesRoot)/reference"
let outDir = "\(scopeLensFixturesRoot)/preview"
let fm = FileManager.default
func err(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

// MARK: plumbing
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
func rgba(_ cg: CGImage) -> ([UInt8], Int, Int)? {
    let w = cg.width, h = cg.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (buf, w, h)
}
func savePNG(_ cg: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: cg)
    if let d = rep.representation(using: .png, properties: [:]) { try? d.write(to: URL(fileURLWithPath: path)) }
}
@inline(__always) func isPlateCrimson(_ r: Int, _ g: Int, _ b: Int) -> Bool {
    r >= 70 && r <= 210 && g <= 70 && b >= 25 && b <= 115 && (r - g) >= 55 && (r - b) >= 30 && (b - g) >= 12
}
@inline(__always) func isDark(_ r: Int, _ g: Int, _ b: Int) -> Bool { r + g + b < 150 }

// MARK: normalized grid feature
let GRID = 24
struct SpriteFeature {
    var fg: [Bool]                 // GRID×GRID foreground mask
    var color: [(Double, Double, Double)]
}
/// Foreground = largest connected component of non-plate, non-dark pixels
/// (screenshot crops), or alpha > 128 (reference icons).
func feature(buf: [UInt8], w: Int, h: Int, useAlpha: Bool) -> SpriteFeature? {
    var mask = [Bool](repeating: false, count: w * h)
    var total = 0
    for p in 0..<(w * h) {
        let i = p * 4
        if useAlpha {
            if buf[i+3] > 128 { mask[p] = true; total += 1 }
        } else {
            let r = Int(buf[i]), g = Int(buf[i+1]), b = Int(buf[i+2])
            if !isPlateCrimson(r, g, b) && !isDark(r, g, b) { mask[p] = true; total += 1 }
        }
    }
    guard total > 60 else { return nil }
    var keep = mask
    if !useAlpha {   // largest connected component
        var labels = [Int](repeating: -1, count: w * h)
        var best: [Int] = []
        for start in 0..<(w * h) where mask[start] && labels[start] < 0 {
            var queue = [start]; labels[start] = 1
            var qi = 0; var pixels: [Int] = []
            while qi < queue.count {
                let p = queue[qi]; qi += 1; pixels.append(p)
                let x = p % w, y = p / w
                for (nx, ny) in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]
                where nx >= 0 && nx < w && ny >= 0 && ny < h {
                    let np = ny * w + nx
                    if mask[np] && labels[np] < 0 { labels[np] = 1; queue.append(np) }
                }
            }
            if pixels.count > best.count { best = pixels }
        }
        guard best.count > 60 else { return nil }
        keep = [Bool](repeating: false, count: w * h)
        for p in best { keep[p] = true }
    }
    var x0 = w, x1 = 0, y0 = h, y1 = 0
    for p in 0..<(w * h) where keep[p] {
        let x = p % w, y = p / w
        x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
    }
    guard x1 - x0 > 6, y1 - y0 > 6 else { return nil }
    // aspect-preserving placement into GRID×GRID
    let bw = Double(x1 - x0 + 1), bh = Double(y1 - y0 + 1)
    let scale = Double(GRID) / max(bw, bh)
    let ox = (Double(GRID) - bw * scale) / 2, oy = (Double(GRID) - bh * scale) / 2
    var fg = [Bool](repeating: false, count: GRID * GRID)
    var sums = [(Double, Double, Double, Double)](repeating: (0, 0, 0, 0), count: GRID * GRID)
    for p in 0..<(w * h) where keep[p] {
        let x = p % w, y = p / w
        let gx = min(GRID - 1, max(0, Int(ox + (Double(x - x0) + 0.5) * scale)))
        let gy = min(GRID - 1, max(0, Int(oy + (Double(y - y0) + 0.5) * scale)))
        let gi = gy * GRID + gx
        let i = p * 4
        sums[gi].0 += Double(buf[i]); sums[gi].1 += Double(buf[i+1]); sums[gi].2 += Double(buf[i+2]); sums[gi].3 += 1
        fg[gi] = true
    }
    var color = [(Double, Double, Double)](repeating: (0, 0, 0), count: GRID * GRID)
    for gi in 0..<(GRID * GRID) where sums[gi].3 > 0 {
        color[gi] = (sums[gi].0 / sums[gi].3, sums[gi].1 / sums[gi].3, sums[gi].2 / sums[gi].3)
    }
    return SpriteFeature(fg: fg, color: color)
}
func matchScore(_ a: SpriteFeature, _ b: SpriteFeature) -> Double {
    var inter = 0, uni = 0
    var dc = 0.0; var nc = 0
    for i in 0..<(GRID * GRID) {
        if a.fg[i] && b.fg[i] {
            inter += 1
            dc += sqrt(pow(a.color[i].0 - b.color[i].0, 2) + pow(a.color[i].1 - b.color[i].1, 2)
                     + pow(a.color[i].2 - b.color[i].2, 2)) / 441.7
            nc += 1
        }
        if a.fg[i] || b.fg[i] { uni += 1 }
    }
    let sil = uni == 0 ? 0 : Double(inter) / Double(uni)
    let colorDist = nc == 0 ? 1 : dc / Double(nc)
    return 1.0 * colorDist + 1.2 * (1 - sil)
}

// MARK: reference data
struct Species { let name: String; let num: Int; let types: Set<String>; let left: Int; let top: Int }
guard let idxData = fm.contents(atPath: "\(refDir)/species-index.json"),
      let idxJSON = try? JSONSerialization.jsonObject(with: idxData) as? [[String: Any]],
      let sheet = loadImage("\(refDir)/pokemonicons-sheet.png") else { err("missing reference data"); exit(1) }
let allSpecies: [Species] = idxJSON.map {
    Species(name: $0["name"] as! String, num: $0["num"] as! Int,
            types: Set(($0["types"] as! [String])), left: $0["left"] as! Int, top: $0["top"] as! Int)
}
// Two reference styles, ensembled by rank fusion:
//  • pixel menu icons (sheet) — share the box-icon POSES Champions uses
//  • Showdown "dex" sprites (120×120 HOME renders) — share the modern PALETTE
func slug(_ name: String) -> String {
    name.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "_" }.joined()
}
var pixelFeatures: [String: SpriteFeature?] = [:]
var dexFeatures: [String: SpriteFeature?] = [:]
func pixelFeature(_ s: Species) -> SpriteFeature? {
    if let f = pixelFeatures[s.name] { return f }
    var f: SpriteFeature? = nil
    if let icon = sheet.cropping(to: CGRect(x: s.left, y: s.top, width: 40, height: 30)),
       let (buf, w, h) = rgba(icon) { f = feature(buf: buf, w: w, h: h, useAlpha: true) }
    pixelFeatures[s.name] = f
    return f
}
func dexFeature(_ s: Species) -> SpriteFeature? {
    if let f = dexFeatures[s.name] { return f }
    var f: SpriteFeature? = nil
    if let img = loadImage("\(refDir)/dex-sprites/\(slug(s.name)).png"),
       let (buf, w, h) = rgba(img) { f = feature(buf: buf, w: w, h: h, useAlpha: true) }
    dexFeatures[s.name] = f
    return f
}
func refIcon(_ s: Species) -> CGImage? {
    if let img = loadImage("\(refDir)/dex-sprites/\(slug(s.name)).png") { return img }
    return sheet.cropping(to: CGRect(x: s.left, y: s.top, width: 40, height: 30))
}

// MARK: inputs
guard let mData = fm.contents(atPath: manifestPath),
      let manifest = try? JSONSerialization.jsonObject(with: mData) as? [String: [String: Any]],
      let tData = fm.contents(atPath: typesPath),
      let typesJSON = try? JSONSerialization.jsonObject(with: tData) as? [String: [[String: Any]]] else {
    err("missing manifest/types"); exit(1)
}
func fixtureImage(_ stem: String) -> CGImage? {
    loadImage("\(previewDir)/\(stem.replacingOccurrences(of: "_", with: " ")).HEIC")
}

// known rows for scoring (nil = to be discovered)
let truth: [String: [String?]] = [
    "Team_Preview_Initial": ["Whimsicott", "Farigiraf", "Charizard", nil, "Archaludon", "Venusaur"],
    "Team_Preview_Selected_with_Summary": ["Whimsicott", "Farigiraf", "Charizard", nil, "Archaludon", "Venusaur"],
    "Team_Preview_Submitted": ["Falinks", "Farigiraf", "Aerodactyl", "Sylveon", "Kingambit", "Garchomp"],
    "Extra_Team_Example_1": ["Charizard", "Garchomp", nil, "Whimsicott", nil, "Kingambit"],
    "Extra_Team_Example_2": ["Scizor", nil, "Swampert", "Incineroar", "Sableye", "Politoed"],
    // Rows confirmed by the user during the 2026-07-02 live m3b test.
    "Team_with_Electric_Type": ["Raichu", "Mawile", nil, "Ceruledge", "Milotic", nil],
]

var okTop1 = 0, okTop3 = 0, nKnown = 0
var speciesOut: [String: [[String: Any]]] = [:]
for (fixture, entry) in manifest.sorted(by: { $0.key < $1.key }) {
    guard let rows = entry["rows"] as? [[String: Any]], let img = fixtureImage(fixture) else { continue }
    let typeReads = typesJSON[fixture] ?? []
    var sheetCells: [[CGImage]] = []
    for r in rows.sorted(by: { ($0["row"] as! Int) < ($1["row"] as! Int) }) {
        let n = r["row"] as! Int
        guard let sr = r["sprite"] as? [String: Double] else { continue }
        let W = Double(img.width), H = Double(img.height)
        guard let crop = img.cropping(to: CGRect(x: sr["x"]! * W, y: sr["y"]! * H,
                                                 width: sr["w"]! * W, height: sr["h"]! * H)),
              let (buf, w, h) = rgba(crop),
              let feat = feature(buf: buf, w: w, h: h, useAlpha: false) else { continue }

        // Type constraint. The predicted pair always seeds the candidate set;
        // a low-margin slot additionally WIDENS it (that slot may be misread)
        // rather than discarding the prediction.
        let reads = typeReads.filter { ($0["row"] as! Int) == n }
        let t1 = reads.first { ($0["slot"] as! Int) == 1 }
        let t2 = reads.first { ($0["slot"] as! Int) == 2 }
        func pred(_ t: [String: Any]?) -> (String, Double)? {
            guard let t = t, let ty = t["type"] as? String else { return nil }
            return (ty, t["margin"] as? Double ?? 0)
        }
        var candidateSet = Set<String>()
        if t1 == nil, let (mono, m2) = pred(t2) {            // mono-type (structural)
            for s in allSpecies where s.types == [mono] { candidateSet.insert(s.name) }
            if m2 < 0.05 { for s in allSpecies where s.types.count == 1 { candidateSet.insert(s.name) } }
        } else if let (a, m1) = pred(t1), let (b, m2) = pred(t2) {
            for s in allSpecies where s.types == Set([a, b]) { candidateSet.insert(s.name) }
            if m1 < 0.05 { for s in allSpecies where s.types.contains(b) && s.types.count == 2 { candidateSet.insert(s.name) } }
            if m2 < 0.05 { for s in allSpecies where s.types.contains(a) && s.types.count == 2 { candidateSet.insert(s.name) } }
        } else if let (a, _) = pred(t1) ?? pred(t2) {
            for s in allSpecies where s.types.contains(a) { candidateSet.insert(s.name) }
        } else {
            candidateSet = Set(allSpecies.map { $0.name })
        }
        let candidates = allSpecies.filter { candidateSet.contains($0.name) }

        // score under both references, fuse by summed rank (Borda)
        var pixelScored: [(String, Double)] = [], dexScored: [(String, Double)] = []
        var byName: [String: Species] = [:]
        for s in candidates {
            byName[s.name] = s
            if let pf = pixelFeature(s) { pixelScored.append((s.name, matchScore(feat, pf))) }
            if let df = dexFeature(s) { dexScored.append((s.name, matchScore(feat, df))) }
        }
        pixelScored.sort { $0.1 < $1.1 }; dexScored.sort { $0.1 < $1.1 }
        var rank: [String: Double] = [:]
        for (i, e) in pixelScored.enumerated() { rank[e.0, default: 0] += Double(i) }
        for (i, e) in dexScored.enumerated() { rank[e.0, default: 0] += Double(i) }
        // a species missing from one list ranks last there
        for s in candidates {
            if !pixelScored.contains(where: { $0.0 == s.name }) { rank[s.name, default: 0] += Double(pixelScored.count) }
            if !dexScored.contains(where: { $0.0 == s.name }) { rank[s.name, default: 0] += Double(dexScored.count) }
        }
        let fused = rank.sorted { ($0.value, $0.key) < ($1.value, $1.key) }
        var top: [(Species, Double)] = []
        for e in fused.prefix(3) { if let s = byName[e.key] { top.append((s, e.value)) } }
        let names = top.map { $0.0.name }
        speciesOut[fixture, default: []].append([
            "row": n, "candidates": candidates.count,
            "top": top.map { ["name": $0.0.name, "num": $0.0.num, "score": $0.1] }
        ])
        // verification sheet row: crop + top3 icons
        var cells: [CGImage] = [crop]
        for (s, _) in top { if let ic = refIcon(s) { cells.append(ic) } }
        sheetCells.append(cells)

        let t = truth[fixture]?[n] ?? nil
        if let t = t {
            nKnown += 1
            if names.first == t { okTop1 += 1 }
            if names.contains(t) { okTop3 += 1 }
            err("\(fixture)/\(n): \(names.joined(separator: " | "))  [truth \(t)] \(names.first == t ? "✓" : "✗")  (\(candidates.count) cands)")
        } else {
            err("\(fixture)/\(n): \(names.joined(separator: " | "))  [NEW]  (\(candidates.count) cands)")
        }
    }
    // save verification sheet
    let cell = 100, pad = 6, cols = 4
    let sw = cols * (cell + pad) + pad, sh = sheetCells.count * (cell + pad) + pad
    if let ctx = CGContext(data: nil, width: sw, height: sh, bitsPerComponent: 8, bytesPerRow: sw * 4,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
        ctx.setFillColor(CGColor(gray: 0.12, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: sw, height: sh))
        for (ri, cells) in sheetCells.enumerated() {
            for (ci, im) in cells.enumerated() {
                let sc = min(Double(cell) / Double(im.width), Double(cell) / Double(im.height))
                let dw = Double(im.width) * sc, dh = Double(im.height) * sc
                let ox = Double(pad + ci * (cell + pad)) + (Double(cell) - dw) / 2
                let oy = Double(sh - (pad + (ri + 1) * (cell + pad))) + (Double(cell) - dh) / 2
                ctx.interpolationQuality = .none
                ctx.draw(im, in: CGRect(x: ox, y: oy, width: dw, height: dh))
            }
        }
        if let s = ctx.makeImage() { savePNG(s, "\(outDir)/\(fixture)_species_sheet.png") }
    }
}
err("top1: \(okTop1)/\(nKnown)   top3: \(okTop3)/\(nKnown)")
let out = try! JSONSerialization.data(withJSONObject: speciesOut, options: [.prettyPrinted, .sortedKeys])
try? out.write(to: URL(fileURLWithPath: "\(outDir)/species.json"))
err("wrote species.json")
