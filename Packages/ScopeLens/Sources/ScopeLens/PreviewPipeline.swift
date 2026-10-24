//
//  PreviewPipeline.swift
//  Scope Lens
//
//  Phase 2, milestone 3a: the team-preview reading pipeline, in the app target.
//  Faithful port of the verified Phase-1 diagnostics (TeamPreviewReader →
//  TypeIconClassifier → SpeciesIdentifier); the originals remain in
//  Diagnostics/ as standalone CLIs, and Diagnostics/PreviewPipelineHarness.swift
//  proves this port reproduces their verified accuracy on the still fixtures
//  (type holdout 12/12; species top-1 14/25, top-3 22/25).
//
//  Inputs are full-resolution viewport frames (normalized-coordinate world);
//  outputs are per-row reads: type pair (+margins), species top-3, gender, and
//  the crops the UI needs for thumbnails. Frame voting across a preview's
//  lifetime lives in PreviewAggregate (same file, used by the live tracker).
//
//  Reference resources (bundled; see Resources/PreviewPipeline/):
//  - templates.json        type-icon color+glyph templates (17/18, Electric pending)
//  - species-index.json    species → num/types + icon-sheet position
//  - pokemonicons-sheet.png pixel menu icons (pose-true reference + UI thumbnails)
//  - dex-features.json     precomputed 24×24 features of the Showdown HOME
//                          renders (palette-true reference) — the 96MB sprite
//                          folder itself stays out of the app.
//

import Foundation
import CoreGraphics
import ImageIO

// MARK: - Pixel plumbing

/// Top-left-origin RGBA buffer of a CGImage.
nonisolated public struct RGBABuffer {
    public let pixels: [UInt8]
    public let width: Int
    public let height: Int

    public init?(_ cg: CGImage) {
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        self.pixels = buf
        self.width = w
        self.height = h
    }
}

/// Opponent plates are a dark crimson/raspberry (range set from probe samples).
@inline(__always) nonisolated func isPlateCrimson(_ r: Int, _ g: Int, _ b: Int) -> Bool {
    r >= 70 && r <= 210 && g <= 70 && b >= 25 && b <= 115 && (r - g) >= 55 && (r - b) >= 30 && (b - g) >= 12
}
@inline(__always) nonisolated func isDarkPixel(_ r: Int, _ g: Int, _ b: Int) -> Bool { r + g + b < 150 }

/// Largest 4-connected component of `mask` (as pixel indices), or [] if none.
nonisolated public func largestComponent(mask: [Bool], w: Int, h: Int) -> [Int] {
    var labels = [Bool](repeating: false, count: w * h)
    var best: [Int] = []
    for start in 0..<(w * h) where mask[start] && !labels[start] {
        var queue = [start]; labels[start] = true
        var qi = 0
        var pixels: [Int] = []
        while qi < queue.count {
            let p = queue[qi]; qi += 1
            pixels.append(p)
            let x = p % w, y = p / w
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            where nx >= 0 && nx < w && ny >= 0 && ny < h {
                let np = ny * w + nx
                if mask[np] && !labels[np] { labels[np] = true; queue.append(np) }
            }
        }
        if pixels.count > best.count { best = pixels }
    }
    return best
}

// MARK: - Row detection (port of TeamPreviewReader)

nonisolated public struct PreviewRowGeometry: Sendable {
    public let row: Int
    public let plate: CGRect      // pixel rect in the source frame
    public let sprite: CGRect
    public let type1: CGRect
    public let type2: CGRect
    public let gender: CGRect
}

nonisolated public enum TeamPreviewRowDetector {

    /// Detect the opponent column and its ≤6 rows. Returns nil when the frame
    /// has no recognizable plate column (not a team-preview frame).
    public static func detectRows(in buf: RGBABuffer) -> (layoutSubmitted: Bool, rows: [PreviewRowGeometry])? {
        let w = buf.width, h = buf.height, pixels = buf.pixels
        let yLo = Int(0.10 * Double(h)), yHi = Int(0.93 * Double(h))

        // 1) opponent plate column: x-histogram of crimson pixels in right 55%
        var colCount = [Int](repeating: 0, count: w)
        for y in yLo..<yHi {
            let base = y * w * 4
            for x in Int(0.55 * Double(w))..<w {
                let i = base + x * 4
                if isPlateCrimson(Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2])) { colCount[x] += 1 }
            }
        }
        let colThresh = Int(0.12 * Double(yHi - yLo))
        var runs: [(Int, Int)] = []
        var runStart = -1
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
        guard let (cx0, cx1) = merged.filter({ $0.1 - $0.0 > Int(0.06 * Double(w)) })
            .max(by: { ($0.1 - $0.0) < ($1.1 - $1.0) }) else { return nil }

        // 2) rows via hysteresis on the column's per-y crimson density
        var density = [Int](repeating: 0, count: h)
        for y in yLo...yHi {
            var cnt = 0
            let base = y * w * 4
            for x in cx0...cx1 {
                let i = base + x * 4
                if isPlateCrimson(Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2])) { cnt += 1 }
            }
            density[y] = cnt
        }
        var d = density
        for y in (yLo + 2)...(yHi - 2) {
            d[y] = (density[y - 2] + density[y - 1] + density[y] + density[y + 1] + density[y + 2]) / 5
        }
        let hiT = Int(0.30 * Double(cx1 - cx0))
        let loT = Int(0.13 * Double(cx1 - cx0))
        var downs: [Int] = [], ups: [Int] = []
        for y in (yLo + 4)...(yHi - 4) {
            if d[y - 3] >= hiT && d[y + 4] <= loT { if downs.last.map({ y - $0 > 8 }) ?? true { downs.append(y) } }
            if d[y + 3] >= hiT && d[y - 4] <= loT { if ups.last.map({ y - $0 > 8 }) ?? true { ups.append(y) } }
        }
        let minH = Int(0.06 * Double(h)), maxH = Int(0.125 * Double(h))
        let paired = ups.compactMap { up in
            downs.first(where: { $0 > up && $0 - up >= minH && $0 - up <= maxH }).map { (up, $0) }
        }
        let heights = paired.map { $0.1 - $0.0 }.sorted()
        let medH = heights.isEmpty ? Int(0.107 * Double(h)) : heights[heights.count / 2]
        var extents: [(Int, Int)] = []
        for up in ups {
            if let down = downs.first(where: { $0 > up && $0 - up >= minH && $0 - up <= maxH }) {
                extents.append((up, down))
            } else {
                extents.append((up, min(up + medH, yHi)))
            }
        }
        for down in downs where !extents.contains(where: { abs($0.1 - down) <= 4 }) {
            extents.append((max(yLo, down - medH), down))
        }
        extents.sort { $0.0 < $1.0 }

        var plates: [(Int, Int)] = []
        for e in extents {
            if let last = plates.last, e.0 <= last.1 - Int(0.02 * Double(h)) { continue }
            let mid0 = e.0 + (e.1 - e.0) / 5, mid1 = e.1 - (e.1 - e.0) / 5
            let meanD = (mid0...mid1).map { density[$0] }.reduce(0, +) / max(1, mid1 - mid0 + 1)
            if meanD < Int(0.35 * Double(cx1 - cx0)) { continue }   // floor reflection
            plates.append(e)
        }
        if plates.count > 6 { plates = Array(plates.prefix(6)) }
        guard !plates.isEmpty else { return nil }

        // 3) component boxes per row (sub-layouts mirror the plate internals;
        // fractions match the Phase-1 reader, incl. the 2026-07-02 restoration)
        let layoutSubmitted = Double(cx0) / Double(w) < 0.72
        let comps: [(Double, Double, Double, Double)] = layoutSubmitted
            ? [(-0.019, -0.117, 0.558, 1.117),   // sprite
               (0.60, 0.02, 0.22, 0.46),         // type1
               (0.80, 0.02, 0.22, 0.46),         // type2
               (0.56, 0.40, 0.44, 0.55)]         // gender
            : [(-0.039, -0.894, 0.579, 1.234),
               (0.55, -0.64, 0.20, 0.64),
               (0.73, -0.64, 0.20, 0.64),
               (0.58, -0.05, 0.26, 0.42)]

        let rows = plates.enumerated().map { (n, e) -> PreviewRowGeometry in
            let pw = cx1 - cx0, ph = e.1 - e.0
            func box(_ c: (Double, Double, Double, Double)) -> CGRect {
                let x = max(0, cx0 + Int(c.0 * Double(pw))), y = max(0, e.0 + Int(c.1 * Double(ph)))
                return CGRect(x: x, y: y,
                              width: min(Int(c.2 * Double(pw)), w - x),
                              height: min(Int(c.3 * Double(ph)), h - y))
            }
            return PreviewRowGeometry(
                row: n,
                plate: CGRect(x: cx0, y: e.0, width: pw, height: ph),
                sprite: box(comps[0]), type1: box(comps[1]),
                type2: box(comps[2]), gender: box(comps[3])
            )
        }
        return (layoutSubmitted, rows)
    }
}

// MARK: - Type icon classification (port of TypeIconClassifier)

nonisolated public struct TypeRead: Sendable, Codable {
    public let type: String
    public let dist: Double
    public let margin: Double     // ≤ ~0.05 ⇒ unreliable, widen candidates
}

nonisolated public struct IconFeature {
    public var color: (Double, Double, Double)
    public var mask: [Bool]       // 24×24 white-glyph grid
}

nonisolated public final class TypeIconCore {
    private let templates: [(String, IconFeature)]

    public init(templatesJSON data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]],
              let arr = json["templates"] else {
            throw NSError(domain: "PreviewPipeline", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "bad templates.json"])
        }
        templates = arr.map { t in
            let c = t["color"] as! [Double]
            let m = (t["mask"] as! [Int]).map { $0 == 1 }
            return (t["type"] as! String, IconFeature(color: (c[0], c[1], c[2]), mask: m))
        }
    }

    /// Icon feature from a slot crop: largest connected component of
    /// icon-colored (non-crimson, non-dark) pixels; nil = empty slot.
    public static func extractIcon(_ buf: RGBABuffer) -> IconFeature? {
        let w = buf.width, h = buf.height, pixels = buf.pixels
        var mask = [Bool](repeating: false, count: w * h)
        var total = 0
        for p in 0..<(w * h) {
            let i = p * 4
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            if !isPlateCrimson(r, g, b) && !isDarkPixel(r, g, b) { mask[p] = true; total += 1 }
        }
        if Double(total) / Double(w * h) < 0.12 { return nil }
        let comp = largestComponent(mask: mask, w: w, h: h)
        let area = Double(comp.count) / Double(w * h)
        if area < 0.10 { return nil }
        let xs = comp.map { $0 % w }, ys = comp.map { $0 / w }
        let x0 = xs.min()!, x1 = xs.max()!, y0 = ys.min()!, y1 = ys.max()!
        guard x1 - x0 > 8, y1 - y0 > 8 else { return nil }

        var rs: [Double] = [], gs: [Double] = [], bs: [Double] = []
        var glyph = [Bool](repeating: false, count: 24 * 24)
        for gy in 0..<24 {
            for gx in 0..<24 {
                let px = x0 + (x1 - x0) * gx / 23
                let py = y0 + (y1 - y0) * gy / 23
                let i = (py * w + px) * 4
                let r = Double(pixels[i]), g = Double(pixels[i + 1]), b = Double(pixels[i + 2])
                let white = r > 195 && g > 195 && b > 195
                glyph[gy * 24 + gx] = white
                if !white && !isPlateCrimson(Int(r), Int(g), Int(b)) && !isDarkPixel(Int(r), Int(g), Int(b)) {
                    rs.append(r); gs.append(g); bs.append(b)
                }
            }
        }
        guard rs.count > 30 else { return nil }
        func median(_ a: [Double]) -> Double { let s = a.sorted(); return s[s.count / 2] }
        return IconFeature(color: (median(rs), median(gs), median(bs)), mask: glyph)
    }

    public static func distance(_ a: IconFeature, _ b: IconFeature) -> Double {
        let sa = max(1, a.color.0 + a.color.1 + a.color.2)
        let sb = max(1, b.color.0 + b.color.1 + b.color.2)
        let dChroma = (pow(a.color.0 / sa - b.color.0 / sb, 2)
                     + pow(a.color.1 / sa - b.color.1 / sb, 2)
                     + pow(a.color.2 / sa - b.color.2 / sb, 2)).squareRoot()
        let dBright = abs(sa - sb) / 765.0
        var inter = 0, uni = 0
        for i in 0..<a.mask.count {
            if a.mask[i] && b.mask[i] { inter += 1 }
            if a.mask[i] || b.mask[i] { uni += 1 }
        }
        let iou = uni == 0 ? 0 : Double(inter) / Double(uni)
        return 2.2 * dChroma + 0.35 * dBright + 0.6 * (1 - iou)
    }

    /// Best type for a slot crop, or nil for an empty slot (mono-type marker).
    public func classify(slot: CGImage) -> TypeRead? {
        guard let buf = RGBABuffer(slot), let feat = Self.extractIcon(buf) else { return nil }
        let scored = templates.map { ($0.0, Self.distance(feat, $0.1)) }.sorted { $0.1 < $1.1 }
        guard scored.count >= 2 else { return nil }
        return TypeRead(type: scored[0].0, dist: scored[0].1, margin: scored[1].1 - scored[0].1)
    }
}

// MARK: - Species identification (port of SpeciesIdentifier)

nonisolated public struct SpeciesCandidate: Sendable, Codable {
    public let name: String
    public let num: Int
    public let fusedRank: Double
}

nonisolated public struct SpriteFeature {
    public var fg: [Bool]                          // 24×24 foreground mask
    public var color: [(Double, Double, Double)]   // per-cell mean RGB
}

nonisolated public final class SpeciesCore {
    struct SpeciesRef {
        let name: String
        let num: Int
        let types: Set<String>
        let sheetLeft: Int
        let sheetTop: Int
    }

    static let grid = 24
    private let species: [SpeciesRef]
    private var pixelFeatures: [String: SpriteFeature] = [:]
    private var dexFeatures: [String: SpriteFeature] = [:]
    /// Champions-native crops banked from confirmed reads (m5) — the ONLY
    /// reference that is the same art as the query. Multiple features per
    /// species (layouts, shinies, laser conditions); source-tagged so offline
    /// evaluation can hold out the fixture being scored.
    private var nativeFeatures: [String: [(source: String, feature: SpriteFeature)]] = [:]
    /// Thumbnails for the UI (40×30 sheet icons by species name).
    private let sheet: CGImage

    /// Same-art decisive match: calibrated on 75 banked crops (2026-07-03) —
    /// same-species cross-source median 0.078, cross-species floor 0.450.
    static let nativeDecisiveDistance = 0.30
    static let nativeDecisiveMargin = 0.15

    /// Evaluation-only: pretend crops from this source were never banked
    /// (leave-one-source-out scoring). Never set in the app.
    public var evalExcludeNativeSource: String?

    public init(indexJSON: Data, sheet: CGImage, dexFeaturesJSON: Data?,
                nativeFeaturesJSON: Data? = nil, nativeOverlayJSON: Data? = nil) throws {
        guard let idx = try JSONSerialization.jsonObject(with: indexJSON) as? [[String: Any]] else {
            throw NSError(domain: "PreviewPipeline", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "bad species-index.json"])
        }
        self.sheet = sheet
        species = idx.map {
            SpeciesRef(name: $0["name"] as! String, num: $0["num"] as! Int,
                       types: Set($0["types"] as! [String]),
                       sheetLeft: $0["left"] as! Int, sheetTop: $0["top"] as! Int)
        }
        // Pixel features: computed once from the bundled sheet (pose-true ref).
        for s in species {
            if let icon = sheet.cropping(to: CGRect(x: s.sheetLeft, y: s.sheetTop, width: 40, height: 30)),
               let buf = RGBABuffer(icon),
               let f = Self.feature(buf: buf, useAlpha: true) {
                pixelFeatures[s.name] = f
            }
        }
        // Dex features: precomputed from the (gitignored) HOME renders.
        if let data = dexFeaturesJSON,
           let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: [Double]]] {
            for (name, entry) in json {
                guard let fgArr = entry["fg"], let colArr = entry["color"],
                      fgArr.count == Self.grid * Self.grid,
                      colArr.count == Self.grid * Self.grid * 3 else { continue }
                var f = SpriteFeature(fg: fgArr.map { $0 > 0.5 },
                                      color: .init(repeating: (0, 0, 0), count: Self.grid * Self.grid))
                for i in 0..<(Self.grid * Self.grid) {
                    f.color[i] = (colArr[i * 3], colArr[i * 3 + 1], colArr[i * 3 + 2])
                }
                dexFeatures[name] = f
            }
        }
        // Native features: precomputed from banked confirmed crops (m5),
        // plus the live confirm-tap overlay from Application Support (m7a).
        for data in [nativeFeaturesJSON, nativeOverlayJSON] {
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]]
            else { continue }
            for (name, list) in json {
                for entry in list {
                    guard let fgArr = entry["fg"] as? [Int], let colArr = entry["color"] as? [Int],
                          fgArr.count == Self.grid * Self.grid,
                          colArr.count == fgArr.count * 3 else { continue }
                    var f = SpriteFeature(fg: fgArr.map { $0 > 0 },
                                          color: .init(repeating: (0, 0, 0), count: fgArr.count))
                    for i in 0..<fgArr.count {
                        f.color[i] = (Double(colArr[i * 3]), Double(colArr[i * 3 + 1]),
                                      Double(colArr[i * 3 + 2]))
                    }
                    nativeFeatures[name, default: []].append(
                        (entry["source"] as? String ?? "unknown", f))
                }
            }
        }
    }

    public var hasNativeReference: Bool { !nativeFeatures.isEmpty }

    public var hasDexReference: Bool { !dexFeatures.isEmpty }

    /// 40×30 sheet icon for a species (UI thumbnails).
    public func thumbnail(for name: String) -> CGImage? {
        guard let s = species.first(where: { $0.name == name }) else { return nil }
        return sheet.cropping(to: CGRect(x: s.sheetLeft, y: s.sheetTop, width: 40, height: 30))
    }

    /// Grid feature: largest CC of non-plate/non-dark pixels (screenshot crops)
    /// or alpha>128 (reference icons), placed aspect-preserving into 24×24.
    public static func feature(buf: RGBABuffer, useAlpha: Bool) -> SpriteFeature? {
        let w = buf.width, h = buf.height, pixels = buf.pixels
        var mask = [Bool](repeating: false, count: w * h)
        var total = 0
        for p in 0..<(w * h) {
            let i = p * 4
            if useAlpha {
                if pixels[i + 3] > 128 { mask[p] = true; total += 1 }
            } else {
                let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
                if !isPlateCrimson(r, g, b) && !isDarkPixel(r, g, b) { mask[p] = true; total += 1 }
            }
        }
        guard total > 60 else { return nil }
        var keep = mask
        if !useAlpha {
            let comp = largestComponent(mask: mask, w: w, h: h)
            guard comp.count > 60 else { return nil }
            keep = [Bool](repeating: false, count: w * h)
            for p in comp { keep[p] = true }
        }
        var x0 = w, x1 = 0, y0 = h, y1 = 0
        for p in 0..<(w * h) where keep[p] {
            let x = p % w, y = p / w
            x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
        }
        guard x1 - x0 > 6, y1 - y0 > 6 else { return nil }
        let bw = Double(x1 - x0 + 1), bh = Double(y1 - y0 + 1)
        let scale = Double(grid) / max(bw, bh)
        let ox = (Double(grid) - bw * scale) / 2, oy = (Double(grid) - bh * scale) / 2
        var fg = [Bool](repeating: false, count: grid * grid)
        var sums = [(Double, Double, Double, Double)](repeating: (0, 0, 0, 0), count: grid * grid)
        for p in 0..<(w * h) where keep[p] {
            let x = p % w, y = p / w
            let gx = min(grid - 1, max(0, Int(ox + (Double(x - x0) + 0.5) * scale)))
            let gy = min(grid - 1, max(0, Int(oy + (Double(y - y0) + 0.5) * scale)))
            let gi = gy * grid + gx
            let i = p * 4
            sums[gi].0 += Double(pixels[i]); sums[gi].1 += Double(pixels[i + 1])
            sums[gi].2 += Double(pixels[i + 2]); sums[gi].3 += 1
            fg[gi] = true
        }
        var color = [(Double, Double, Double)](repeating: (0, 0, 0), count: grid * grid)
        for gi in 0..<(grid * grid) where sums[gi].3 > 0 {
            color[gi] = (sums[gi].0 / sums[gi].3, sums[gi].1 / sums[gi].3, sums[gi].2 / sums[gi].3)
        }
        return SpriteFeature(fg: fg, color: color)
    }

    public static func matchScore(_ a: SpriteFeature, _ b: SpriteFeature) -> Double {
        var inter = 0, uni = 0
        var dc = 0.0
        var nc = 0
        for i in 0..<(grid * grid) {
            if a.fg[i] && b.fg[i] {
                inter += 1
                dc += (pow(a.color[i].0 - b.color[i].0, 2) + pow(a.color[i].1 - b.color[i].1, 2)
                     + pow(a.color[i].2 - b.color[i].2, 2)).squareRoot() / 441.7
                nc += 1
            }
            if a.fg[i] || b.fg[i] { uni += 1 }
        }
        let sil = uni == 0 ? 0 : Double(inter) / Double(uni)
        let colorDist = nc == 0 ? 1 : dc / Double(nc)
        return 1.0 * colorDist + 1.2 * (1 - sil)
    }

    /// Type-constrained candidates: the predicted pair always seeds the set;
    /// low-margin slots WIDEN it (never discard the prediction). type1 == nil
    /// with a type2 read ⇒ mono-type (structural).
    func candidates(t1: TypeRead?, t2: TypeRead?) -> [SpeciesRef] {
        var names = Set<String>()
        if t1 == nil, let t2 {
            for s in species where s.types == [t2.type] { names.insert(s.name) }
            if t2.margin < 0.05 { for s in species where s.types.count == 1 { names.insert(s.name) } }
        } else if let t1, let t2 {
            for s in species where s.types == Set([t1.type, t2.type]) { names.insert(s.name) }
            if t1.margin < 0.05 {
                for s in species where s.types.contains(t2.type) && s.types.count == 2 { names.insert(s.name) }
            }
            if t2.margin < 0.05 {
                for s in species where s.types.contains(t1.type) && s.types.count == 2 { names.insert(s.name) }
            }
        } else if let only = t1 ?? t2 {
            for s in species where s.types.contains(only.type) { names.insert(s.name) }
        } else {
            names = Set(species.map(\.name))
        }
        return species.filter { names.contains($0.name) }
    }

    /// Rank fusion over the references → top-3 + candidate count.
    /// Pixel-sheet poses and dex-render palettes vote by Borda; the native
    /// tier (same art as the query) also votes — and OVERRIDES outright on a
    /// calibrated same-art match (distance < 0.30 with ≥0.15 margin over the
    /// nearest other species; cross-species floor measured at 0.45).
    public func identify(sprite: CGImage, t1: TypeRead?, t2: TypeRead?) -> (top: [SpeciesCandidate], candidateCount: Int)? {
        guard let buf = RGBABuffer(sprite),
              let feat = Self.feature(buf: buf, useAlpha: false) else { return nil }
        let cands = candidates(t1: t1, t2: t2)
        var pixelScored: [(String, Double)] = [], dexScored: [(String, Double)] = []
        var nativeScored: [(String, Double)] = []
        for s in cands {
            if let pf = pixelFeatures[s.name] { pixelScored.append((s.name, Self.matchScore(feat, pf))) }
            if let df = dexFeatures[s.name] { dexScored.append((s.name, Self.matchScore(feat, df))) }
            if let refs = nativeFeatures[s.name] {
                let usable = refs.filter { $0.source != evalExcludeNativeSource }
                if let best = usable.map({ Self.matchScore(feat, $0.feature) }).min() {
                    nativeScored.append((s.name, best))
                }
            }
        }
        pixelScored.sort { $0.1 < $1.1 }
        dexScored.sort { $0.1 < $1.1 }
        nativeScored.sort { $0.1 < $1.1 }
        var rank: [String: Double] = [:]
        for (i, e) in pixelScored.enumerated() { rank[e.0, default: 0] += Double(i) }
        for (i, e) in dexScored.enumerated() { rank[e.0, default: 0] += Double(i) }
        for (i, e) in nativeScored.enumerated() { rank[e.0, default: 0] += Double(i) }
        for s in cands {
            if !pixelScored.contains(where: { $0.0 == s.name }) { rank[s.name, default: 0] += Double(pixelScored.count) }
            if !dexScored.contains(where: { $0.0 == s.name }) { rank[s.name, default: 0] += Double(dexScored.count) }
            // Native absence is NOT penalized: most species have no banked
            // crops yet, and that must never count against them.
        }
        let byName = Dictionary(uniqueKeysWithValues: cands.map { ($0.name, $0) })
        let fused = rank.sorted { ($0.value, $0.key) < ($1.value, $1.key) }
        var top = fused.prefix(3).compactMap { e in
            byName[e.key].map { SpeciesCandidate(name: $0.name, num: $0.num, fusedRank: e.value) }
        }

        // Same-art decisive override.
        if let best = nativeScored.first, best.1 < Self.nativeDecisiveDistance {
            let runnerUp = nativeScored.dropFirst().first?.1 ?? .infinity
            if runnerUp - best.1 >= Self.nativeDecisiveMargin, top.first?.name != best.0,
               let ref = byName[best.0] {
                top.removeAll { $0.name == best.0 }
                top.insert(SpeciesCandidate(name: ref.name, num: ref.num, fusedRank: -1), at: 0)
                top = Array(top.prefix(3))
            }
        }
        return (top, cands.count)
    }
}

// MARK: - Orchestrator

nonisolated public struct PreviewRowRead: Sendable {
    public let row: Int
    public let plateNorm: CGRect          // normalized to the frame
    public let type1: TypeRead?           // nil = empty slot
    public let type2: TypeRead?
    public let speciesTop: [SpeciesCandidate]
    public let candidateCount: Int
    public let gender: String             // male | female | unknown
    public let spriteCrop: CGImage
}

nonisolated public struct PreviewRead: Sendable {
    public let layoutSubmitted: Bool
    public let rows: [PreviewRowRead]
}

nonisolated public final class PreviewPipeline {
    public let typeCore: TypeIconCore
    public let speciesCore: SpeciesCore

    public init(typeCore: TypeIconCore, speciesCore: SpeciesCore) {
        self.typeCore = typeCore
        self.speciesCore = speciesCore
    }

    /// Load from the app bundle's Resources/PreviewPipeline copies.
    /// `nativeOverlayJSON`: the live confirm-tap overlay (app passes
    /// NativeReferenceStore.overlayData(); kept as a parameter so diagnostics
    /// builds of this file need no app-only symbols).
    public static func bundled(nativeOverlayJSON: Data? = nil) throws -> PreviewPipeline {
        func data(_ name: String, _ ext: String) throws -> Data {
            guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
                throw NSError(domain: "PreviewPipeline", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "missing bundled resource \(name).\(ext)"])
            }
            return try Data(contentsOf: url)
        }
        guard let sheetSrc = CGImageSourceCreateWithData(try data("pokemonicons-sheet", "png") as CFData, nil),
              let sheet = CGImageSourceCreateImageAtIndex(sheetSrc, 0, nil) else {
            throw NSError(domain: "PreviewPipeline", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "bad icon sheet"])
        }
        return PreviewPipeline(
            typeCore: try TypeIconCore(templatesJSON: try data("templates", "json")),
            speciesCore: try SpeciesCore(indexJSON: try data("species-index", "json"),
                                         sheet: sheet,
                                         dexFeaturesJSON: try? data("dex-features", "json"),
                                         nativeFeaturesJSON: try? data("native-features", "json"),
                                         nativeOverlayJSON: nativeOverlayJSON)
        )
    }

    /// The matcher's closed species vocabulary — just the names from the
    /// bundled index, alphabetized, for UI pickers (BACKLOG P1: any species
    /// can be pinned even when the voted top-3 misses). Cheap: decodes the
    /// index JSON only — no icon sheet, no feature tables. Empty outside
    /// the app bundle (diagnostics CLIs never call this).
    public static func bundledSpeciesNames() -> [String] {
        guard let url = Bundle.module.url(forResource: "species-index", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let idx = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return idx.compactMap { $0["name"] as? String }.sorted()
    }

    /// Read one full-resolution team-preview frame. Returns nil when no
    /// opponent column is found (mid-fade frames, wrong screen).
    public func read(frame: CGImage) -> PreviewRead? {
        guard let buf = RGBABuffer(frame),
              let (layoutSubmitted, geos) = TeamPreviewRowDetector.detectRows(in: buf) else { return nil }

        var rows: [PreviewRowRead] = []
        for g in geos {
            guard let spriteCrop = frame.cropping(to: g.sprite) else { continue }
            let t1 = frame.cropping(to: g.type1).flatMap { typeCore.classify(slot: $0) }
            let t2 = frame.cropping(to: g.type2).flatMap { typeCore.classify(slot: $0) }
            let id = speciesCore.identify(sprite: spriteCrop, t1: t1, t2: t2)
            rows.append(PreviewRowRead(
                row: g.row,
                plateNorm: CGRect(x: g.plate.minX / CGFloat(buf.width),
                                  y: g.plate.minY / CGFloat(buf.height),
                                  width: g.plate.width / CGFloat(buf.width),
                                  height: g.plate.height / CGFloat(buf.height)),
                type1: t1, type2: t2,
                speciesTop: id?.top ?? [], candidateCount: id?.candidateCount ?? 0,
                gender: Self.genderGuess(frame: frame, box: g.gender),
                spriteCrop: spriteCrop
            ))
        }
        guard !rows.isEmpty else { return nil }
        return PreviewRead(layoutSubmitted: layoutSubmitted, rows: rows)
    }

    /// Blue/red dominance with laser-safe thresholds (port of the reader's guess).
    static func genderGuess(frame: CGImage, box: CGRect) -> String {
        guard let crop = frame.cropping(to: box), let buf = RGBABuffer(crop) else { return "unknown" }
        var blue = 0, red = 0
        let px = buf.pixels
        for i in stride(from: 0, to: buf.width * buf.height * 4, by: 4) {
            let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
            if b >= 170 && (b - r) >= 70 && g <= 170 { blue += 1 }
            if r >= 190 && g <= 90 && b <= 105 && (r - g) >= 110 && (r - b) >= 90 { red += 1 }
        }
        return blue > red * 2 ? "male" : (red > blue * 2 ? "female" : "unknown")
    }
}

// MARK: - Frame voting

/// Accumulates preview reads across a preview's lifetime; row index = identity
/// (the roster order is stable across the pre-submit/submitted layout change).
nonisolated public struct PreviewAggregate: Sendable {
    public struct RowConsensus: Sendable {
        public let row: Int
        public let typePair: [String]         // 1 element = mono-type
        public let typeStability: Double      // winning votes / frames seen
        public let speciesTop: [(name: String, votes: Double)]
        public let gender: String
        public let framesSeen: Int
    }

    private var typeVotes: [Int: [String: Double]] = [:]     // row → "t1|t2" → weight
    private var speciesVotes: [Int: [String: Double]] = [:]  // row → name → Borda points
    private var genderVotes: [Int: [String: Int]] = [:]
    private var frames: [Int: Int] = [:]
    public private(set) var frameCount = 0

    public init() {}

    public mutating func add(_ read: PreviewRead) {
        frameCount += 1
        for r in read.rows {
            frames[r.row, default: 0] += 1
            let pair = [r.type1?.type, r.type2?.type].compactMap { $0 }.sorted().joined(separator: "|")
            if !pair.isEmpty {
                // Weight a frame's vote by its weakest margin (laser-degraded
                // reads count less), floored so every sighting counts a little.
                let weight = max(0.15, min(r.type1?.margin ?? 1, r.type2?.margin ?? 1) * 10)
                typeVotes[r.row, default: [:]][pair, default: 0] += weight
            }
            for (i, c) in r.speciesTop.enumerated() {
                speciesVotes[r.row, default: [:]][c.name, default: 0] += [3.0, 2.0, 1.0][i]
            }
            if r.gender != "unknown" {
                genderVotes[r.row, default: [:]][r.gender, default: 0] += 1
            }
        }
    }

    public var consensus: [RowConsensus] {
        frames.keys.sorted().map { row in
            let tv = typeVotes[row] ?? [:]
            let winner = tv.max { $0.value < $1.value }
            let totalW = tv.values.reduce(0, +)
            let sv = (speciesVotes[row] ?? [:]).sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            let gv = genderVotes[row] ?? [:]
            return RowConsensus(
                row: row,
                typePair: winner.map { $0.key.split(separator: "|").map(String.init) } ?? [],
                typeStability: totalW > 0 ? (winner?.value ?? 0) / totalW : 0,
                speciesTop: sv.prefix(3).map { ($0.key, $0.value) },
                gender: gv.max { $0.value < $1.value }?.key ?? "unknown",
                framesSeen: frames[row] ?? 0
            )
        }
    }
}
