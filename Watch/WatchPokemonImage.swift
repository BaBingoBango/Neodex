import CoreGraphics
import NeodexKit
import SwiftUI
import UIKit

/// A Pokémon's thumbnail from the watch bundle (`thumbs/<id>-thumb.heic`), decoded off the main thread
/// and kept in a small cache so lists scroll without re-decoding.
struct WatchPokemonImage: View {
    var pokemon: Pokemon
    /// Draws the shape only, for Who's That Pokémon?.
    var silhouette = false

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                if silhouette {
                    Image(uiImage: image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.black.opacity(0.85))
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            } else {
                Color.clear
            }
        }
        .task(id: pokemon.imageID) {
            image = await WatchImageCache.shared.thumbnail(for: pokemon.imageID)
        }
    }
}

/// Decodes and remembers thumbnails.
@MainActor
final class WatchImageCache {
    static let shared = WatchImageCache()

    private let cache = NSCache<NSString, UIImage>()

    func thumbnail(for imageID: String) async -> UIImage? {
        if let cached = cache.object(forKey: imageID as NSString) { return cached }
        let url = Bundle.main.url(forResource: "\(imageID)-thumb", withExtension: "heic", subdirectory: "thumbs")
            ?? Bundle.main.url(forResource: "\(imageID)-thumb", withExtension: "heic")
        guard let url else { return nil }
        let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            // Force the decode now, off the main thread, by drawing into a bitmap once.
            guard let cgImage = image.cgImage, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: nil, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            return context.makeImage().map { UIImage(cgImage: $0, scale: image.scale, orientation: .up) } ?? image
        }.value
        if let decoded { cache.setObject(decoded, forKey: imageID as NSString) }
        return decoded
    }
}
