import Foundation
import Testing
@testable import NeodexKit

@Suite("Identifiers and search")
struct SupportTests {
    @Test("Showdown IDs strip punctuation and accents")
    func showdownIDs() {
        #expect(ShowdownID.make("Charizard-Mega-X") == "charizardmegax")
        #expect(ShowdownID.make("Flabébé") == "flabebe")
        #expect(ShowdownID.make("Farfetch’d") == "farfetchd")
        #expect(ShowdownID.make("Mr. Mime") == "mrmime")
        #expect(ShowdownID.make("Nidoran♀") == "nidoranf")
        #expect(ShowdownID.make("10,000,000 Volt Thunderbolt") == "10000000voltthunderbolt")
    }

    @Test("Search ranking prefers exact, then prefix, then word prefix")
    func searchRanking() {
        let query = SearchNormalizer.normalize("mega")
        #expect(SearchNormalizer.match("mega", query: query) == .exact)
        #expect(SearchNormalizer.match("meganium", query: query) == .prefix)
        #expect(SearchNormalizer.match("charizard mega x", query: query) == .wordPrefix)
        #expect(SearchNormalizer.match("omega", query: query) == .contains)
        #expect(SearchNormalizer.match("pikachu", query: query) == .none)
        #expect(SearchNormalizer.normalize("  Flabébé-Blue  ") == "flabebeblue")
    }

    @Test("Learnset codes round-trip")
    func learnsetCodes() throws {
        let level = try #require(LearnSource(code: "9L24"))
        #expect(level.generation == 9 && level.method == .levelUp && level.level == 24)
        #expect(level.code == "9L24")
        #expect(level.label == "Lv. 24")
        let machine = try #require(LearnSource(code: "9M"))
        #expect(machine.method == .machine && machine.level == nil && machine.label == "TM")
        let event = try #require(LearnSource(code: "7S3"))
        #expect(event.method == .event && event.code == "7S")
        #expect(LearnSource(code: "X") == nil)

        let encoded = try JSONEncoder().encode([level, machine])
        #expect(String(decoding: encoded, as: UTF8.self) == #"["9L24","9M"]"#)
        let decoded = try JSONDecoder().decode([LearnSource].self, from: encoded)
        #expect(decoded == [level, machine])
    }

    @Test("Evolution descriptions read naturally")
    func evolutionText() {
        #expect(Evolution(to: "ivysaur", level: 16).methodDescription == "Level 16")
        #expect(Evolution(to: "vaporeon", kind: "useItem", item: "Water Stone").methodDescription == "Use Water Stone")
        #expect(Evolution(to: "espeon", kind: "levelFriendship", condition: "during the day").methodDescription
                == "Level up with high friendship during the day")
        #expect(Evolution(to: "scizor", kind: "trade", item: "Metal Coat").methodDescription == "Trade holding Metal Coat")
        #expect(Evolution(to: "sirfetchd", kind: "other", condition: "Land three critical hits in one battle").methodDescription
                == "Land three critical hits in one battle")
    }
}

@Suite("Usage statistics parsing")
struct UsageParsingTests {
    @Test("Rankings table")
    func rankings() {
        let text = """
         Total battles: 574541
         Avg. weight/team: 0.5
         + ---- + ------------------ + --------- + ------ + ------- + ------ + ------- +
         | Rank | Pokemon            | Usage %   | Raw    | %       | Real   | %       |
         + ---- + ------------------ + --------- + ------ + ------- + ------ + ------- +
         | 1    | Great Tusk         | 33.14600% | 339306 | 24.520% | 268140 | 25.000% |
         | 2    | Kingambit          | 30.65542% | 251115 | 18.148% | 215080 | 20.054% |
         + ---- + ------------------ + --------- + ------ + ------- + ------ + ------- +
        """
        let report = UsageTextParser.parseRankings(text)
        #expect(report.totalBattles == 574541)
        #expect(report.rankings.count == 2)
        #expect(report.rankings[0].name == "Great Tusk")
        #expect(report.rankings[0].usagePercent == 33.146)
        #expect(report.rankings[1].rawCount == 251115)
    }

    @Test("Directory listings")
    func listings() {
        let index = #"<a href="2026-08/">2026-08/</a> <a href="2026-09/">2026-09/</a> <a href="2026-09-DLC1/">x</a>"#
        #expect(UsageTextParser.parseMonths(fromIndexHTML: index) == ["2026-09-DLC1", "2026-09", "2026-08"])
        let chaos = #"<a href="gen9ou-0.json">a</a><a href="gen9ou-1695.json">b</a><a href="gen9vgc2024regg-1760.json">c</a>"#
        let formats = UsageTextParser.parseFormats(fromDirectoryHTML: chaos)
        #expect(formats.map(\.id) == ["gen9ou", "gen9vgc2024regg"])
        #expect(formats[0].ratingCutoffs == [0, 1695])
        #expect(formats[0].displayName == "Gen 9 OU")
        #expect(formats[1].displayName == "Gen 9 VGC 2024 Reg G")
        #expect(UsageFormat.displayName(for: "gen9nationaldexmonotype") == "Gen 9 National Dex Monotype")
    }

    @Test("Chaos JSON decodes into percentages")
    func chaos() throws {
        let json = """
        {"info":{"metagame":"gen9ou","cutoff":1695,"cutoff deviation":0,"team type":null,"number of battles":1000},
         "data":{"Great Tusk":{"usage":0.33,"Raw count":100,"Abilities":{"protosynthesis":80},
           "Items":{"rockyhelmet":40,"heavydutyboots":40},"Moves":{"rapidspin":80,"headlongrush":60},
           "Spreads":{"Jolly:0/252/4/0/0/252":50},"Teammates":{"Gholdengo":20},"Tera Types":{"Steel":60,"Water":20},
           "Checks and Counters":{"Clefable":{"n":10,"p":0.67,"d":0.02}},"Happiness":{},"Viability Ceiling":[4,100,90,80]}}}
        """
        let report = try UsageChaosReport.decode(Data(json.utf8))
        #expect(report.numberOfBattles == 1000)
        let tusk = try #require(report.details["Great Tusk"])
        #expect(tusk.usagePercent == 33)
        #expect(tusk.abilities.first?.percent == 100)
        #expect(tusk.items.map(\.percent) == [50, 50])
        #expect(tusk.moves.first?.key == "rapidspin")
        #expect(tusk.moves.first?.percent == 100)
        #expect(tusk.moves.last?.percent == 75)
        #expect(tusk.teraTypes.first?.key == "Steel")
        #expect(tusk.checksAndCounters.first?.name == "Clefable")
        #expect(report.rankings.first?.rank == 1)
    }
}
