import CoreGraphics
import Foundation
import ImageIO

/// Bundled and downloaded images are decoded with ImageIO straight to `CGImage`, which both
/// platforms draw and which crosses actors freely. Decoding happens at creation rather than at
/// first draw, so views never pay for it on the main thread.
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

    private nonisolated static func decodedFirstImage(_ source: CGImageSource) -> CGImage? {
        let options = [kCGImageSourceShouldCacheImmediately: true, kCGImageSourceShouldCache: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }
}
