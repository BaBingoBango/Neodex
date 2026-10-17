import Foundation
import NeodexKit

/// Pokémon TCG card illustrations from pokemontcg.io, grouped by National Dex number.
///
/// Cards are the one source that shows each Pokémon in dozens of art styles, which is what a camera
/// classifier needs; they also double as realistic validation data.
enum TradingCards {
    struct Card: Decodable, Sendable {
        struct Images: Decodable, Sendable {
            let small: URL
        }

        let id: String
        let name: String
        let subtypes: [String]?
        let nationalPokedexNumbers: [Int]?
        let types: [String]?
        let images: Images
    }

    private struct Page: Decodable, Sendable {
        let data: [Card]
        let totalCount: Int
    }

    static let pageSize = 250
    static let pageConcurrency = 2

    /// Every Pokémon card, keyed by the single dex number it depicts (tag-team cards are skipped).
    static func load(using fetcher: Fetcher, log: Pipeline.Log) async throws -> [Int: [Card]] {
        guard let first = try await page(1, using: fetcher) else {
            log("  pokemontcg.io is unavailable; training without cards")
            return [:]
        }
        let pageCount = min(200, Int((Double(first.totalCount) / Double(pageSize)).rounded(.up)))
        var pages: [Int: Page] = [1: first]
        try await withThrowingTaskGroup(of: (Int, Page?).self) { group in
            var next = 2
            var running = 0
            func enqueue() {
                let number = next
                next += 1
                group.addTask { (number, try await page(number, using: fetcher)) }
            }
            while running < pageConcurrency, next <= pageCount { enqueue(); running += 1 }
            while let (number, page) = try await group.next() {
                if let page { pages[number] = page } else { log("  card page \(number) was unavailable") }
                if pages.count % 10 == 0 { log("  card pages \(pages.count)/\(pageCount)") }
                if next <= pageCount { enqueue() }
            }
        }

        var grouped: [Int: [Card]] = [:]
        for page in pages.values {
            for card in page.data {
                guard let numbers = card.nationalPokedexNumbers, numbers.count == 1 else { continue }
                grouped[numbers[0], default: []].append(card)
            }
        }
        for key in grouped.keys { grouped[key]?.sort { $0.id < $1.id } }
        return grouped
    }

    private static func page(_ number: Int, using fetcher: Fetcher) async throws -> Page? {
        var components = URLComponents(string: "https://api.pokemontcg.io/v2/cards")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "supertype:Pokémon"),
            URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            URLQueryItem(name: "page", value: "\(number)"),
        ]
        guard let url = components.url, let data = try await fetchWithRetry(url, using: fetcher) else { return nil }
        return try JSONDecoder().decode(Page.self, from: data)
    }

    /// pokemontcg.io answers 5xx (and 429 when it is busy) now and then; wait and retry, and give up
    /// quietly on a page or image that stays unavailable.
    static func fetchWithRetry(_ url: URL, using fetcher: Fetcher, attempts: Int = 8) async throws -> Data? {
        var delay = 3.0
        for attempt in 1...attempts {
            do {
                return try await fetcher.data(for: url, allowNotFound: true)
            } catch Fetcher.FetchError.badStatus(let code, _) where code == 429 || code >= 500 {
                if attempt == attempts { return nil }
                try await Task.sleep(for: .seconds(delay))
                delay *= 1.5
            }
        }
        return nil
    }

    /// The form a card depicts, chosen among the forms that share its dex number. A form matches when
    /// every word of its name appears on the card ("Rapid Strike Urshifu VMAX" → Rapid-Strike-Gmax).
    /// Returns `nil` when the card can't tell two forms apart (a "M Charizard-EX" whose TCG type fits
    /// both Mega X and Mega Y), so that card is left out rather than mislabelled.
    static func match(_ card: Card, among candidates: [Pokemon]) -> Pokemon? {
        guard let base = candidates.first(where: \.isBaseForm) ?? candidates.first else { return nil }
        var cardTokens = Set(normalize(card.name))
        if card.subtypes?.contains("VMAX") == true { cardTokens.insert("gmax") }

        var best: [Pokemon] = []
        var bestScore = 0
        for candidate in candidates where !candidate.isBaseForm {
            let required = formTokens(for: candidate)
            guard !required.isEmpty else { continue }
            var score = 0
            if required.isSubset(of: cardTokens) {
                score = required.count
            } else if required.contains("mega"), required.subtracting(["x", "y"]).isSubset(of: cardTokens) {
                // A Mega card that doesn't say X or Y; settled by type below, if it can be.
                score = required.count - 1
            }
            if score > bestScore {
                bestScore = score
                best = [candidate]
            } else if score == bestScore, score > 0 {
                best.append(candidate)
            }
        }
        guard bestScore > 0 else { return base }
        if best.count == 1 { return best[0] }

        // Tied forms: the card's TCG type decides, using only the types the tied forms don't share.
        let cardTypes = Set((card.types ?? []).map { $0.lowercased() })
        let typeSets = best.map { Set($0.types.map(tcgType)) }
        let shared = typeSets.dropFirst().reduce(typeSets[0]) { $0.intersection($1) }
        let matches = zip(best, typeSets).filter { !$1.subtracting(shared).intersection(cardTypes).isEmpty }
        return matches.count == 1 ? matches[0].0 : nil
    }

    /// Lowercased words of a name with the TCG's spellings folded onto Showdown's ("Alolan" → "alola",
    /// "M" → "mega", "VMAX" → "gmax"); `%` survives for Zygarde 10%, other punctuation goes.
    static func normalize(_ name: String) -> [String] {
        let aliases = ["alolan": "alola", "galarian": "galar", "hisuian": "hisui", "paldean": "paldea",
                       "m": "mega", "vmax": "gmax", "gigantamax": "gmax"]
        return name.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in String(word.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "%" }) }
            .filter { !$0.isEmpty }
            .map { aliases[$0] ?? $0 }
    }

    /// The words a card must carry to depict this form; filler like "Forme" doesn't count.
    static func formTokens(for pokemon: Pokemon) -> Set<String> {
        Set(normalize(pokemon.formName ?? "")).subtracting(["forme", "form", "mode", "style", "size", "cloak", "mask"])
    }

    /// The TCG energy type a Pokémon type maps to.
    static func tcgType(_ type: PokemonType) -> String {
        switch type {
        case .fire: "fire"
        case .water, .ice: "water"
        case .grass, .bug: "grass"
        case .electric: "lightning"
        case .psychic, .ghost, .poison: "psychic"
        case .fighting, .rock, .ground: "fighting"
        case .dark: "darkness"
        case .steel: "metal"
        case .dragon: "dragon"
        case .fairy: "fairy"
        case .normal, .flying: "colorless"
        }
    }
}
