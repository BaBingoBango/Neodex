import Foundation
import Vision
import AppKit
import CoreImage
import ImageIO

/// Real Champions fixtures live in the private Scope Lens checkout; SCOPELENS_FIXTURES points at them.
let scopeLensFixturesRoot = ProcessInfo.processInfo.environment["SCOPELENS_FIXTURES"] ?? FileManager.default.currentDirectoryPath + "/Fixtures"

let repoRoot = FileManager.default.currentDirectoryPath
let scanDir  = "\(scopeLensFixturesRoot)/screenshots"
let iconsOut = "\(scopeLensFixturesRoot)/icons"
let languages = ["en-US","ja","ko","zh-Hans","zh-Hant","fr-FR","de-DE","es-ES","it-IT"]
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
func ocr(_ cg: CGImage) -> [(String, Double, Double)] {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = false
    req.recognitionLanguages = languages
    let h = VNImageRequestHandler(cgImage: cg, options: [:])
    do { try h.perform([req]) } catch { return [] }
    return (req.results ?? []).compactMap { o in
        guard let c = o.topCandidates(1).first else { return nil }
        return (c.string, Double(o.boundingBox.midX), 1.0 - Double(o.boundingBox.midY)) // top-left
    }
}
func savePNG(_ cg: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: cg)
    if let d = rep.representation(using: .png, properties: [:]) { try? d.write(to: URL(fileURLWithPath: path)) }
}
func digits(_ s: String) -> Int { s.filter { $0.isNumber }.count }
func hasLetter(_ s: String) -> Bool { s.contains { $0.isLetter } }

let exts: Set<String> = ["heic","png","jpg","jpeg"]
var fixtures: [String] = []
if let en = fm.enumerator(atPath: scanDir) {
    for case let rel as String in en where exts.contains((rel as NSString).pathExtension.lowercased()) {
        fixtures.append("\(scanDir)/\(rel)")
    }
}
fixtures.sort()

// icon = square of side S(frac of H), centered at anchor + (dx,dy) in normalized units
func crop(_ cg: CGImage, _ W: Int, _ H: Int, _ cxN: Double, _ cyN: Double, _ sideFracH: Double, _ out: String) {
    let s = Int(sideFracH * Double(H))
    var ox = Int(cxN * Double(W)) - s/2
    var oy = Int(cyN * Double(H)) - s/2
    ox = max(0, min(ox, W - s)); oy = max(0, min(oy, H - s))
    if let c = cg.cropping(to: CGRect(x: ox, y: oy, width: s, height: s)) { savePNG(c, out) }
}

for path in fixtures {
    let rel = path.replacingOccurrences(of: scanDir + "/", with: "")
    guard let cg = loadImage(path) else { continue }
    let W = cg.width, H = cg.height
    let stem = ((rel as NSString).lastPathComponent as NSString).deletingPathExtension.replacingOccurrences(of: " ", with: "_")
    let toks = ocr(cg)

    // Opponent: anchor on "%" tokens in the top band. Icon sits left + slightly up.
    let opp = toks.filter { $0.0.contains("%") && $0.2 < 0.30 }.sorted { $0.1 < $1.1 }
    for (i, t) in opp.enumerated() {
        crop(cg, W, H, t.1 - 0.115, t.2 - 0.045, 0.11, "\(iconsOut)/\(stem)_opp\(i).png")
    }
    // Mine: anchor on the plate NAME token (top row of my plate). Icon sits just left.
    // Gate on HUD presence (opponent % tokens) so team-preview/narration frames don't false-fire.
    let mine = opp.isEmpty ? [] :
        toks.filter { hasLetter($0.0) && $0.2 > 0.855 && $0.2 < 0.885 && $0.1 < 0.50 }.sorted { $0.1 < $1.1 }
    for (i, t) in mine.enumerated() {
        crop(cg, W, H, t.1 - 0.035, t.2 + 0.020, 0.13, "\(iconsOut)/\(stem)_mine\(i).png")
    }
    err("• \(rel): opp=\(opp.count) mine=\(mine.count)  [opp anchors: \(opp.map{ String(format:"%.3f",$0.1) }.joined(separator:","))]")
}
