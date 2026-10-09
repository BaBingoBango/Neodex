import ImageIO
import NeodexKit
import SwiftUI
import UIKit

/// A decoded GIF: its frames and how long each one shows.
nonisolated struct AnimatedImage: @unchecked Sendable {
    var frames: [CGImage]
    var durations: [TimeInterval]

    var totalDuration: TimeInterval { durations.reduce(0, +) }
    var size: CGSize { frames.first.map { CGSize(width: $0.width, height: $0.height) } ?? .zero }

    /// The frame to show `time` seconds into a looping playback.
    func frameIndex(at time: TimeInterval) -> Int {
        guard frames.count > 1, totalDuration > 0 else { return 0 }
        var remaining = time.truncatingRemainder(dividingBy: totalDuration)
        for (index, duration) in durations.enumerated() {
            remaining -= duration
            if remaining < 0 { return index }
        }
        return frames.count - 1
    }

    /// Decodes GIF data with ImageIO.
    static func decode(_ data: Data) -> AnimatedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        var frames: [CGImage] = []
        var durations: [TimeInterval] = []
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(image)
            durations.append(frameDuration(source, index))
        }
        guard !frames.isEmpty else { return nil }
        return AnimatedImage(frames: frames, durations: durations)
    }

    private static func frameDuration(_ source: CGImageSource, _ index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? TimeInterval
        let delay = unclamped ?? clamped ?? 0.1
        // Browsers show near-zero delays as 100 ms; match them so sprites don't blur.
        return delay < 0.011 ? 0.1 : delay
    }
}

/// What the sprite store found for a Pokémon.
nonisolated enum SpriteMedia: Sendable {
    case animated(AnimatedImage)
    case still(UIImage)
    case unavailable
}

/// Fetches and decodes Showdown's animated sprites, keeping decoded frames in memory.
@MainActor
final class SpriteMediaStore {
    static let shared = SpriteMediaStore()

    private var cache: [String: SpriteMedia] = [:]
    private var inFlight: [String: Task<SpriteMedia, Never>] = [:]

    func sprite(for pokemon: Pokemon, shiny: Bool) async -> SpriteMedia {
        let stem = pokemon.showdownSpriteID
        let key = "\(stem)|\(shiny)"
        if let cached = cache[key] { return cached }
        if let task = inFlight[key] { return await task.value }
        let task = Task { await Self.load(stem: stem, shiny: shiny) }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        cache[key] = result
        return result
    }

    @concurrent
    nonisolated private static func load(stem: String, shiny: Bool) async -> SpriteMedia {
        if let data = try? await MediaCache.shared.data(for: ShowdownMedia.animatedSprite(stem, shiny: shiny)),
           let image = AnimatedImage.decode(data) {
            return .animated(image)
        }
        if shiny, let data = try? await MediaCache.shared.data(for: ShowdownMedia.staticShinySprite(stem)),
           let image = UIImage(data: data) {
            return .still(image)
        }
        return .unavailable
    }
}

/// Showdown's animated battle sprite for a Pokémon, with the bundled still sprite as the stand-in
/// while it loads or when Showdown has no animation. Honours Reduce Motion by showing one frame.
struct AnimatedSpriteView: View {
    var pokemon: Pokemon
    var shiny: Bool = false
    var maxHeight: CGFloat = 200

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var media: SpriteMedia?

    var body: some View {
        Group {
            switch media {
            case .animated(let image):
                if image.frames.count > 1, !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        frame(image.frames[image.frameIndex(at: context.date.timeIntervalSinceReferenceDate)], size: image.size)
                    }
                } else {
                    frame(image.frames[0], size: image.size)
                }
            case .still(let image):
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: image.size.width * scale(for: image.size), height: image.size.height * scale(for: image.size))
            case .unavailable, nil:
                PokemonImage(pokemon: pokemon, kind: .sprite)
                    .frame(width: 96 * scale(for: CGSize(width: 96, height: 96)), height: 96 * scale(for: CGSize(width: 96, height: 96)))
                    .overlay {
                        if media == nil { ProgressView().tint(.white) }
                    }
            }
        }
        .accessibilityLabel(shiny ? "Shiny \(pokemon.displayName)" : pokemon.displayName)
        .task(id: "\(pokemon.id)|\(shiny)") {
            media = nil
            let loaded = await SpriteMediaStore.shared.sprite(for: pokemon, shiny: shiny)
            if !Task.isCancelled { media = loaded }
        }
    }

    private func scale(for size: CGSize) -> CGFloat {
        guard size.height > 0 else { return 2 }
        return min(2, maxHeight / size.height)
    }

    private func frame(_ cgImage: CGImage, size: CGSize) -> some View {
        Image(decorative: cgImage, scale: 1)
            .interpolation(.none)
            .resizable()
            .frame(width: size.width * scale(for: size), height: size.height * scale(for: size))
    }
}
