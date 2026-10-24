import AppIntents
import CoreImage
import CoreSpotlight
import CoreVideo
import Foundation
import NeodexKit
#if canImport(VisualIntelligence) && os(iOS)
import VisualIntelligence
#endif

#if canImport(VisualIntelligence) && os(iOS)
/// Visual intelligence shows Neodex's matches when someone points the camera at a Pokémon, a card
/// or a screen and searches. The system hands over a frame; the on-device recogniser does the rest.
/// (The framework ships only in the device SDK, so simulator builds leave this out.)
nonisolated struct PokemonVisualSearchQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [PokemonEntity] {
        guard let pixelBuffer = input.pixelBuffer else { return [] }
        let database = try await DatabaseProvider.shared.database()
        let image = pixelBuffer.withUnsafeBuffer { buffer -> CGImage? in
            let ciImage = CIImage(cvPixelBuffer: buffer)
            return CIContext().createCGImage(ciImage, from: ciImage.extent)
        }
        guard let image else { return [] }
        let matches = try await PokemonRecognizer.shared.combinedMatches(in: image, database: database, limit: 6)
        // Below this the classifier is guessing; show nothing rather than a wrong Pokémon.
        return matches
            .filter { $0.confidence >= 0.12 }
            .compactMap { database.pokemon(id: $0.pokemonID) }
            .map(PokemonEntity.init)
    }
}
#endif

/// Visual intelligence lists results as indexed entities.
extension PokemonEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = name
        attributes.contentDescription = "#\(String(format: "%04d", dexNumber)) · " + types.map(\.name).joined(separator: " / ")
        attributes.keywords = [name] + types.map(\.name)
        if let url = Bundle.main.url(forResource: "\(imageID)-thumb", withExtension: "heic") {
            attributes.thumbnailData = try? Data(contentsOf: url)
        }
        return attributes
    }
}
