import Foundation
import NeodexKit
import SwiftData
import Testing
@testable import Neodex

/// Dexbot's teambuilding against the real dataset, an in-memory store and made-up Smogon statistics.
@Suite("Dexbot teams")
@MainActor
struct DexbotTeamTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: SavedTeam.self, BrowsingRecord.self, DexbotConversation.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func savedTeams(in context: ModelContext) throws -> [SavedTeam] {
        try context.fetch(FetchDescriptor<SavedTeam>())
    }

    private nonisolated static func entries(_ keys: [String]) -> [UsageDetail.Entry] {
        keys.enumerated().map { UsageDetail.Entry(key: $1, percent: Double(90 - $0 * 10)) }
    }

    /// Smogon-style details for Great Tusk and Kingambit, as if fetched for Gen 9 OU.
    private nonisolated static func ouDetails() -> [String: UsageDetail] {
        [
            "Great Tusk": UsageDetail(name: "Great Tusk", usagePercent: 30, rawCount: 1000,
                                      abilities: entries(["protosynthesis"]), items: entries(["nothing", "heavydutyboots"]),
                                      moves: entries(["headlongrush", "icespinner", "rapidspin", "knockoff", "closecombat"]),
                                      spreads: entries(["Jolly:0/252/4/0/0/252"]), teammates: [], teraTypes: entries(["Stellar", "Steel"]),
                                      checksAndCounters: []),
            "Kingambit": UsageDetail(name: "Kingambit", usagePercent: 25, rawCount: 900,
                                     abilities: entries(["supremeoverlord"]), items: entries(["leftovers"]),
                                     moves: entries(["swordsdance", "kowtowcleave", "suckerpunch", "ironhead"]),
                                     spreads: entries(["Adamant:252/252/0/0/4/0"]), teammates: [], teraTypes: entries(["Dark"]),
                                     checksAndCounters: []),
        ]
    }

    /// The same, plus a rain core: Pelipper and Barraskewda turn up together far more than their usage
    /// explains, while Great Tusk is on Pelipper's teams no more often than on anyone's.
    private nonisolated static func rainDetails() -> [String: UsageDetail] {
        func mates(_ pairs: KeyValuePairs<String, Double>) -> [UsageDetail.Entry] { pairs.map { UsageDetail.Entry(key: $0.key, percent: $0.value) } }
        return ouDetails().merging([
            "Pelipper": UsageDetail(name: "Pelipper", usagePercent: 2, rawCount: 500,
                                    abilities: entries(["drizzle"]), items: entries(["damprock"]),
                                    moves: entries(["hurricane", "surf", "uturn", "roost"]),
                                    spreads: entries(["Bold:248/0/252/0/8/0"]),
                                    teammates: mates(["Barraskewda": 60, "Kingambit": 31, "Great Tusk": 30]),
                                    teraTypes: entries(["Ground"]), checksAndCounters: []),
            "Barraskewda": UsageDetail(name: "Barraskewda", usagePercent: 1, rawCount: 300,
                                       abilities: entries(["swiftswim"]), items: entries(["choiceband"]),
                                       moves: entries(["liquidation", "flipturn", "closecombat", "aquajet"]),
                                       spreads: entries(["Adamant:0/252/0/0/4/252"]),
                                       teammates: mates(["Pelipper": 95, "Kingambit": 35]),
                                       teraTypes: entries(["Water"]), checksAndCounters: []),
            "Politoed": UsageDetail(name: "Politoed", usagePercent: 0.1, rawCount: 20,
                                    abilities: entries(["drizzle"]), items: entries(["leftovers"]),
                                    moves: entries(["surf", "icebeam", "encore", "haze"]),
                                    spreads: [], teammates: [], teraTypes: [], checksAndCounters: []),
        ]) { $1 }
    }

    private static let usage: DexbotTeamBuilder.UsageLookup = { _ in ouDetails() }
    private static let rainUsage: DexbotTeamBuilder.UsageLookup = { _ in rainDetails() }
    private static let offline: DexbotTeamBuilder.UsageLookup = { _ in nil }

    private let fullSets = """
        Great Tusk @ Heavy-Duty Boots
        Ability: Protosynthesis
        Tera Type: Steel
        EVs: 252 Atk / 4 Def / 252 Spe
        Jolly Nature
        - Headlong Rush
        - Ice Spinner
        - Rapid Spin
        - Knock Off

        Gholdengo @ Choice Scarf
        Ability: Good as Gold
        Tera Type: Steel
        EVs: 252 SpA / 4 SpD / 252 Spe
        Timid Nature
        - Make It Rain
        - Shadow Ball
        - Nasty Plot
        - Recover
        """

    @Test("Complete, legal sets are saved as written")
    func savesLegalTeam() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        let result = await DexbotTeamBuilder.build(name: "Steel Core", format: "Gen 9 OU", sets: fullSets, database: database,
                                                   usage: Self.offline, context: context)
        #expect(result.hasPrefix("Saved “Steel Core” for Gen 9 OU to Teams with exactly these 2 Pokémon:\n- Great Tusk"), "\(result)")
        #expect(result.contains("Every set is legal in Gen 9 OU."))
        #expect(!result.contains("Changes Neodex made") && !result.contains("completed the sets"))
        #expect(result.contains("couldn't fill the empty slots"))
        let team = try #require(try savedTeams(in: context).first)
        #expect(team.format == "gen9ou")
        #expect(team.members.map(\.pokemonID) == ["greattusk", "gholdengo"])
        #expect(team.members.allSatisfy { $0.chosenMoveIDs.count == 4 })
        #expect(DexbotTeamBuilder.savedTeamIDs.last == team.id)
    }

    @Test("Names alone become full sets from Smogon's most common choices")
    func fillsNamesFromUsage() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        let result = await DexbotTeamBuilder.build(name: "Core", format: "gen9ou", pokemon: ["Great Tusk", "Kingambit"],
                                                   database: database, usage: Self.usage, context: context)
        #expect(result.contains("""
            with exactly these 2 Pokémon:
            - Great Tusk @ Heavy-Duty Boots (Protosynthesis): Headlong Rush, Ice Spinner, Rapid Spin, Knock Off
            - Kingambit @ Leftovers (Supreme Overlord): Swords Dance, Kowtow Cleave, Sucker Punch, Iron Head
            Neodex completed
            """), "\(result)")
        #expect(result.contains("Neodex completed the sets for Great Tusk and Kingambit with Smogon's most common Gen 9 OU choices."), "\(result)")
        #expect(!result.contains("filled the empty slots"), "Nobody else has statistics to fill them with")
        let team = try #require(try savedTeams(in: context).first)
        let tusk = try #require(team.members.first)
        #expect(tusk.abilityID == "protosynthesis")
        #expect(tusk.itemID == "heavydutyboots")
        #expect(tusk.chosenMoveIDs == ["headlongrush", "icespinner", "rapidspin", "knockoff"])
        #expect(tusk.natureID == "jolly")
        #expect(tusk.evs == StatBlock(attack: 252, defense: 4, speed: 252))
        #expect(tusk.teraType == .steel)
        #expect(team.members.last?.chosenMoveIDs == ["swordsdance", "kowtowcleave", "suckerpunch", "ironhead"])
    }

    @Test("Illegal choices are swapped for common legal ones, and banned Pokémon are left out")
    func repairsProblems() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        let sets = """
            Koraidon @ Choice Scarf
            Ability: Orichalcum Pulse
            - Flare Blitz

            Great Tusk @ Heavy-Duty Boots
            Ability: Levitate
            - Headlong Rush
            - Hydro Pump
            - Hyper Death Ray
            """
        let result = await DexbotTeamBuilder.build(name: "Fixed", format: "gen9ou", sets: sets, database: database,
                                                   usage: Self.usage, context: context)
        #expect(result.contains("Left out Koraidon"), "\(result)")
        #expect(result.contains("Great Tusk can't have Levitate."))
        #expect(result.contains("Great Tusk can't learn Hydro Pump."))
        #expect(result.contains("Hyper Death Ray"))
        #expect(result.contains("Every set is legal in Gen 9 OU."))
        let tusk = try #require(try savedTeams(in: context).first?.members.first)
        #expect(tusk.abilityID == "protosynthesis")
        #expect(tusk.chosenMoveIDs == ["headlongrush", "icespinner", "rapidspin", "knockoff"])
    }

    @Test("Empty slots go to the Pokémon players pair with the team, not just the most used")
    func fillsWithPartners() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        let result = await DexbotTeamBuilder.build(name: "Rain", format: "gen9ou", pokemon: ["Pelipper"], database: database,
                                                   usage: Self.rainUsage, context: context)
        // Barraskewda first for Pelipper alone, then Kingambit for the pair, then the most used Pokémon left.
        #expect(result.contains("Neodex filled the empty slots with Barraskewda, Kingambit, Great Tusk"), "\(result)")
        let team = try #require(try savedTeams(in: context).first)
        #expect(team.members.map(\.pokemonID) == ["pelipper", "barraskewda", "kingambit", "greattusk", "politoed"])
        #expect(team.members[1].chosenMoveIDs == ["liquidation", "flipturn", "closecombat", "aquajet"])
        #expect(result.contains("Every set is legal in Gen 9 OU."), "\(result)")
    }

    @Test("A weather team gets the Pokémon that sets the weather most often in the format")
    func addsWeatherSetter() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        let result = await DexbotTeamBuilder.build(name: "Rain", format: "gen9ou", pokemon: ["Barraskewda"], weather: .rain,
                                                   database: database, usage: Self.rainUsage, context: context)
        #expect(result.contains("Neodex added Pelipper to set up rain with Drizzle."), "\(result)")
        #expect(!result.contains("completed the sets for Pelipper"), "\(result)")
        let lead = try #require(try savedTeams(in: context).first?.members.first)
        #expect(lead.pokemonID == "pelipper" && lead.abilityID == "drizzle")
    }

    @Test("A weather team that already has a setter keeps it and gets the right Ability")
    func keepsOwnSetter() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        let result = await DexbotTeamBuilder.build(name: "Sand", format: "gen9ou", pokemon: ["Excadrill", "Hippowdon"], weather: .sandstorm,
                                                   database: database, usage: Self.offline, context: context)
        #expect(!result.contains("to set up"), "\(result)")
        let team = try #require(try savedTeams(in: context).first)
        #expect(team.members.map(\.pokemonID) == ["excadrill", "hippowdon"])
        #expect(team.members.last?.abilityID == "sandstream")
    }

    @Test("Without statistics, the strongest setter the format allows leads the team")
    func offlineWeatherSetter() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        let result = await DexbotTeamBuilder.build(name: "Sand", format: "gen9ou", pokemon: ["Excadrill"], weather: .sandstorm,
                                                   database: database, usage: Self.offline, context: context)
        #expect(result.contains("Neodex added Tyranitar to set up sandstorm with Sand Stream."), "\(result)")
        #expect(try savedTeams(in: context).first?.members.first?.abilityID == "sandstream")
    }

    @Test("Saving under the same name again updates the team")
    func updatesSameName() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        _ = await DexbotTeamBuilder.build(name: "Rain", format: "gen9ou", sets: "Great Tusk", database: database, usage: Self.usage, context: context)
        let result = await DexbotTeamBuilder.build(name: "rain", format: "gen9ou", sets: "Great Tusk\n\nKingambit", database: database,
                                                   usage: Self.usage, context: context)
        #expect(result.hasPrefix("Updated “Rain”"), "\(result)")
        let teams = try savedTeams(in: context)
        #expect(teams.count == 1)
        #expect(teams.first?.members.count == 2)
    }

    @Test("Without Smogon's data, names still make a team that says what's missing")
    func offlineNames() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        let result = await DexbotTeamBuilder.build(name: "Offline", format: "gen9ou", sets: "Great Tusk", database: database,
                                                   usage: Self.offline, context: context)
        #expect(result.contains("Great Tusk has no moves yet"), "\(result)")
        #expect(!result.contains("completed the sets"), "Only its Ability came from the Pokédex")
        #expect(try savedTeams(in: context).count == 1)
    }

    @Test("Doubles teams get level 50 and the basic checks")
    func savesVGCTeam() async throws {
        let database = try await DatabaseProvider.shared.database()
        let context = try makeContext()
        let sets = """
            Incineroar @ Sitrus Berry
            Ability: Intimidate
            Tera Type: Grass
            EVs: 252 HP / 4 Atk / 252 SpD
            Careful Nature
            - Fake Out
            - Flare Blitz
            - Knock Off
            - Parting Shot
            """
        let result = await DexbotTeamBuilder.build(name: "Doubles Pivot", format: "VGC 2026", sets: sets, database: database,
                                                   usage: Self.offline, context: context)
        #expect(result.contains("can't check Gen 9 VGC 2026's own rules"), "\(result)")
        let team = try #require(try savedTeams(in: context).first)
        #expect(team.format == "gen9vgc2026")
        #expect(team.members.first?.level == 50)
    }

    @Test("Names pick up the sets written for them, in the names' order")
    func namesWithSets() {
        let sets = DexbotTeamBuilder.teamSets(names: ["Gholdengo", "Kingambit", "Great Tusk"], text: fullSets)
        #expect(sets.map(\.species) == ["Gholdengo", "Kingambit", "Great Tusk"])
        #expect(sets[0].moves.count == 4 && sets[1].moves.isEmpty && sets[2].item == "Heavy-Duty Boots")
        let squashed = fullSets.replacingOccurrences(of: "\n\n", with: "\n")
        #expect(DexbotTeamBuilder.teamSets(names: [], text: squashed).map(\.species) == ["Great Tusk", "Gholdengo"])
    }

    @Test("Formats, lists and spreads are read the way models write them")
    func parsing() {
        #expect(DexbotTeamBuilder.normalizedFormatID("OU") == "gen9ou")
        #expect(DexbotTeamBuilder.normalizedFormatID("Gen 9 OU") == "gen9ou")
        #expect(DexbotTeamBuilder.normalizedFormatID("Little Cup") == "gen9lc")
        #expect(DexbotTeamBuilder.normalizedFormatID("") == "gen9ou")
        #expect(DexbotTeamBuilder.defaultLevel(for: "gen9lc") == 5)
        #expect(DexbotTeamBuilder.defaultLevel(for: "gen9ou") == nil)
        #expect(DexbotTeamBuilder.setsText(from: "Pelipper, Barraskewda, Porygon2") == "Pelipper\n\nBarraskewda\n\nPorygon2")
        #expect(DexbotTeamBuilder.setsText(from: "- Pelipper\n- Barraskewda") == "Pelipper\n\nBarraskewda")
        #expect(DexbotTeamBuilder.setsText(from: "Pelipper\n- Hurricane\n- Surf") == "Pelipper\n- Hurricane\n- Surf")
        #expect(DexbotTeamBuilder.setsText(from: fullSets) == fullSets)
        let spread = DexbotTeamBuilder.parseSpread("Jolly:0/252/4/0/0/252")
        #expect(spread?.nature.id == "jolly")
        #expect(spread?.evs == StatBlock(attack: 252, defense: 4, speed: 252))
        #expect(DexbotTeamBuilder.parseSpread("Jolly") == nil)
    }

    @Test("A team from the on-device model comes with a pointer to a stronger model")
    func onDeviceNote() {
        let id = UUID()
        let onDevice = DexbotModel.answerText("Here's your rain team.", note: nil, teams: [id], answeredBy: .onDevice)
        #expect(onDevice.contains("try Claude in [Dexbot Settings](\(DexbotModel.settingsURL.absoluteString))._"), "\(onDevice)")
        #expect(DexbotTeamLink.split(onDevice).teamIDs == [id])
        #expect(!DexbotModel.answerText("Here's your rain team.", note: nil, teams: [id], answeredBy: .claude).contains("Dexbot Settings"))
        #expect(DexbotModel.answerText("Garchomp is weak to Ice.", note: nil, teams: [], answeredBy: .onDevice) == "Garchomp is weak to Ice.")
    }

    @Test("A saved team rides along with the reply and comes back out for its card")
    func teamLinks() throws {
        let id = UUID()
        let link = DexbotTeamLink.markdown(id: id, name: "Team")
        let parts = DexbotTeamLink.split("Here's your rain team.\n\n" + link + "\n\n" + link)
        #expect(parts.text == "Here's your rain team.")
        #expect(parts.teamIDs == [id])
        #expect(DexbotTeamLink.split("See [Garchomp](neodex://pokemon/garchomp).").teamIDs.isEmpty)
        #expect(DexbotConversationsView.preview(of: [DexbotMessage(role: .dexbot, text: link)]) == "Saved a team to Teams.")
    }
}
