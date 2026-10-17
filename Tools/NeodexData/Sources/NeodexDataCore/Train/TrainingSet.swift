import CoreGraphics
import Foundation
import NeodexKit

/// Settings for building the recogniser's training set and model.
package struct TrainingOptions: Sendable {
    /// Trading cards per class (one in five is held out for validation).
    package var cardsPerClass = 40
    /// Composites of a cut-out on a generated background, per class.
    package var syntheticPerClass = 6
    /// Frames taken from each animated sprite.
    package var framesPerGIF = 3
    package var skipCards = false
    /// Training epochs for the softmax head.
    package var maxIterations = 40
    /// Where the weights go; defaults to `App/Resources/PokemonClassifier.weights`.
    package var modelURL: URL?

    package init() {}
}

/// Gathers labelled images for the Pokémon recogniser: one class per Pokémon with its own artwork.
///
/// Sources, per class: the bundled artwork and sprite, PokeAPI's official artwork and HOME renders
/// (normal and shiny), Dream World art, frames of Showdown's animated sprites (front, back, shiny),
/// trading-card illustrations, and composites of the cut-outs on generated backgrounds.
struct TrainingSet {
    struct Summary: Sendable {
        var classes = 0
        var trainingImages = 0
        var validationImages = 0
        var sources: [String: Int] = [:]
        var classesWithoutCards = 0
    }

    private struct ClassImages: Sendable {
        var id: String
        var training: [URL] = []
        var validation: [URL] = []
        var sources: [String: Int] = [:]

        mutating func add(_ url: URL, source: String, validation isValidation: Bool = false) {
            if isValidation { validation.append(url) } else { training.append(url) }
            sources[source, default: 0] += 1
        }
    }

    let fetcher: Fetcher
    /// The pipeline's download cache; derived images go in a `training` folder beside it.
    let cacheDirectory: URL
    /// `App/Resources/Images`, for the artwork and sprites the app already ships.
    let bundledImages: URL
    var options: TrainingOptions
    var concurrency = 8

    private static let compositeSize = 448
    private static let dreamWorldSize = 400

    private var derivedDirectory: URL { cacheDirectory.appendingPathComponent("training") }

    func build(pokemon: [Pokemon], pokeapiIDs: [String: Int], spriteIDs: [String: String],
               log: Pipeline.Log) async throws -> (training: [String: [URL]], validation: [String: [URL]], summary: Summary) {
        let classes = pokemon.filter { $0.imageID == $0.id && $0.formKind != .totem }
        log("  \(classes.count) classes (forms with their own artwork; totems fold into their species)")

        var cardsByClass: [String: [TradingCards.Card]] = [:]
        if !options.skipCards {
            log("Loading trading cards…")
            let cards = try await TradingCards.load(using: fetcher, log: log)
            let candidatesByDex = Dictionary(grouping: classes, by: \.nationalDexNumber)
            var matched = 0
            for (dex, candidates) in candidatesByDex {
                for card in cards[dex] ?? [] {
                    guard let form = TradingCards.match(card, among: candidates) else { continue }
                    cardsByClass[form.id, default: []].append(card)
                    matched += 1
                }
            }
            for key in cardsByClass.keys { cardsByClass[key] = Array(cardsByClass[key]!.prefix(options.cardsPerClass)) }
            log("  \(cards.values.reduce(0) { $0 + $1.count }) cards, \(matched) matched to a form, keeping up to \(options.cardsPerClass) per class")
        }

        try FileManager.default.createDirectory(at: derivedDirectory, withIntermediateDirectories: true)
        log("Collecting images for \(classes.count) classes…")
        var results: [ClassImages] = []
        try await withThrowingTaskGroup(of: ClassImages.self) { group in
            var iterator = classes.makeIterator()
            var running = 0
            func enqueue(_ entry: Pokemon) {
                let apiID = pokeapiIDs[entry.id]
                let spriteID = spriteIDs[entry.id] ?? entry.id
                let cards = cardsByClass[entry.id] ?? []
                group.addTask { try await collect(entry, apiID: apiID, spriteID: spriteID, cards: cards) }
            }
            while running < concurrency, let entry = iterator.next() { enqueue(entry); running += 1 }
            while let result = try await group.next() {
                results.append(result)
                if results.count % 100 == 0 { log("  \(results.count)/\(classes.count)") }
                if let entry = iterator.next() { enqueue(entry) }
            }
        }

        var training: [String: [URL]] = [:]
        var validation: [String: [URL]] = [:]
        var summary = Summary(classes: classes.count)
        for result in results where !result.training.isEmpty {
            training[result.id] = result.training
            if !result.validation.isEmpty { validation[result.id] = result.validation }
            summary.trainingImages += result.training.count
            summary.validationImages += result.validation.count
            for (source, count) in result.sources { summary.sources[source, default: 0] += count }
            if result.sources["cards"] == nil { summary.classesWithoutCards += 1 }
        }
        return (training, validation, summary)
    }

    // MARK: - One class

    private func collect(_ entry: Pokemon, apiID: Int?, spriteID: String, cards: [TradingCards.Card]) async throws -> ClassImages {
        var images = ClassImages(id: entry.id)
        let directory = derivedDirectory.appendingPathComponent(entry.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        /// Cut-outs with transparency, used for the composites.
        var subjects: [CGImage] = []

        // The artwork and sprite the app ships.
        let bundledArt = bundledImages.appendingPathComponent("artwork/\(entry.id)-art.heic")
        if let data = try? Data(contentsOf: bundledArt), let image = ImageConverter.image(from: data) {
            let url = try derived("bundled-art.png", in: directory) { image }
            images.add(url, source: "bundled")
            subjects.append(image)
        }
        let bundledSprite = bundledImages.appendingPathComponent("sprites/\(entry.id)-sprite.png")
        if let data = try? Data(contentsOf: bundledSprite), let sprite = ImageConverter.image(from: data) {
            images.add(try derived("bundled-sprite.png", in: directory) { TrainingImages.normalized(sprite, canvas: Self.frameCanvas) }, source: "bundled")
        }

        // PokeAPI: official artwork, HOME renders and Dream World art.
        if let apiID {
            let stills = ["other/official-artwork/\(apiID).png", "other/official-artwork/shiny/\(apiID).png",
                          "other/home/\(apiID).png", "other/home/shiny/\(apiID).png", "other/home/female/\(apiID).png"]
            for path in stills {
                let url = PokeAPIData.spriteBase.appendingPathComponent("pokemon/\(path)")
                guard let data = try await fetcher.data(for: url, allowNotFound: true) else { continue }
                images.add(Fetcher.cacheURL(for: url, in: cacheDirectory), source: "pokeapi")
                if subjects.count < 4, !path.contains("shiny"), let image = ImageConverter.image(from: data) { subjects.append(image) }
            }
            let dream = PokeAPIData.spriteBase.appendingPathComponent("pokemon/other/dream-world/\(apiID).svg")
            if let data = try await fetcher.data(for: dream, allowNotFound: true) {
                let target = directory.appendingPathComponent("dream.png")
                if !FileManager.default.fileExists(atPath: target.path),
                   let image = await MainActor.run(body: { TrainingImages.rasterize(svg: data, size: Self.dreamWorldSize) }) {
                    try ImageConverter.writePNG(image, to: target)
                }
                if FileManager.default.fileExists(atPath: target.path) { images.add(target, source: "dreamworld") }
            }
        }

        // Showdown's animated sprites: a few frames each of the front, back and shiny animations.
        for variant in ["ani", "ani-shiny", "ani-back"] {
            let url = ShowdownData.spriteBase.appendingPathComponent("\(variant)/\(spriteID).gif")
            guard let data = try await fetcher.data(for: url, allowNotFound: true) else { continue }
            let frames = TrainingImages.frames(fromGIF: data, count: options.framesPerGIF)
            for (index, frame) in frames.enumerated() {
                let target = try derived("\(variant)-\(index).png", in: directory) { TrainingImages.normalized(frame, canvas: Self.frameCanvas) }
                images.add(target, source: "showdown")
            }
            if variant == "ani", let first = frames.first { subjects.append(first) }
        }

        // Trading cards: one in five goes to validation; half of the training cards also contribute an art crop.
        for (index, card) in cards.enumerated() {
            guard let data = try await TradingCards.fetchWithRetry(card.images.small, using: fetcher) else { continue }
            let cached = Fetcher.cacheURL(for: card.images.small, in: cacheDirectory)
            let isValidation = cards.count >= 3 && index % 5 == 4
            images.add(cached, source: "cards", validation: isValidation)
            if !isValidation, index % 2 == 0, let image = ImageConverter.image(from: data), let art = TrainingImages.cardArt(image) {
                let target = try derived("cardart-\(card.id).png", in: directory) { art }
                images.add(target, source: "cards")
            }
        }

        // Composites of the cut-outs on generated backgrounds.
        if !subjects.isEmpty {
            var generator = SeededGenerator(string: entry.id)
            for index in 0..<options.syntheticPerClass {
                let subject = subjects[index % subjects.count]
                let target = directory.appendingPathComponent("synth-\(index).png")
                if !FileManager.default.fileExists(atPath: target.path) {
                    guard let image = TrainingImages.composite(subject, size: Self.compositeSize, generator: &generator) else { continue }
                    try ImageConverter.writePNG(image, to: target)
                }
                images.add(target, source: "synthetic")
            }
        }
        return images
    }

    private static let minimumDimension = 128
    /// Sprites and frames come in hundreds of sizes; they are all written on this square canvas.
    private static let frameCanvas = 256

    /// Writes a derived PNG once (small images are upscaled first); later runs reuse it.
    private func derived(_ name: String, in directory: URL, make: () -> CGImage) throws -> URL {
        let target = directory.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: target.path) {
            try ImageConverter.writePNG(TrainingImages.upscaled(make(), minimumDimension: Self.minimumDimension), to: target)
        }
        return target
    }
}
