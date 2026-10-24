import Foundation
import AppKit
import CoreImage
import ImageIO

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

// TeamPreviewReader — isolates the six opponent rows on the Team Preview screen
// into {plate, sprite, type1, type2, gender} crops plus a manifest.
// Detection is dynamic (crimson plate column), because the opponent column sits
// at different x positions in the pre-submit vs submitted layouts.

let repoRoot = FileManager.default.currentDirectoryPath
let previewDir = "\(scopeLensFixturesRoot)/screenshots/iPhone 17 Pro Max/Team Preview"
let outRoot = "\(scopeLensFixturesRoot)/preview"
let fm = FileManager.default
func err(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

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
func rgbaTopLeft(_ cg: CGImage) -> ([UInt8], Int, Int)? {
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

// Opponent plates are a dark crimson/raspberry. Range set from probe samples:
// interiors span (86..177, 2..25, 31..75); shaded edges reach r≈70.
@inline(__always) func isPlate(_ r: Int, _ g: Int, _ b: Int) -> Bool {
    r >= 70 && r <= 210 && g <= 70 && b >= 25 && b <= 115 && (r - g) >= 55 && (r - b) >= 30 && (b - g) >= 12
}

let fixtures = ((try? fm.contentsOfDirectory(atPath: previewDir)) ?? [])
    .filter { $0.lowercased().hasSuffix(".heic") }.sorted().map { "\(previewDir)/\($0)" }

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "extract"

if mode == "probe" {
    for path in fixtures {
        let name = (path as NSString).lastPathComponent
        guard let cg = loadImage(path), let (buf, w, h) = rgbaTopLeft(cg) else { continue }
        err("== \(name) ==")
        for xN in [0.68, 0.71, 0.74, 0.77, 0.80, 0.83, 0.86] {
            var line = String(format: "x=%.2f:", xN)
            for yN in [0.14, 0.17, 0.235, 0.30, 0.45, 0.60, 0.75, 0.82] {
                let i = (Int(yN * Double(h)) * w + Int(xN * Double(w))) * 4
                let r = Int(buf[i]), g = Int(buf[i+1]), b = Int(buf[i+2])
                line += String(format: " (%.2f:%3d,%3d,%3d%@)", yN, r, g, b, isPlate(r, g, b) ? "*" : " ")
            }
            err(line)
        }
    }
    exit(0)
}

// MARK: extract
struct Row { let x0: Int, x1: Int, y0: Int, y1: Int }

var manifest: [String: Any] = [:]
for path in fixtures {
    let name = (path as NSString).lastPathComponent
    let stem = ((name as NSString).deletingPathExtension).replacingOccurrences(of: " ", with: "_")
    guard let cg = loadImage(path), let (buf, w, h) = rgbaTopLeft(cg) else { continue }
    let yLo = Int(0.10 * Double(h)), yHi = Int(0.93 * Double(h))

    // 1) find the opponent plate column: x-histogram of plate pixels in right 55%
    var colCount = [Int](repeating: 0, count: w)
    for y in yLo..<yHi {
        let base = y * w * 4
        for x in Int(0.55 * Double(w))..<w {
            let i = base + x * 4
            if isPlate(Int(buf[i]), Int(buf[i+1]), Int(buf[i+2])) { colCount[x] += 1 }
        }
    }
    // Sprites/icons sit on the plates, so per-x crimson density dips inside the
    // column — use a low threshold and merge runs across small gaps.
    let colThresh = Int(0.12 * Double(yHi - yLo))
    var runs: [(Int, Int)] = []; var runStart = -1
    for x in 0..<w {
        let hit = colCount[x] >= colThresh
        if hit && runStart < 0 { runStart = x }
        if (!hit || x == w - 1) && runStart >= 0 { runs.append((runStart, hit ? x : x - 1)); runStart = -1 }
    }
    var merged: [(Int, Int)] = []
    for r in runs {
        if var last = merged.last, r.0 - last.1 <= Int(0.02 * Double(w)) {
            last.1 = r.1; merged[merged.count - 1] = last
        } else { merged.append(r) }
    }
    let bestRun = merged.filter { $0.1 - $0.0 > Int(0.06 * Double(w)) }.max { ($0.1 - $0.0) < ($1.1 - $1.0) }
    guard let (cx0, cx1) = bestRun else { err("!! \(name): no plate column found"); continue }

    // 2) rows via hysteresis: a plate's bottom half is dense crimson (seed),
    // its sprite/icon-covered top half is ~25% (extend), and gaps are laser
    // noise ≤~15% (stop). A single threshold cannot separate the last two.
    var density = [Int](repeating: 0, count: h)
    for y in yLo...yHi {
        var cnt = 0
        let base = y * w * 4
        for x in cx0...cx1 {
            let i = base + x * 4
            if isPlate(Int(buf[i]), Int(buf[i+1]), Int(buf[i+2])) { cnt += 1 }
        }
        density[y] = cnt
    }
    // Smooth, then anchor rows on plate BOTTOM edges — the one transition that
    // is always crisp (full-width crimson → gap). Tops can be soft where sprite
    // art overflows the plate, so pair each bottom with a top edge when one
    // exists and fall back to the median plate height when it doesn't.
    var d = density
    for y in (yLo + 2)...(yHi - 2) { d[y] = (density[y-2] + density[y-1] + density[y] + density[y+1] + density[y+2]) / 5 }
    let hiT = Int(0.30 * Double(cx1 - cx0))
    let loT = Int(0.13 * Double(cx1 - cx0))
    // The smoothed profile ramps over ~5px at plate edges, so test contrast
    // across a 7px window rather than adjacent pixels.
    var downs: [Int] = [], ups: [Int] = []
    for y in (yLo + 4)...(yHi - 4) {
        if d[y - 3] >= hiT && d[y + 4] <= loT { if downs.last.map({ y - $0 > 8 }) ?? true { downs.append(y) } }
        if d[y + 3] >= hiT && d[y - 4] <= loT { if ups.last.map({ y - $0 > 8 }) ?? true { ups.append(y) } }
    }
    // Pair edges; any edge whose partner is missing (laser noise, band edge)
    // gets one synthesized from the median plate height.
    let minH = Int(0.06 * Double(h)), maxH = Int(0.125 * Double(h))
    let paired = ups.compactMap { up in
        downs.first(where: { $0 > up && $0 - up >= minH && $0 - up <= maxH }).map { (up, $0) }
    }
    let heights = paired.map { $0.1 - $0.0 }.sorted()
    let medH = heights.isEmpty ? Int(0.107 * Double(h)) : heights[heights.count / 2]
    var extents: [(Int, Int)] = []
    for up in ups {
        if let down = downs.first(where: { $0 > up && $0 - up >= minH && $0 - up <= maxH }) { extents.append((up, down)) }
        else { extents.append((up, min(up + medH, yHi))) }
    }
    for down in downs where !extents.contains(where: { abs($0.1 - down) <= 4 }) {
        extents.append((max(yLo, down - medH), down))
    }
    extents.sort { $0.0 < $1.0 }
    var rows: [Row] = []
    for e in extents {
        if let last = rows.last, e.0 <= last.y1 - Int(0.02 * Double(h)) { continue }   // overlap → duplicate
        // Plate interiors stay ≥ ~0.42 crimson; floor reflections sit ≈ 0.26.
        let mid0 = e.0 + (e.1 - e.0) / 5, mid1 = e.1 - (e.1 - e.0) / 5
        let meanD = (mid0...mid1).map { density[$0] }.reduce(0, +) / max(1, mid1 - mid0 + 1)
        if meanD < Int(0.35 * Double(cx1 - cx0)) { continue }
        rows.append(Row(x0: cx0, x1: cx1, y0: e.0, y1: e.1))
    }
    if rows.count > 6 { rows = Array(rows.prefix(6)) }
    err("  edges: \(ups.count) up / \(downs.count) down, medH=\(String(format: "%.3f", Double(medH) / Double(h)))h")

    err(String(format: "• %@: column x[%.3f–%.3f], %d row(s)", name,
               Double(cx0) / Double(w), Double(cx1) / Double(w), rows.count))

    // 3) component crops per row
    let fixDir = "\(outRoot)/\(stem)"
    try? fm.createDirectory(atPath: fixDir, withIntermediateDirectories: true)
    // relative component boxes within a plate (fractions of plate w/h)
    // The two sub-layouts mirror the plate internals: the submitted/"Preparing
    // for Battle" screen (column further left) puts type icons top-right with
    // gender below; the pre-submit roster puts gender top-right with icons
    // bottom-right. Mono-type: the single icon occupies the type2 slot.
    let layoutB = Double(cx0) / Double(w) < 0.72     // submitted variant
    // Sprite fractions restored 2026-07-02 from the committed manifest.json:
    // the source had drifted from the geometry that produced the verified
    // species accuracy (top-3 22/25); these values reproduce it.
    let comps: [(String, Double, Double, Double, Double)] = layoutB ? [
        ("plate",    0.00, 0.00, 1.00, 1.00),
        ("sprite",  -0.019, -0.117, 0.558, 1.117),
        ("typeBand", 0.58, 0.02, 0.44, 0.46),
        ("type1",    0.60, 0.02, 0.22, 0.46),
        ("type2",    0.80, 0.02, 0.22, 0.46),
        ("gender",   0.56, 0.40, 0.44, 0.55),
    ] : [
        // Pre-submit: each entry's art anchors to its plate's TOP seam and
        // overhangs upward (negative y offsets, in fractions of plate height).
        ("plate",    0.00, 0.00, 1.00, 1.00),
        ("sprite",  -0.039, -0.894, 0.579, 1.234),
        ("typeBand", 0.53, -0.64, 0.44, 0.64),
        ("type1",    0.55, -0.64, 0.20, 0.64),
        ("type2",    0.73, -0.64, 0.20, 0.64),
        ("gender",   0.58, -0.05, 0.26, 0.42),
    ]
    var rowsJSON: [[String: Any]] = []
    var cellImgs: [[CGImage]] = []
    for (n, r) in rows.enumerated() {
        let pw = r.x1 - r.x0, ph = r.y1 - r.y0
        var cells: [CGImage] = []
        var rowJSON: [String: Any] = [
            "row": n,
            "plate": ["x": Double(r.x0)/Double(w), "y": Double(r.y0)/Double(h),
                      "w": Double(pw)/Double(w),  "h": Double(ph)/Double(h)]
        ]
        for (tag, fx, fy, fw, fh) in comps {
            let cxa = max(0, r.x0 + Int(fx * Double(pw))), cya = max(0, r.y0 + Int(fy * Double(ph)))
            let cw = Int(fw * Double(pw)), ch = Int(fh * Double(ph))
            let rect = CGRect(x: cxa, y: cya, width: min(cw, w - cxa), height: min(ch, h - cya))
            if let crop = cg.cropping(to: rect) {
                savePNG(crop, "\(fixDir)/row\(n)_\(tag).png")
                cells.append(crop)
                if tag != "plate" {
                    rowJSON[tag] = ["x": Double(cxa)/Double(w), "y": Double(cya)/Double(h),
                                    "w": Double(rect.width)/Double(w), "h": Double(rect.height)/Double(h)]
                }
            }
        }
        // cheap gender classification: blue-dominant = male, red/pink-dominant = female
        let gBox = comps.first { $0.0 == "gender" }!
        if let gcrop = cg.cropping(to: CGRect(x: max(0, r.x0 + Int(gBox.1 * Double(pw))),
                                              y: max(0, r.y0 + Int(gBox.2 * Double(ph))),
                                              width: Int(gBox.3 * Double(pw)), height: Int(gBox.4 * Double(ph)))),
           let (gbuf, gw, gh) = rgbaTopLeft(gcrop) {
            var blue = 0, red = 0
            for i in stride(from: 0, to: gw * gh * 4, by: 4) {
                let r0 = Int(gbuf[i]), g0 = Int(gbuf[i+1]), b0 = Int(gbuf[i+2])
                if b0 >= 170 && (b0 - r0) >= 70 && g0 <= 170 { blue += 1 }             // ♂ saturated blue
                // ♀ pure red; b ≤ 105 excludes pink laser cores (b ≥ ~120)
                if r0 >= 190 && g0 <= 90 && b0 <= 105 && (r0 - g0) >= 110 && (r0 - b0) >= 90 { red += 1 }
            }
            rowJSON["gender"] = (rowJSON["gender"] as? [String: Any])?.merging(
                ["guess": blue > red * 2 ? "male" : (red > blue * 2 ? "female" : "unknown"),
                 "bluePx": blue, "redPx": red]) { a, _ in a }
        }
        rowsJSON.append(rowJSON)
        cellImgs.append(cells)
    }
    manifest[stem] = ["column": ["x0": Double(cx0)/Double(w), "x1": Double(cx1)/Double(w)], "rows": rowsJSON]

    // 4) contact sheet: rows × [plate, sprite, type1, type2, gender]
    let cell = 110, pad = 6
    let cols = 6
    let sheetW = cols * (cell + pad) + pad
    let sheetH = cellImgs.count * (cell + pad) + pad
    if let ctx = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8,
                           bytesPerRow: sheetW * 4, space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
        ctx.setFillColor(CGColor(gray: 0.12, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
        for (ri, cells) in cellImgs.enumerated() {
            for (ci, img) in cells.enumerated() {
                let scale = min(Double(cell) / Double(img.width), Double(cell) / Double(img.height))
                let dw = Double(img.width) * scale, dh = Double(img.height) * scale
                let ox = Double(pad + ci * (cell + pad)) + (Double(cell) - dw) / 2
                // CGContext origin bottom-left; row 0 at top
                let oy = Double(sheetH - (pad + (ri + 1) * (cell + pad))) + (Double(cell) - dh) / 2
                ctx.draw(img, in: CGRect(x: ox, y: oy, width: dw, height: dh))
            }
        }
        if let sheet = ctx.makeImage() { savePNG(sheet, "\(outRoot)/\(stem)_sheet.png") }
    }
}
let json = try! JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try? json.write(to: URL(fileURLWithPath: "\(outRoot)/manifest.json"))
err("wrote \(outRoot)/manifest.json")
