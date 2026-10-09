import NeodexKit
import SwiftUI
import UIKit

/// Which bundled image of a Pokémon to show.
enum PokemonImageKind: String {
    /// 400px official artwork (`-art.heic`).
    case artwork = "art"
    /// 120px artwork thumbnail (`-thumb.heic`).
    case thumbnail = "thumb"
    /// 96px Showdown battle sprite (`-sprite.png`).
    case sprite

    var fileExtension: String { self == .sprite ? "png" : "heic" }
}

/// Loads bundled Pokémon and item images, decoding them off the main actor and caching the result.
@MainActor
final class BundledImageStore {
    static let shared = BundledImageStore()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [NSString: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 800
    }

    /// An already-decoded image, if one is cached.
    func cachedPokemonImage(_ imageID: String, kind: PokemonImageKind) -> UIImage? {
        cache.object(forKey: key(imageID, kind))
    }

    /// Loads and decodes a Pokémon image. Concurrent requests for the same image share one decode.
    func pokemonImage(_ imageID: String, kind: PokemonImageKind) async -> UIImage? {
        let key = key(imageID, kind)
        if let cached = cache.object(forKey: key) { return cached }
        if let task = inFlight[key] { return await task.value }
        guard let url = Bundle.main.url(forResource: "\(imageID)-\(kind.rawValue)", withExtension: kind.fileExtension) else { return nil }
        let task = Task { await Self.decode(url) }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    /// Item icons are tiny PNGs; decoding them inline is fine.
    func itemImage(_ itemID: String) -> UIImage? {
        let key = "\(itemID)-item.png" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let url = Bundle.main.url(forResource: "\(itemID)-item", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    private func key(_ imageID: String, _ kind: PokemonImageKind) -> NSString {
        "\(imageID)-\(kind.rawValue).\(kind.fileExtension)" as NSString
    }

    @concurrent
    nonisolated private static func decode(_ url: URL) async -> UIImage? {
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        return await image.byPreparingForDisplay() ?? image
    }
}

/// Displays a Pokémon's artwork, thumbnail or sprite, with a placeholder when missing.
struct PokemonImage: View {
    var pokemon: Pokemon
    var kind: PokemonImageKind = .artwork

    @State private var loaded: UIImage?
    @State private var failed = false

    private var image: UIImage? {
        loaded ?? BundledImageStore.shared.cachedPokemonImage(pokemon.imageID, kind: kind)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(kind == .sprite ? .none : .high)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(pokemon.displayName)
            } else if failed {
                Image(systemName: "questionmark.circle.dashed")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.tertiary)
                    .padding(8)
                    .accessibilityLabel("No image for \(pokemon.displayName)")
            } else {
                Color.clear
                    .accessibilityLabel(pokemon.displayName)
            }
        }
        .task(id: "\(pokemon.imageID)-\(kind.rawValue)") {
            // Another view may have finished decoding this image between this view's first render
            // and its task starting; always publish what the store has, or the view stays blank.
            if let cached = BundledImageStore.shared.cachedPokemonImage(pokemon.imageID, kind: kind) {
                loaded = cached
                return
            }
            let result = await BundledImageStore.shared.pokemonImage(pokemon.imageID, kind: kind)
            if !Task.isCancelled {
                loaded = result
                failed = result == nil
            }
        }
    }
}

/// Displays an item's icon from Showdown's sprite sheet.
struct ItemImage: View {
    var item: Item

    var body: some View {
        if let image = BundledImageStore.shared.itemImage(item.id) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(item.name)
        } else {
            Image(systemName: "cube.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.tertiary)
                .accessibilityLabel(item.name)
        }
    }
}
