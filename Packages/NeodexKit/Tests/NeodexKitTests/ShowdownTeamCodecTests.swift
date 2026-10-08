import Testing
@testable import NeodexKit

@Suite("Showdown team codec")
struct ShowdownTeamCodecTests {
    let sample = """
    Chompy (Garchomp) (M) @ Rocky Helmet
    Ability: Rough Skin
    Tera Type: Steel
    EVs: 252 HP / 4 Atk / 252 Spe
    Jolly Nature
    IVs: 0 SpA
    - Earthquake
    - Dragon Tail
    - Stealth Rock
    - Spikes

    Gholdengo @ Air Balloon
    Ability: Good as Gold
    Level: 50
    Shiny: Yes
    EVs: 252 SpA / 4 SpD / 252 Spe
    Timid Nature
    - Make It Rain
    - Shadow Ball
    - Nasty Plot
    - Recover
    """

    @Test("Parses a two-Pokémon team")
    func parse() throws {
        let teams = ShowdownTeamCodec.parseTeams(sample)
        #expect(teams.count == 1)
        let sets = try #require(teams.first?.sets)
        #expect(sets.count == 2)

        let chomp = sets[0]
        #expect(chomp.species == "Garchomp")
        #expect(chomp.nickname == "Chompy")
        #expect(chomp.gender == "M")
        #expect(chomp.item == "Rocky Helmet")
        #expect(chomp.ability == "Rough Skin")
        #expect(chomp.teraType == "Steel")
        #expect(chomp.level == 100)
        #expect(chomp.evs.hp == 252 && chomp.evs.attack == 4 && chomp.evs.speed == 252 && chomp.evs.defense == 0)
        #expect(chomp.ivs.specialAttack == 0 && chomp.ivs.attack == 31)
        #expect(chomp.nature == "Jolly")
        #expect(chomp.moves == ["Earthquake", "Dragon Tail", "Stealth Rock", "Spikes"])

        let ghold = sets[1]
        #expect(ghold.species == "Gholdengo")
        #expect(ghold.nickname == nil)
        #expect(ghold.gender == nil)
        #expect(ghold.level == 50)
        #expect(ghold.shiny)
        #expect(ghold.moves.count == 4)
    }

    @Test("Export then import is lossless")
    func roundTrip() throws {
        let original = try #require(ShowdownTeamCodec.parseTeams(sample).first)
        let exported = ShowdownTeamCodec.export(original)
        let reparsed = try #require(ShowdownTeamCodec.parseTeams(exported).first)
        #expect(reparsed.sets == original.sets)
    }

    @Test("Export matches Showdown's layout")
    func exportFormat() {
        var set = ShowdownSet(species: "Charizard-Mega-X")
        set.nickname = "Zard"
        set.gender = "F"
        set.item = "Charizardite X"
        set.ability = "Tough Claws"
        set.evs = StatBlock(hp: 0, attack: 252, defense: 0, specialAttack: 0, specialDefense: 4, speed: 252)
        set.nature = "Adamant"
        set.moves = ["Flare Blitz", "Dragon Claw", "Hidden Power Ice"]
        let text = ShowdownTeamCodec.export(set)
        #expect(text == """
        Zard (Charizard-Mega-X) (F) @ Charizardite X
        Ability: Tough Claws
        EVs: 252 Atk / 4 SpD / 252 Spe
        Adamant Nature
        - Flare Blitz
        - Dragon Claw
        - Hidden Power [Ice]

        """)
    }

    @Test("Team headers carry format and name")
    func headers() throws {
        let text = """
        === [gen9ou] Rain Offense ===

        Pelipper @ Damp Rock
        Ability: Drizzle
        - Hurricane

        === [gen9vgc2025regi] Sun ===

        Torkoal @ Eject Pack
        Ability: Drought
        - Eruption
        """
        let teams = ShowdownTeamCodec.parseTeams(text)
        #expect(teams.count == 2)
        #expect(teams[0].format == "gen9ou")
        #expect(teams[0].name == "Rain Offense")
        #expect(teams[0].sets.map(\.species) == ["Pelipper"])
        #expect(teams[1].format == "gen9vgc2025regi")
        #expect(teams[1].sets.first?.item == "Eject Pack")
    }

    @Test("Species line variants")
    func speciesLines() {
        #expect(ShowdownTeamCodec.parseSpeciesLine("Pikachu").species == "Pikachu")
        let withItem = ShowdownTeamCodec.parseSpeciesLine("Pikachu @ Light Ball")
        #expect(withItem.species == "Pikachu" && withItem.item == "Light Ball")
        let nicknameOnly = ShowdownTeamCodec.parseSpeciesLine("Sparky (Pikachu)")
        #expect(nicknameOnly.species == "Pikachu" && nicknameOnly.nickname == "Sparky")
        let parens = ShowdownTeamCodec.parseSpeciesLine("Mr. Mime (M) @ Leftovers")
        #expect(parens.species == "Mr. Mime" && parens.gender == "M" && parens.item == "Leftovers")
        let nidoran = ShowdownTeamCodec.parseSpeciesLine("Nidoran-F (F)")
        #expect(nidoran.species == "Nidoran-F" && nidoran.gender == "F")
    }
}
