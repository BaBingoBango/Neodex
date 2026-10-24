import Foundation
import AppKit
import CoreImage
import ImageIO

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

// TypeIconClassifier — classifies the 1–2 type icons on each opponent
// team-preview row using templates harvested from verified fixture crops.
//
//   harvest   build Fixtures/type-templates/ from labeled slots
//   classify  classify every row in Fixtures/preview/manifest.json,
//             score against known labels, write Fixtures/preview/types.json
//
// Icon features: median RGB of the icon's colored background (robust to laser
// streaks) + a 24×24 white-glyph mask. Distance = color + λ·(1 − mask IoU).

let repoRoot = FileManager.default.currentDirectoryPath
let previewDir = "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max/Team Preview"
let manifestPath = "\(scopeLensFixturesRoot)/preview/manifest.json"
let templatesDir = "\(scopeLensFixturesRoot)/type-templates"
let fm = FileManager.default
func err(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

// MARK: image plumbing
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

// MARK: icon feature
struct IconFeature {
    var color: (Double, Double, Double)   // median RGB of colored (non-white) icon pixels
    var mask: [Bool]                       // 24×24 white-glyph mask
    var area: Double                       // icon pixels / slot pixels
}

/// Extract the icon inside a slot crop. Slot boxes can clip the neighboring
/// icon's edge, so take the LARGEST CONNECTED COMPONENT of icon-colored pixels
/// rather than the union bounding box; returns nil if the slot is empty.
func extractIcon(_ cg: CGImage) -> IconFeature? {
    guard let (buf, w, h) = rgba(cg) else { return nil }
    var mask8 = [Bool](repeating: false, count: w * h)
    var total = 0
    for p in 0..<(w * h) {
        let i = p * 4
        let r = Int(buf[i]), g = Int(buf[i+1]), b = Int(buf[i+2])
        if !isPlateCrimson(r, g, b) && !isDark(r, g, b) { mask8[p] = true; total += 1 }
    }
    if Double(total) / Double(w * h) < 0.12 { return nil }      // empty slot (mono-type)
    // largest 4-connected component (BFS)
    var labels = [Int](repeating: -1, count: w * h)
    var bestPixels: [Int] = []
    var cur = 0
    for start in 0..<(w * h) where mask8[start] && labels[start] < 0 {
        var queue = [start]; labels[start] = cur
        var pixels: [Int] = []
        var qi = 0
        while qi < queue.count {
            let p = queue[qi]; qi += 1
            pixels.append(p)
            let x = p % w, y = p / w
            for (nx, ny) in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]
            where nx >= 0 && nx < w && ny >= 0 && ny < h {
                let np = ny * w + nx
                if mask8[np] && labels[np] < 0 { labels[np] = cur; queue.append(np) }
            }
        }
        if pixels.count > bestPixels.count { bestPixels = pixels }
        cur += 1
    }
    let area = Double(bestPixels.count) / Double(w * h)
    if area < 0.10 { return nil }
    let x0 = bestPixels.map { $0 % w }.min()!, x1 = bestPixels.map { $0 % w }.max()!
    let y0 = bestPixels.map { $0 / w }.min()!, y1 = bestPixels.map { $0 / w }.max()!
    guard x1 - x0 > 8, y1 - y0 > 8 else { return nil }
    // sample a 24×24 grid over the bounding box
    var rs: [Double] = [], gs: [Double] = [], bs: [Double] = []
    var mask = [Bool](repeating: false, count: 24 * 24)
    for gy in 0..<24 {
        for gx in 0..<24 {
            let px = x0 + (x1 - x0) * gx / 23
            let py = y0 + (y1 - y0) * gy / 23
            let i = (py * w + px) * 4
            let r = Double(buf[i]), g = Double(buf[i+1]), b = Double(buf[i+2])
            let white = r > 195 && g > 195 && b > 195
            mask[gy * 24 + gx] = white
            if !white && !isPlateCrimson(Int(r), Int(g), Int(b)) && !isDark(Int(r), Int(g), Int(b)) {
                rs.append(r); gs.append(g); bs.append(b)
            }
        }
    }
    guard rs.count > 30 else { return nil }
    func median(_ a: [Double]) -> Double { let s = a.sorted(); return s[s.count / 2] }
    return IconFeature(color: (median(rs), median(gs), median(bs)), mask: mask, area: area)
}

func iou(_ a: [Bool], _ b: [Bool]) -> Double {
    var inter = 0, uni = 0
    for i in 0..<a.count { if a[i] && b[i] { inter += 1 }; if a[i] || b[i] { uni += 1 } }
    return uni == 0 ? 0 : Double(inter) / Double(uni)
}
func distance(_ a: IconFeature, _ b: IconFeature) -> Double {
    // Chromaticity separates hue families even when lasers darken the icon;
    // brightness enters only as a weak term.
    let sa = max(1, a.color.0 + a.color.1 + a.color.2)
    let sb = max(1, b.color.0 + b.color.1 + b.color.2)
    let dChroma = sqrt(pow(a.color.0 / sa - b.color.0 / sb, 2)
                     + pow(a.color.1 / sa - b.color.1 / sb, 2)
                     + pow(a.color.2 / sa - b.color.2 / sb, 2))
    let dBright = abs(sa - sb) / 765.0
    return 2.2 * dChroma + 0.35 * dBright + 0.6 * (1 - iou(a.mask, b.mask))
}

// MARK: manifest access
struct Slot { let fixture: String; let row: Int; let slot: Int; let rect: CGRect }   // rect normalized
func loadSlots() -> [Slot] {
    guard let data = fm.contents(atPath: manifestPath),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return [] }
    var out: [Slot] = []
    for (fixture, entry) in json {
        guard let rows = entry["rows"] as? [[String: Any]] else { continue }
        for r in rows {
            let n = r["row"] as? Int ?? 0
            for (idx, key) in [(1, "type1"), (2, "type2")] {
                if let t = r[key] as? [String: Double] {
                    out.append(Slot(fixture: fixture, row: n, slot: idx,
                                    rect: CGRect(x: t["x"]!, y: t["y"]!, width: t["w"]!, height: t["h"]!)))
                }
            }
        }
    }
    return out
}
func fixtureImage(_ stem: String) -> CGImage? {
    let name = stem.replacingOccurrences(of: "_", with: " ")
    return loadImage("\(previewDir)/\(name).HEIC")
}
func cropSlot(_ cg: CGImage, _ rect: CGRect) -> CGImage? {
    let w = Double(cg.width), h = Double(cg.height)
    return cg.cropping(to: CGRect(x: rect.minX * w, y: rect.minY * h,
                                  width: rect.width * w, height: rect.height * h))
}

// MARK: labels
// Verified by eye against the contact sheets / original screenshots.
// (fixture, row, slot) → type. Selected_with_Summary is deliberately absent — holdout.
let harvestLabels: [String: String] = [
    "Team_Preview_Initial/0/1": "Grass",    "Team_Preview_Initial/0/2": "Fairy",
    "Team_Preview_Initial/1/1": "Normal",   "Team_Preview_Initial/1/2": "Psychic",
    "Team_Preview_Initial/2/1": "Fire",     "Team_Preview_Initial/2/2": "Flying",
    "Team_Preview_Initial/3/1": "Water",    "Team_Preview_Initial/3/2": "Flying",
    "Team_Preview_Initial/4/1": "Steel",    "Team_Preview_Initial/4/2": "Dragon",
    "Team_Preview_Initial/5/1": "Grass",    "Team_Preview_Initial/5/2": "Poison",
    "Team_Preview_Submitted/0/2": "Fighting",
    "Team_Preview_Submitted/1/1": "Normal", "Team_Preview_Submitted/1/2": "Psychic",
    "Team_Preview_Submitted/2/1": "Rock",   "Team_Preview_Submitted/2/2": "Flying",
    "Team_Preview_Submitted/3/2": "Fairy",
    "Team_Preview_Submitted/4/1": "Dark",   "Team_Preview_Submitted/4/2": "Steel",
    "Team_Preview_Submitted/5/1": "Dragon", "Team_Preview_Submitted/5/2": "Ground",
    "Extra_Team_Example_2/0/1": "Bug",      "Extra_Team_Example_2/0/2": "Steel",
    "Team_with_Ice_Type/0/1": "Ice",        "Team_with_Ice_Type/0/2": "Ghost",
    "Extra_Team_Example_2/3/1": "Fire",     "Extra_Team_Example_2/3/2": "Dark",
    "Extra_Team_Example_2/4/1": "Dark",     "Extra_Team_Example_2/4/2": "Ghost",
    "Extra_Team_Example_2/5/2": "Water",
    // The 18th and final type — mono-Electric Raichu, harvested 2026-07-02
    // from the user's "Team with Electric Type" fixture (laser-free icon).
    "Team_with_Electric_Type/0/2": "Electric",
]
// Held-out ground truth for scoring only.
let holdoutLabels: [String: String] = [
    "Team_Preview_Selected_with_Summary/0/1": "Grass",  "Team_Preview_Selected_with_Summary/0/2": "Fairy",
    "Team_Preview_Selected_with_Summary/1/1": "Normal", "Team_Preview_Selected_with_Summary/1/2": "Psychic",
    "Team_Preview_Selected_with_Summary/2/1": "Fire",   "Team_Preview_Selected_with_Summary/2/2": "Flying",
    "Team_Preview_Selected_with_Summary/3/1": "Water",  "Team_Preview_Selected_with_Summary/3/2": "Flying",
    "Team_Preview_Selected_with_Summary/4/1": "Steel",  "Team_Preview_Selected_with_Summary/4/2": "Dragon",
    "Team_Preview_Selected_with_Summary/5/1": "Grass",  "Team_Preview_Selected_with_Summary/5/2": "Poison",
]

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "classify"
let slots = loadSlots()
var images: [String: CGImage] = [:]
for f in Set(slots.map { $0.fixture }) { images[f] = fixtureImage(f) }

if mode == "harvest" {
    try? fm.createDirectory(atPath: templatesDir, withIntermediateDirectories: true)
    var byType: [String: [(IconFeature, CGImage)]] = [:]
    for s in slots {
        guard let label = harvestLabels["\(s.fixture)/\(s.row)/\(s.slot)"],
              let img = images[s.fixture], let crop = cropSlot(img, s.rect),
              let feat = extractIcon(crop) else { continue }
        byType[label, default: []].append((feat, crop))
    }
    var templates: [[String: Any]] = []
    for (type, instances) in byType.sorted(by: { $0.key < $1.key }) {
        // median color across instances; glyph mask from the instance closest to that color
        let cr = instances.map { $0.0.color.0 }.sorted()[instances.count / 2]
        let cgn = instances.map { $0.0.color.1 }.sorted()[instances.count / 2]
        let cb = instances.map { $0.0.color.2 }.sorted()[instances.count / 2]
        let best = instances.min(by: {
            pow($0.0.color.0 - cr, 2) + pow($0.0.color.1 - cgn, 2) + pow($0.0.color.2 - cb, 2) <
            pow($1.0.color.0 - cr, 2) + pow($1.0.color.1 - cgn, 2) + pow($1.0.color.2 - cb, 2)
        })!
        savePNG(best.1, "\(templatesDir)/\(type).png")
        templates.append(["type": type, "color": [cr, cgn, cb],
                          "mask": best.0.mask.map { $0 ? 1 : 0 }, "instances": instances.count])
        err("\(type.padding(toLength: 9, withPad: " ", startingAt: 0)) ×\(instances.count)  " +
            String(format: "color(%3.0f,%3.0f,%3.0f)", cr, cgn, cb))
    }
    let data = try! JSONSerialization.data(withJSONObject: ["templates": templates], options: [.sortedKeys])
    try? data.write(to: URL(fileURLWithPath: "\(templatesDir)/templates.json"))
    err("harvested \(templates.count) type templates -> \(templatesDir)")
    exit(0)
}

if mode == "debug" {
    let fx = CommandLine.arguments[2]; let row = Int(CommandLine.arguments[3])!; let sl = Int(CommandLine.arguments[4])!
    guard let s = slots.first(where: { $0.fixture == fx && $0.row == row && $0.slot == sl }),
          let img = images[fx], let crop = cropSlot(img, s.rect) else { err("slot not found"); exit(1) }
    savePNG(crop, "/tmp/debug_slot.png")
    guard let feat = extractIcon(crop) else { err("extractIcon: EMPTY"); exit(0) }
    err(String(format: "extracted color (%.0f,%.0f,%.0f) area %.2f", feat.color.0, feat.color.1, feat.color.2, feat.area))
    for gy in 0..<24 { err(String((0..<24).map { feat.mask[gy * 24 + $0] ? "#" : "." })) }
    if let tdata = fm.contents(atPath: "\(templatesDir)/templates.json"),
       let tjson = try? JSONSerialization.jsonObject(with: tdata) as? [String: [[String: Any]]] {
        let temps: [(String, IconFeature)] = tjson["templates"]!.map { t in
            let c = t["color"] as! [Double]
            let m = (t["mask"] as! [Int]).map { $0 == 1 }
            return (t["type"] as! String, IconFeature(color: (c[0], c[1], c[2]), mask: m, area: 1))
        }
        for (name, tf) in temps.sorted(by: { distance(feat, $0.1) < distance(feat, $1.1) }).prefix(4) {
            let dc = sqrt(pow(feat.color.0 - tf.color.0, 2) + pow(feat.color.1 - tf.color.1, 2) + pow(feat.color.2 - tf.color.2, 2)) / 441.7
            err(String(format: "  %@ total %.3f (color %.3f, maskIoU %.2f)", name, distance(feat, tf), dc, iou(feat.mask, tf.mask)))
        }
    }
    exit(0)
}

// MARK: classify
guard let tdata = fm.contents(atPath: "\(templatesDir)/templates.json"),
      let tjson = try? JSONSerialization.jsonObject(with: tdata) as? [String: [[String: Any]]],
      let tarr = tjson["templates"] else { err("no templates — run harvest first"); exit(1) }
let templates: [(String, IconFeature)] = tarr.map { t in
    let c = t["color"] as! [Double]
    let m = (t["mask"] as! [Int]).map { $0 == 1 }
    return (t["type"] as! String, IconFeature(color: (c[0], c[1], c[2]), mask: m, area: 1))
}

var results: [String: [[String: Any]]] = [:]
var okH = 0, nH = 0, okT = 0, nT = 0
var lines: [String] = []
for s in slots.sorted(by: { ($0.fixture, $0.row, $0.slot) < ($1.fixture, $1.row, $1.slot) }) {
    guard let img = images[s.fixture], let crop = cropSlot(img, s.rect) else { continue }
    let key = "\(s.fixture)/\(s.row)/\(s.slot)"
    var verdict = "—"
    var conf = 0.0
    if let feat = extractIcon(crop) {
        let scored = templates.map { ($0.0, distance(feat, $0.1)) }.sorted { $0.1 < $1.1 }
        verdict = scored[0].0
        conf = scored[1].1 - scored[0].1        // margin to runner-up
        results[s.fixture, default: []].append(["row": s.row, "slot": s.slot, "type": verdict,
                                                "dist": scored[0].1, "margin": conf])
    }
    if let truth = holdoutLabels[key] { nH += 1; if verdict == truth { okH += 1 }
        lines.append("HOLDOUT \(key): \(verdict) (truth \(truth)) \(verdict == truth ? "✓" : "✗")")
    } else if let truth = harvestLabels[key] { nT += 1; if verdict == truth { okT += 1 }
        if verdict != truth { lines.append("TRAIN-MISS \(key): \(verdict) ≠ \(truth)") }
    } else {
        lines.append("NEW     \(key): \(verdict) margin=\(String(format: "%.2f", conf))")
    }
}
for l in lines { err(l) }
err("holdout: \(okH)/\(nH)   train-consistency: \(okT)/\(nT)")
let out = try! JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
try? out.write(to: URL(fileURLWithPath: "\(scopeLensFixturesRoot)/preview/types.json"))
err("wrote Fixtures/preview/types.json")
