import Foundation
import Vision
import AppKit
import CoreImage
import ImageIO

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

// MARK: - Config
let repoRoot = FileManager.default.currentDirectoryPath
let scanDir  = "\(scopeLensFixturesRoot)/screenshots"
let iconsOut = "\(scopeLensFixturesRoot)/icons"
let dumpPath = "\(repoRoot)/ocr-dump.txt"
let languages = ["en-US","ja","ko","zh-Hans","zh-Hant","fr-FR","de-DE","es-ES","it-IT"]
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsOut, withIntermediateDirectories: true)

func err(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

// MARK: - Fixtures
func collectFixtures() -> [String] {
    var out: [String] = []
    let exts: Set<String> = ["heic","png","jpg","jpeg"]
    if let en = fm.enumerator(atPath: scanDir) {
        for case let rel as String in en where exts.contains((rel as NSString).pathExtension.lowercased()) {
            out.append("\(scanDir)/\(rel)")
        }
    }
    return out.sorted()
}

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

// MARK: - Script classification
func scriptTag(_ s: String) -> String {
    var found = Set<String>()
    for u in s.unicodeScalars {
        switch u.value {
        case 0x3040...0x309F:                       found.insert("Hiragana")
        case 0x30A0...0x30FF, 0x31F0...0x31FF, 0xFF66...0xFF9D: found.insert("Katakana")
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF: found.insert("Han")
        case 0x1100...0x11FF, 0x3130...0x318F, 0xAC00...0xD7A3: found.insert("Hangul")
        case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F, 0x1E00...0x1EFF: found.insert("Latin")
        default: break
        }
    }
    if found.isEmpty { return "Other" }
    if found.count == 1 { return found.first! }
    return "Mixed"
}

// MARK: - OCR
func ocr(_ cg: CGImage) -> [(String, Float, CGRect)] {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = false
    req.recognitionLanguages = languages
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    do { try handler.perform([req]) } catch { err("  OCR error: \(error)"); return [] }
    return (req.results ?? []).compactMap { obs in
        guard let c = obs.topCandidates(1).first else { return nil }
        return (c.string, c.confidence, obs.boundingBox)   // boundingBox: normalized, origin BOTTOM-left
    }
}

// MARK: - Pixel buffer (row 0 = TOP)
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

// HP-fill color signature (green / yellow / red gradient)
@inline(__always) func isHP(_ r: Int, _ g: Int, _ b: Int) -> Bool {
    let green  = g >= 150 && g - b >= 45 && g - r >= -25 && b <= 140 && r <= 215
    let yellow = r >= 195 && g >= 165 && b <= 100 && abs(r - g) <= 65
    let red    = r >= 175 && g <= 105 && b <= 105
    return green || yellow || red
}

struct Bar { var x0: Int; var x1: Int; var y0: Int; var y1: Int
    var w: Int { x1 - x0 }; var h: Int { y1 - y0 } }

func detectBars(_ buf: [UInt8], _ w: Int, _ h: Int) -> [Bar] {
    let minRun = Int(0.05 * Double(w))
    // open components carried from previous row
    var open: [Bar] = []
    var closed: [Bar] = []
    for y in 0..<h {
        // find long HP runs in this row
        var runs: [(Int, Int)] = []
        var runStart = -1
        let base = y * w * 4
        for x in 0..<w {
            let i = base + x * 4
            let hit = isHP(Int(buf[i]), Int(buf[i+1]), Int(buf[i+2]))
            if hit && runStart < 0 { runStart = x }
            if (!hit || x == w - 1) && runStart >= 0 {
                let end = hit ? x : x - 1
                if end - runStart + 1 >= minRun { runs.append((runStart, end)) }
                runStart = -1
            }
        }
        var nextOpen: [Bar] = []
        var used = [Bool](repeating: false, count: open.count)
        for (rs, re) in runs {
            // merge into an open component that overlaps in x and was active last row
            var merged = false
            for idx in 0..<open.count where !used[idx] {
                var b = open[idx]
                if b.y1 == y - 1 && rs <= b.x1 && re >= b.x0 {
                    b.x0 = min(b.x0, rs); b.x1 = max(b.x1, re); b.y1 = y
                    nextOpen.append(b); used[idx] = true; merged = true; break
                }
            }
            if !merged { nextOpen.append(Bar(x0: rs, x1: re, y0: y, y1: y)) }
        }
        // components that were not extended are closed
        for (idx, b) in open.enumerated() where !used[idx] { closed.append(b) }
        open = nextOpen
    }
    closed.append(contentsOf: open)
    // shape filter: thin, wide, horizontal
    let minH = Int(0.004 * Double(h)), maxH = Int(0.05 * Double(h))
    let minW = Int(0.06 * Double(w))
    return closed.filter { $0.h >= minH && $0.h <= maxH && $0.w >= minW && Double($0.w) / Double(max($0.h,1)) >= 5.0 }
                 .sorted { $0.w > $1.w }
}

func savePNG(_ cg: CGImage, _ path: String) -> Bool {
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    do { try data.write(to: URL(fileURLWithPath: path)); return true } catch { return false }
}

// MARK: - Run
let fixtures = collectFixtures()
err("Found \(fixtures.count) fixtures")

var dump = ""
dump += "# ScopeLens OCR dump\n"
dump += "# Vision VNRecognizeTextRequest | level .accurate | usesLanguageCorrection false\n"
dump += "# recognitionLanguages: \(languages.joined(separator: ", "))\n"
dump += "# columns: string | confidence | script | center(x,y) | size(w,h)\n"
dump += "# coordinates normalized 0-1, ORIGIN TOP-LEFT (y increases downward); sorted reading order (center-y, then center-x)\n"
dump += "# scripts: Latin / Hiragana / Katakana / Han / Hangul / Mixed / Other\n\n"

for path in fixtures {
    let rel = path.replacingOccurrences(of: scanDir + "/", with: "")
    guard let cg = loadImage(path) else { err("!! could not load \(rel)"); continue }
    let W = cg.width, H = cg.height
    let aspect = Double(W) / Double(H)

    // --- OCR ---
    var toks = ocr(cg).map { (s, c, box) -> (String, Float, String, Double, Double, Double, Double) in
        let cx = Double(box.midX)
        let cy = 1.0 - Double(box.midY)          // -> top-left origin
        return (s, c, scriptTag(s), cx, cy, Double(box.width), Double(box.height))
    }
    toks.sort { ($0.4, $0.3) < ($1.4, $1.3) }     // center-y then center-x

    dump += "### \(rel)\n"
    dump += String(format: "# %dx%d  aspect %.3f  tokens %d\n", W, H, aspect, toks.count)
    for t in toks {
        dump += String(format: "%@ | %.2f | %@ | (%.3f, %.3f) | (%.3f, %.3f)\n",
                       t.0, t.1, t.2, t.3, t.4, t.5, t.6)
    }

    // --- HP bars + icon crops ---
    var iconNote = ""
    if let (buf, w, h) = rgbaTopLeft(cg) {
        let bars = Array(detectBars(buf, w, h).prefix(8))
        iconNote = "  [\(bars.count) HP-bar candidate(s)]"
        for (n, b) in bars.enumerated() {
            // Geometry annotation only; icon crops are produced by IconIsolation.swift.
            dump += String(format: "# HP-bar[%d] center(%.3f, %.3f) size(%.3f, %.3f)\n",
                           n,
                           Double(b.x0 + b.x1) / 2.0 / Double(w),
                           Double(b.y0 + b.y1) / 2.0 / Double(h),
                           Double(b.w) / Double(w), Double(b.h) / Double(h))
        }
    }
    dump += "\n"
    err("• \(rel): \(toks.count) tokens\(iconNote)")
}

do {
    try dump.write(toFile: dumpPath, atomically: true, encoding: .utf8)
    err("Wrote \(dumpPath) (\(dump.count) chars)")
} catch { err("!! failed to write dump: \(error)") }

// also echo to stdout
print(dump)
