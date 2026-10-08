import Foundation

/// One row of a Smogon usage-statistics ranking.
public struct UsageRanking: Sendable, Hashable, Identifiable {
    public var rank: Int
    /// Showdown species name, e.g. `"Great Tusk"`.
    public var name: String
    /// Weighted usage percentage (0…100).
    public var usagePercent: Double
    public var rawCount: Int?

    public init(rank: Int, name: String, usagePercent: Double, rawCount: Int? = nil) {
        self.rank = rank
        self.name = name
        self.usagePercent = usagePercent
        self.rawCount = rawCount
    }

    public var id: String { name }
}

/// A parsed `gen9ou-1695.txt`-style rankings file.
public struct UsageRankingsReport: Sendable, Hashable {
    public var totalBattles: Int?
    public var rankings: [UsageRanking]

    public init(totalBattles: Int? = nil, rankings: [UsageRanking]) {
        self.totalBattles = totalBattles
        self.rankings = rankings
    }
}

/// Parser for the plain-text rankings tables published at smogon.com/stats.
public enum UsageTextParser {
    /// Parses the fixed-width table:
    /// ```
    ///  Total battles: 574541
    ///  Avg. weight/team: 0.5
    ///  + ---- + ------------------ + --------- + ------ + ------- + ------ + ------- +
    ///  | Rank | Pokemon            | Usage %   | Raw    | %       | Real   | %       |
    ///  | 1    | Great Tusk         | 33.14600% | 339306 | 24.5%   | ...
    /// ```
    public static func parseRankings(_ text: String) -> UsageRankingsReport {
        var totalBattles: Int?
        var rankings: [UsageRanking] = []
        for line in text.components(separatedBy: .newlines) {
            if line.contains("Total battles:") {
                totalBattles = Int(line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "")
                continue
            }
            guard line.hasPrefix(" |") || line.hasPrefix("|") else { continue }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard cells.count >= 3, let rank = Int(cells[0]) else { continue }
            let name = cells[1]
            let usage = Double(cells[2].replacingOccurrences(of: "%", with: "")) ?? 0
            let raw = cells.count > 3 ? Int(cells[3]) : nil
            rankings.append(UsageRanking(rank: rank, name: name, usagePercent: usage, rawCount: raw))
        }
        return UsageRankingsReport(totalBattles: totalBattles, rankings: rankings)
    }

    /// Extracts `YYYY-MM` directory names from the stats index page HTML.
    public static func parseMonths(fromIndexHTML html: String) -> [String] {
        var seen = Set<String>()
        var months: [String] = []
        let pattern = #"href="(\d{4}-\d{2}(?:-DLC\d)?)/""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let month = String(html[range])
            if seen.insert(month).inserted { months.append(month) }
        }
        return months.sorted(by: >)
    }

    /// Extracts `(format, rating)` pairs from a `chaos/` directory listing.
    public static func parseFormats(fromDirectoryHTML html: String) -> [UsageFormat] {
        var byFormat: [String: Set<Int>] = [:]
        let pattern = #"href="([a-z0-9]+)-(\d+)\.json""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let formatRange = Range(match.range(at: 1), in: html),
                  let ratingRange = Range(match.range(at: 2), in: html),
                  let rating = Int(html[ratingRange]) else { continue }
            byFormat[String(html[formatRange]), default: []].insert(rating)
        }
        return byFormat.map { UsageFormat(id: $0.key, ratingCutoffs: $0.value.sorted()) }
            .sorted { $0.id < $1.id }
    }
}

/// A Showdown format with usage data for a month.
public struct UsageFormat: Sendable, Hashable, Identifiable {
    /// Format ID, e.g. `"gen9ou"`.
    public var id: String
    /// Available rating cutoffs, ascending (the first is always 0).
    public var ratingCutoffs: [Int]

    public init(id: String, ratingCutoffs: [Int]) {
        self.id = id
        self.ratingCutoffs = ratingCutoffs
    }

    /// Human-friendly name, e.g. `"Gen 9 OU"`, `"Gen 9 VGC 2024 Reg G"`.
    public var displayName: String { UsageFormat.displayName(for: id) }

    public var generation: Int? {
        guard id.hasPrefix("gen"), let digit = id.dropFirst(3).first?.wholeNumberValue else { return nil }
        return digit
    }

    public static func displayName(for id: String) -> String {
        var rest = Substring(id)
        var prefix = ""
        if rest.hasPrefix("gen"), let digit = rest.dropFirst(3).first, digit.isNumber {
            prefix = "Gen \(digit) "
            rest = rest.dropFirst(4)
        }
        let known: [(String, String)] = [
            ("nationaldexmonotype", "National Dex Monotype"), ("nationaldexdoubles", "National Dex Doubles"),
            ("nationaldexubers", "National Dex Ubers"), ("nationaldexuu", "National Dex UU"), ("nationaldexag", "National Dex AG"),
            ("nationaldex", "National Dex"), ("doublesubers", "Doubles Ubers"), ("doublesou", "Doubles OU"), ("doublesuu", "Doubles UU"),
            ("doubleslc", "Doubles LC"), ("anythinggoes", "Anything Goes"), ("almostanyability", "Almost Any Ability"),
            ("balancedhackmons", "Balanced Hackmons"), ("randombattle", "Random Battle"), ("randomdoublesbattle", "Random Doubles Battle"),
            ("battlestadiumsingles", "Battle Stadium Singles"), ("battlestadiumdoubles", "Battle Stadium Doubles"),
            ("ubersuu", "Ubers UU"), ("monotype", "Monotype"), ("ubers", "Ubers"), ("1v1", "1v1"), ("2v2doubles", "2v2 Doubles"),
            ("mixandmega", "Mix and Mega"), ("godlygift", "Godly Gift"), ("stabmons", "STABmons"), ("partnersincrime", "Partners in Crime"),
            ("inheritance", "Inheritance"), ("sharedpower", "Shared Power"), ("purehackmons", "Pure Hackmons"), ("camomons", "Camomons"),
            ("ou", "OU"), ("uu", "UU"), ("ru", "RU"), ("nu", "NU"), ("pu", "PU"), ("zu", "ZU"), ("lc", "LC"), ("ag", "AG"), ("cap", "CAP"),
        ]
        for (key, name) in known where rest.hasPrefix(key) {
            let remainder = rest.dropFirst(key.count)
            return prefix + name + (remainder.isEmpty ? "" : " " + prettify(String(remainder)))
        }
        if rest.hasPrefix("vgc") {
            let remainder = rest.dropFirst(3)
            let year = remainder.prefix { $0.isNumber }
            let series = remainder.dropFirst(year.count)
            var name = "VGC \(year)"
            if series.hasPrefix("reg") {
                name += " Reg " + series.dropFirst(3).uppercased()
            } else if !series.isEmpty {
                name += " " + prettify(String(series))
            }
            return prefix + name
        }
        if rest.hasPrefix("bss") {
            return prefix + "Battle Stadium Singles " + prettify(String(rest.dropFirst(3)))
        }
        return prefix + prettify(String(rest))
    }

    private static func prettify(_ text: String) -> String {
        text.replacingOccurrences(of: "series", with: "Series ")
            .replacingOccurrences(of: "bo3", with: "Bo3")
            .capitalized
            .trimmingCharacters(in: .whitespaces)
    }
}

/// Detailed usage data for one Pokémon in one format, from Smogon's "chaos" JSON files.
public struct UsageDetail: Sendable, Hashable {
    public struct Entry: Sendable, Hashable, Identifiable {
        /// Showdown ID (abilities, items, moves) or display name (teammates), or a spread like `"Jolly:0/252/4/0/0/252"`.
        public var key: String
        /// Percentage of this Pokémon's weighted usage (0…100).
        public var percent: Double

        public init(key: String, percent: Double) {
            self.key = key
            self.percent = percent
        }

        public var id: String { key }
    }

    public struct Check: Sendable, Hashable, Identifiable {
        public var name: String
        /// Probability the check KOs or forces out this Pokémon.
        public var probability: Double
        public var deviation: Double

        public init(name: String, probability: Double, deviation: Double) {
            self.name = name
            self.probability = probability
            self.deviation = deviation
        }

        public var id: String { name }

        /// Smogon's displayed score: `p - 4σ`.
        public var score: Double { probability - 4 * deviation }
    }

    public var name: String
    public var usagePercent: Double
    public var rawCount: Int
    public var abilities: [Entry]
    public var items: [Entry]
    public var moves: [Entry]
    public var spreads: [Entry]
    public var teammates: [Entry]
    public var teraTypes: [Entry]
    public var checksAndCounters: [Check]

    public init(name: String, usagePercent: Double, rawCount: Int, abilities: [Entry], items: [Entry], moves: [Entry],
                spreads: [Entry], teammates: [Entry], teraTypes: [Entry], checksAndCounters: [Check]) {
        self.name = name
        self.usagePercent = usagePercent
        self.rawCount = rawCount
        self.abilities = abilities
        self.items = items
        self.moves = moves
        self.spreads = spreads
        self.teammates = teammates
        self.teraTypes = teraTypes
        self.checksAndCounters = checksAndCounters
    }
}

/// A whole chaos file: metadata plus every Pokémon's details.
public struct UsageChaosReport: Sendable, Hashable {
    public var metagame: String
    public var cutoff: Int
    public var numberOfBattles: Int
    public var details: [String: UsageDetail]

    public init(metagame: String, cutoff: Int, numberOfBattles: Int, details: [String: UsageDetail]) {
        self.metagame = metagame
        self.cutoff = cutoff
        self.numberOfBattles = numberOfBattles
        self.details = details
    }

    /// Rankings derived from the chaos data, sorted by usage.
    public var rankings: [UsageRanking] {
        details.values.sorted { $0.usagePercent > $1.usagePercent }.enumerated().map { index, detail in
            UsageRanking(rank: index + 1, name: detail.name, usagePercent: detail.usagePercent, rawCount: detail.rawCount)
        }
    }

    /// Decodes Smogon's chaos JSON.
    public static func decode(_ data: Data) throws -> UsageChaosReport {
        let raw = try JSONDecoder().decode(RawChaos.self, from: data)
        var details: [String: UsageDetail] = [:]
        details.reserveCapacity(raw.data.count)
        for (name, entry) in raw.data {
            // Every set has exactly one ability, so the ability weights sum to the Pokémon's total weight.
            let total = entry.abilities.values.reduce(0, +)
            func entries(_ dict: [String: Double], fraction: Bool = false) -> [UsageDetail.Entry] {
                let denominator = fraction ? max(dict.values.reduce(0, +), .ulpOfOne) : max(total, .ulpOfOne)
                return dict.map { UsageDetail.Entry(key: $0.key, percent: $0.value / denominator * 100) }
                    .filter { $0.percent >= 0.05 }
                    .sorted { $0.percent > $1.percent }
            }
            let checks = entry.checksAndCounters.map { UsageDetail.Check(name: $0.key, probability: $0.value.p, deviation: $0.value.d) }
                .sorted { $0.score > $1.score }
            details[name] = UsageDetail(
                name: name,
                usagePercent: entry.usage * 100,
                rawCount: entry.rawCount,
                abilities: entries(entry.abilities),
                items: entries(entry.items),
                moves: entries(entry.moves),
                spreads: entries(entry.spreads),
                teammates: entries(entry.teammates),
                teraTypes: entries(entry.teraTypes ?? [:]),
                checksAndCounters: checks
            )
        }
        return UsageChaosReport(metagame: raw.info.metagame, cutoff: raw.info.cutoff,
                                numberOfBattles: raw.info.numberOfBattles, details: details)
    }

    private struct RawChaos: Decodable {
        struct Info: Decodable {
            var metagame: String
            var cutoff: Int
            var numberOfBattles: Int
            enum CodingKeys: String, CodingKey {
                case metagame, cutoff
                case numberOfBattles = "number of battles"
            }
        }
        struct Entry: Decodable {
            var usage: Double
            var rawCount: Int
            var abilities: [String: Double]
            var items: [String: Double]
            var moves: [String: Double]
            var spreads: [String: Double]
            var teammates: [String: Double]
            var teraTypes: [String: Double]?
            var checksAndCounters: [String: CheckValue]
            enum CodingKeys: String, CodingKey {
                case usage
                case rawCount = "Raw count"
                case abilities = "Abilities"
                case items = "Items"
                case moves = "Moves"
                case spreads = "Spreads"
                case teammates = "Teammates"
                case teraTypes = "Tera Types"
                case checksAndCounters = "Checks and Counters"
            }
        }
        struct CheckValue: Decodable {
            var n: Double
            var p: Double
            var d: Double
        }
        var info: Info
        var data: [String: Entry]
    }
}
