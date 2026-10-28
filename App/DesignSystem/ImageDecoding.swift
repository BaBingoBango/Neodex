import CoreGraphics
import Foundation
import ImageIO

/// Bundled and downloaded images are decoded to plain-bitmap `CGImage`s, which both platforms draw and
/// which cross actors freely. Decoding happens at creation, off the main thread, so views never pay for
/// it while scrolling.
///
/// The bitmap step matters. An image straight out of ImageIO, even with `kCGImageSourceShouldCacheImmediately`,
/// keeps ImageIO as its data provider, so Core Animation calls back into ImageIO when it renders it.
/// With a decode running on another thread at the same moment, the two deadlock inside ImageIO, freezing
/// the app (seen in the iOS 27 simulator on Home). Drawing each image into a `CGContext` once leaves
/// Core Animation plain memory to read.
extension CGImage {
    /// Decodes the first image in `data` into a ready-to-draw bitmap.
    nonisolated static func decoded(_ data: Data) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap(decodedFirstImage)
    }

    /// Decodes the image file at `url` into a ready-to-draw bitmap.
    nonisolated static func decoded(contentsOf url: URL) -> CGImage? {
        CGImageSourceCreateWithURL(url as CFURL, nil).flatMap(decodedFirstImage)
    }

    /// The EXIF orientation recorded in `data`; `.up` when there is none.
    nonisolated static func orientation(of data: Data) -> CGImagePropertyOrientation {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let raw = properties[kCGImagePropertyOrientation] as? UInt32 else { return .up }
        return CGImagePropertyOrientation(rawValue: raw) ?? .up
    }

    /// This image redrawn into a plain bitmap in its own colour space (sRGB when that can't back a
    /// bitmap), or itself when no context can be made.
    nonisolated func renderedBitmap() -> CGImage {
        guard width > 0, height > 0 else { return self }
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)
        let spaces = [colorSpace.flatMap { $0.model == .rgb ? $0 : nil }, sRGB].compactMap(\.self)
        for space in spaces {
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { continue }
            context.interpolationQuality = .high
            context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
            if let image = context.makeImage() { return image }
        }
        return self
    }

    private nonisolated static func decodedFirstImage(_ source: CGImageSource) -> CGImage? {
        // No ImageIO caching: the bitmap below is the only decoded copy.
        CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary)?.renderedBitmap()
    }
}

/// Where decoding happens: a few threads of its own rather than Swift's cooperative pool. A decode is
/// synchronous work, and HEIC decodes can stall (the simulator's software HEVC decoder does under
/// load); run on the cooperative pool, a handful of them blocks every thread Swift concurrency has and
/// starves unrelated work such as network requests. Three at a time keeps grids filling quickly.
nonisolated enum ImageDecoder {
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Neodex.ImageDecoder"
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .userInitiated
        return queue
    }()

    static func decode(contentsOf url: URL) async -> CGImage? {
        await withCheckedContinuation { continuation in
            queue.addOperation { continuation.resume(returning: CGImage.decoded(contentsOf: url)) }
        }
    }

    static func decode(_ data: Data) async -> CGImage? {
        await withCheckedContinuation { continuation in
            queue.addOperation { continuation.resume(returning: CGImage.decoded(data)) }
        }
    }
}
