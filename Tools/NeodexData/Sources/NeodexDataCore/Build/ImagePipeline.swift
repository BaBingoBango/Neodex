import CoreGraphics
import Foundation
import ImageIO
import NeodexKit
import UniformTypeIdentifiers

/// Downloads artwork and sprites, converts them to compact bundled formats, and records
/// which Pokémon had to fall back to their base species' artwork.
struct ImagePipeline {
    let fetcher: Fetcher
    let imagesDirectory: URL
    var concurrency = 8
    var force = false

    static let artworkSize = 400
    static let thumbnailSize = 120
    static let heicQuality = 0.8

    struct Report: Sendable {
        var artworkWritten = 0
        var dexSpriteFallbacks: [String] = []
        var speciesFallbacks: [String] = []
        var missingArtwork: [String] = []
        var missingSprites: [String] = []
        var itemIcons = 0
    }

    private enum ArtworkSource: Sendable {
        case pokeapi(Data)
        case showdownDex(Data)
        case none
    }

    private struct Result: Sendable {
        var id: String
        var wroteArtwork: Bool
        var artworkSource: String
        var wroteSprite: Bool
    }

    var artworkDirectory: URL { imagesDirectory.appendingPathComponent("artwork") }
    var thumbnailDirectory: URL { imagesDirectory.appendingPathComponent("thumbs") }
    var spriteDirectory: URL { imagesDirectory.appendingPathComponent("sprites") }
    var itemDirectory: URL { imagesDirectory.appendingPathComponent("items") }

    func run(pokemon: inout [Pokemon], pokeapiIDs: [String: Int], spriteIDs: [String: String], items: [Item]) async throws -> Report {
        for directory in [artworkDirectory, thumbnailDirectory, spriteDirectory, itemDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        var report = Report()
        let speciesByID = Dictionary(uniqueKeysWithValues: pokemon.map { ($0.id, $0) })

        var results: [String: Result] = [:]
        try await withThrowingTaskGroup(of: Result.self) { group in
            var iterator = pokemon.makeIterator()
            var running = 0
            func enqueue(_ entry: Pokemon) {
                let apiID = pokeapiIDs[entry.id]
                let spriteID = spriteIDs[entry.id] ?? entry.id
                let speciesSpriteID = spriteIDs[entry.speciesID] ?? entry.speciesID
                group.addTask { try await process(entry, apiID: apiID, spriteID: spriteID, speciesSpriteID: speciesSpriteID) }
            }
            while running < concurrency, let entry = iterator.next() { enqueue(entry); running += 1 }
            while let result = try await group.next() {
                results[result.id] = result
                if let entry = iterator.next() { enqueue(entry) }
            }
        }

        // Resolve fallbacks: forms without their own artwork borrow the base species' images.
        for index in pokemon.indices {
            let entry = pokemon[index]
            guard let result = results[entry.id] else { continue }
            if result.wroteArtwork {
                report.artworkWritten += 1
                if result.artworkSource == "dex" { report.dexSpriteFallbacks.append(entry.name) }
                pokemon[index].imageID = entry.id
            } else if entry.isBaseForm {
                report.missingArtwork.append(entry.name)
            } else if speciesByID[entry.speciesID] != nil {
                pokemon[index].imageID = entry.speciesID
                report.speciesFallbacks.append(entry.name)
            } else {
                report.missingArtwork.append(entry.name)
            }
            if !result.wroteSprite, pokemon[index].imageID == entry.id { report.missingSprites.append(entry.name) }
        }

        report.itemIcons = try await writeItemIcons(items)
        return report
    }

    private func process(_ entry: Pokemon, apiID: Int?, spriteID: String, speciesSpriteID: String) async throws -> Result {
        let artworkURL = artworkDirectory.appendingPathComponent("\(entry.id)-art.heic")
        let thumbnailURL = thumbnailDirectory.appendingPathComponent("\(entry.id)-thumb.heic")
        let spriteURL = spriteDirectory.appendingPathComponent("\(entry.id)-sprite.png")
        let fileManager = FileManager.default

        var wroteArtwork = fileManager.fileExists(atPath: artworkURL.path) && fileManager.fileExists(atPath: thumbnailURL.path) && !force
        var artworkSource = wroteArtwork ? "cached" : "none"
        if !wroteArtwork {
            var source = ArtworkSource.none
            if let apiID, let data = try await fetcher.data(for: PokeAPIData.spriteBase.appendingPathComponent("pokemon/other/official-artwork/\(apiID).png"), allowNotFound: true) {
                source = .pokeapi(data)
            } else if let data = try await fetcher.data(for: ShowdownData.spriteBase.appendingPathComponent("dex/\(spriteID).png"), allowNotFound: true) {
                source = .showdownDex(data)
            }
            switch source {
            case .pokeapi(let data), .showdownDex(let data):
                if let image = ImageConverter.image(from: data) {
                    try ImageConverter.writeHEIC(image, maxDimension: Self.artworkSize, quality: Self.heicQuality, to: artworkURL)
                    try ImageConverter.writeHEIC(image, maxDimension: Self.thumbnailSize, quality: Self.heicQuality, to: thumbnailURL)
                    wroteArtwork = true
                    if case .showdownDex = source { artworkSource = "dex" } else { artworkSource = "pokeapi" }
                }
            case .none:
                break
            }
        }

        var wroteSprite = fileManager.fileExists(atPath: spriteURL.path) && !force
        if !wroteSprite {
            let candidates = spriteID == speciesSpriteID ? [spriteID] : [spriteID, speciesSpriteID]
            for candidate in candidates {
                if let data = try await fetcher.data(for: ShowdownData.spriteBase.appendingPathComponent("gen5/\(candidate).png"), allowNotFound: true) {
                    try data.write(to: spriteURL, options: .atomic)
                    wroteSprite = true
                    break
                }
            }
        }
        return Result(id: entry.id, wroteArtwork: wroteArtwork, artworkSource: artworkSource, wroteSprite: wroteSprite)
    }

    /// Slices Showdown's 16-column item sprite sheet (24×24 tiles) into one PNG per item.
    private func writeItemIcons(_ items: [Item]) async throws -> Int {
        guard let sheetData = try await fetcher.data(for: ShowdownData.spriteBase.appendingPathComponent("itemicons-sheet.png")),
              let sheet = ImageConverter.image(from: sheetData) else { return 0 }
        let tile = 24
        let columns = sheet.width / tile
        var written = 0
        for item in items {
            guard let index = item.spriteIndex, index >= 0 else { continue }
            let url = itemDirectory.appendingPathComponent("\(item.id)-item.png")
            if FileManager.default.fileExists(atPath: url.path), !force { written += 1; continue }
            let rect = CGRect(x: (index % columns) * tile, y: (index / columns) * tile, width: tile, height: tile)
            guard rect.maxY <= CGFloat(sheet.height), let icon = sheet.cropping(to: rect) else { continue }
            try ImageConverter.writePNG(icon, to: url)
            written += 1
        }
        return written
    }
}

/// ImageIO helpers for decoding, resizing and encoding.
enum ImageConverter {
    enum ConversionError: Error { case decodeFailed, encodeFailed }

    static func image(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func resized(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let scale = min(1, Double(maxDimension) / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    static func writeHEIC(_ image: CGImage, maxDimension: Int, quality: Double, to url: URL) throws {
        guard let resized = resized(image, maxDimension: maxDimension) else { throw ConversionError.decodeFailed }
        try write(resized, type: .heic, options: [kCGImageDestinationLossyCompressionQuality: quality], to: url)
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try write(image, type: .png, options: [:], to: url)
    }

    private static func write(_ image: CGImage, type: UTType, options: [CFString: Any], to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw ConversionError.encodeFailed
        }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.encodeFailed }
    }
}
