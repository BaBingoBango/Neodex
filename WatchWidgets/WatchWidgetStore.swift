import CoreGraphics
import Foundation
import NeodexKit
import UIKit

/// What the complications read: the bundled species index, the thumbnails and the shared reveal state.
/// The extension carries its own copies, because an extension can't read its app's bundle.
nonisolated enum WatchWidgetStore {
    /// Every Pokémon, in dex order, from `pokemon-index.json`.
    static let index: [WidgetPokemon] = {
        guard let url = Bundle.main.url(forResource: "pokemon-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([WidgetPokemon].self, from: data)) ?? []
    }()

    /// Base forms only, the list the daily picks draw from (the same order the app uses).
    static var species: [WidgetPokemon] { index.filter(\.isSpecies) }

    /// The bundled thumbnail downsampled to 80 px: WidgetKit refuses to archive images above
    /// 80 pixels on a side in the small families and fails the whole placeholder batch when one is.
    static func thumbnail(_ imageID: String) -> UIImage? {
        let url = Bundle.main.url(forResource: "\(imageID)-thumb", withExtension: "heic", subdirectory: "thumbs")
            ?? Bundle.main.url(forResource: "\(imageID)-thumb", withExtension: "heic")
        guard let url, let image = UIImage(contentsOfFile: url.path), let cgImage = image.cgImage else { return nil }
        let side = 80
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        let scale = Double(side) / Double(max(cgImage.width, cgImage.height))
        let width = Double(cgImage.width) * scale
        let height = Double(cgImage.height) * scale
        context.draw(cgImage, in: CGRect(x: (Double(side) - width) / 2, y: (Double(side) - height) / 2, width: width, height: height))
        return context.makeImage().map { UIImage(cgImage: $0, scale: 2, orientation: .up) }
    }

    private static var defaults: UserDefaults { SharedContainer.defaults ?? .standard }

    static func isMysteryRevealed(on date: Date) -> Bool {
        defaults.integer(forKey: SharedContainer.DefaultsKey.mysteryRevealedDay) == DailyPick.dayOrdinal(for: date)
    }

    static func revealMystery(on date: Date = .now) {
        defaults.set(DailyPick.dayOrdinal(for: date), forKey: SharedContainer.DefaultsKey.mysteryRevealedDay)
    }
}
