import Foundation
import NeodexKit
import Testing
import UIKit
@testable import Neodex

/// The camera scanner's recogniser, exercised against the bundled artwork and rendered text.
/// Vision's scene-print feature extractor can't run in the simulator ("Failed to create espresso
/// context"), so the model-backed tests only run on a device.
@Suite("Pokémon recogniser")
struct RecognizerTests {
    #if targetEnvironment(simulator)
    nonisolated static let canRunModel = false
    #else
    nonisolated static let canRunModel = PokemonRecognizer.isAvailable
    #endif

    @Test("Bundled artwork is recognised as the right Pokémon", .enabled(if: canRunModel),
          arguments: ["pikachu", "garchomp", "charizardmegax", "gengar", "kingambit"])
    func recognisesArtwork(id: String) async throws {
        let image = try #require(Self.bundledArtwork(id))
        let matches = try await PokemonRecognizer.shared.matches(in: image, limit: 3)
        #expect(matches.map(\.pokemonID).contains(id), "\(id) not in \(matches.map(\.pokemonID))")
    }

    @Test("Printed names are read off an image", .enabled(if: canRunModel))
    func readsNames() async throws {
        let database = try await DatabaseProvider.shared.database()
        let image = Self.rendered(text: "Mewtwo EX")
        let matches = try await PokemonRecognizer.shared.namedPokemon(in: image, database: database)
        #expect(matches.map(\.pokemonID) == ["mewtwo"])
    }

    @Test("Visual and printed matches merge by the strongest evidence")
    func merge() {
        let visual = [PokemonMatch(pokemonID: "mew", confidence: 0.6), PokemonMatch(pokemonID: "mewtwo", confidence: 0.3)]
        let named = [PokemonMatch(pokemonID: "mewtwo", confidence: 0.92)]
        let merged = PokemonRecognizer.merge(visual, named, limit: 5)
        #expect(merged.map(\.pokemonID) == ["mewtwo", "mew"])
        #expect(merged.first?.confidence == 0.92)
    }

    private static func bundledArtwork(_ id: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: "\(id)-art", withExtension: "heic"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)?.cgImage
    }

    private static func rendered(text: String) -> CGImage {
        let size = CGSize(width: 600, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 72), .foregroundColor: UIColor.black]
            (text as NSString).draw(at: CGPoint(x: 40, y: 60), withAttributes: attributes)
        }
        return image.cgImage!
    }
}
