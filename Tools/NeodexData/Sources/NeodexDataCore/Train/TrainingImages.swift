import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// Image helpers for the recogniser's training set: GIF frames, card crops, SVG rasters and composites.
enum TrainingImages {
    /// Up to `count` evenly spaced frames of an animated GIF.
    static func frames(fromGIF data: Data, count: Int) -> [CGImage] {
        guard count > 0, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return [] }
        let total = CGImageSourceGetCount(source)
        guard total > 0 else { return [] }
        let wanted = min(count, total)
        return (0..<wanted).compactMap { CGImageSourceCreateImageAtIndex(source, total * $0 / wanted, nil) }
    }

    /// Pixel art and animated-sprite frames can be under 40 px; Create ML's crop augmentation chokes on
    /// those, so small images are blown up with nearest-neighbour sampling to keep the pixels crisp.
    static func upscaled(_ image: CGImage, minimumDimension: Int) -> CGImage {
        let shortest = min(image.width, image.height)
        guard shortest > 0, shortest < minimumDimension else { return image }
        let factor = Int((Double(minimumDimension) / Double(shortest)).rounded(.up))
        let width = image.width * factor
        let height = image.height * factor
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

    /// Centres an image on a transparent square canvas, scaled to fit, so every frame shares one size.
    /// Small pixel art is enlarged with nearest-neighbour sampling; larger images are shrunk smoothly.
    static func normalized(_ image: CGImage, canvas: Int) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        let scale = Double(canvas) * 0.92 / Double(longest)
        context.interpolationQuality = scale > 1 ? .none : .high
        let width = Double(image.width) * scale
        let height = Double(image.height) * scale
        context.draw(image, in: CGRect(x: (Double(canvas) - width) / 2, y: (Double(canvas) - height) / 2, width: width, height: height))
        return context.makeImage() ?? image
    }

    /// The illustration window of a trading card: roughly the band below the name line.
    static func cardArt(_ card: CGImage) -> CGImage? {
        let top = Int(Double(card.height) * 0.08)
        let height = Int(Double(card.height) * 0.44)
        return card.cropping(to: CGRect(x: 0, y: top, width: card.width, height: height))
    }

    /// Rasterises an SVG (AppKit renders it) into a square bitmap, aspect-fitted and centred.
    @MainActor
    static func rasterize(svg data: Data, size: Int) -> CGImage? {
        guard let image = NSImage(data: data), image.isValid, image.size.width > 0, image.size.height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        let natural = image.size
        let scale = min(CGFloat(size) / natural.width, CGFloat(size) / natural.height)
        let drawn = NSSize(width: natural.width * scale, height: natural.height * scale)
        let origin = NSPoint(x: (CGFloat(size) - drawn.width) / 2, y: (CGFloat(size) - drawn.height) / 2)
        image.draw(in: NSRect(origin: origin, size: drawn), from: .zero, operation: .sourceOver, fraction: 1)
        context.flushGraphics()
        return rep.cgImage
    }

    /// Pastes a cut-out (artwork or sprite with transparency) onto a procedurally generated background,
    /// with a random size, position, rotation and tint, so the classifier sees Pokémon in cluttered scenes.
    static func composite(_ subject: CGImage, size: Int, generator: inout SeededGenerator) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        let canvas = CGRect(x: 0, y: 0, width: size, height: size)
        let side = CGFloat(size)

        // Background: a two-colour gradient under a scattering of soft shapes.
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [randomColor(&generator), randomColor(&generator)] as CFArray, locations: [0, 1]) {
            let start = CGPoint(x: 0, y: CGFloat.random(in: 0...side, using: &generator))
            let end = CGPoint(x: side, y: CGFloat.random(in: 0...side, using: &generator))
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else {
            context.setFillColor(randomColor(&generator))
            context.fill(canvas)
        }
        for _ in 0..<Int.random(in: 6...18, using: &generator) {
            let color = randomColor(&generator).copy(alpha: CGFloat.random(in: 0.12...0.45, using: &generator)) ?? randomColor(&generator)
            context.setFillColor(color)
            let extent = CGFloat.random(in: side * 0.08...side * 0.6, using: &generator)
            let rect = CGRect(x: CGFloat.random(in: -extent / 2...side - extent / 2, using: &generator),
                              y: CGFloat.random(in: -extent / 2...side - extent / 2, using: &generator),
                              width: extent, height: extent * CGFloat.random(in: 0.4...1.6, using: &generator))
            if Bool.random(using: &generator) { context.fillEllipse(in: rect) } else { context.fill(rect) }
        }

        // Subject: scaled to 45–90% of the canvas, nudged off centre, slightly rotated, sometimes mirrored.
        let longest = CGFloat(max(subject.width, subject.height))
        let scale = side * CGFloat.random(in: 0.45...0.9, using: &generator) / longest
        let width = CGFloat(subject.width) * scale
        let height = CGFloat(subject.height) * scale
        let centerX = CGFloat.random(in: width / 2 * 0.8...side - width / 2 * 0.8, using: &generator)
        let centerY = CGFloat.random(in: height / 2 * 0.8...side - height / 2 * 0.8, using: &generator)
        context.saveGState()
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: CGFloat.random(in: -0.45...0.45, using: &generator))
        if Bool.random(using: &generator) { context.scaleBy(x: -1, y: 1) }
        context.draw(subject, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        context.restoreGState()

        // A faint colour cast, like uneven room lighting.
        if let cast = randomColor(&generator).copy(alpha: CGFloat.random(in: 0...0.14, using: &generator)) {
            context.setFillColor(cast)
            context.fill(canvas)
        }
        return context.makeImage()
    }

    private static func randomColor(_ generator: inout SeededGenerator) -> CGColor {
        CGColor(red: CGFloat.random(in: 0...1, using: &generator), green: CGFloat.random(in: 0...1, using: &generator),
                blue: CGFloat.random(in: 0...1, using: &generator), alpha: 1)
    }
}

/// A small deterministic generator (SplitMix64) so every run composes the same synthetic images.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    init(string: String) {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        self.init(seed: hash)
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
