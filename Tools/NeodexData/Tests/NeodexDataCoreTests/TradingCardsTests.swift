import Foundation
import NeodexKit
import Testing
@testable import NeodexDataCore

/// Matching trading cards to the form they depict.
@Suite("Trading cards")
struct TradingCardsTests {
    private static func pokemon(_ id: String, dex: Int, form: String? = nil, kind: FormKind? = nil, base: String? = nil,
                                types: [PokemonType]) -> Pokemon {
        Pokemon(id: id, name: id, displayName: id, nationalDexNumber: dex, generation: 1, baseSpeciesID: base, formName: form,
                formKind: kind, types: types, abilities: AbilitySet(primary: "none"), baseStats: .zero, height: 1, weight: 1,
                maleRatio: nil, imageID: id)
    }

    private static func card(_ name: String, subtypes: [String] = [], types: [String] = []) -> TradingCards.Card {
        TradingCards.Card(id: name, name: name, subtypes: subtypes, nationalPokedexNumbers: nil, types: types,
                          images: .init(small: URL(string: "https://example.com/\(name.hashValue).png")!))
    }

    private static let charizards = [
        pokemon("charizard", dex: 6, types: [.fire, .flying]),
        pokemon("charizardmegax", dex: 6, form: "Mega-X", kind: .mega, base: "charizard", types: [.fire, .dragon]),
        pokemon("charizardmegay", dex: 6, form: "Mega-Y", kind: .mega, base: "charizard", types: [.fire, .flying]),
        pokemon("charizardgmax", dex: 6, form: "Gmax", kind: .gigantamax, base: "charizard", types: [.fire, .flying]),
    ]

    private static let urshifus = [
        pokemon("urshifu", dex: 892, types: [.fighting, .dark]),
        pokemon("urshifurapidstrike", dex: 892, form: "Rapid-Strike", base: "urshifu", types: [.fighting, .water]),
        pokemon("urshifugmax", dex: 892, form: "Gmax", kind: .gigantamax, base: "urshifu", types: [.fighting, .dark]),
        pokemon("urshifurapidstrikegmax", dex: 892, form: "Rapid-Strike-Gmax", kind: .gigantamax, base: "urshifu", types: [.fighting, .water]),
    ]

    @Test("Plain cards go to the base form; qualifiers pick the form")
    func qualifiers() {
        #expect(TradingCards.match(Self.card("Charizard V"), among: Self.charizards)?.id == "charizard")
        #expect(TradingCards.match(Self.card("Dark Charizard"), among: Self.charizards)?.id == "charizard")
        #expect(TradingCards.match(Self.card("Charizard VMAX", subtypes: ["VMAX"]), among: Self.charizards)?.id == "charizardgmax")
        #expect(TradingCards.match(Self.card("Single Strike Urshifu V"), among: Self.urshifus)?.id == "urshifu")
        #expect(TradingCards.match(Self.card("Rapid Strike Urshifu V"), among: Self.urshifus)?.id == "urshifurapidstrike")
        #expect(TradingCards.match(Self.card("Rapid Strike Urshifu VMAX", subtypes: ["VMAX"]), among: Self.urshifus)?.id == "urshifurapidstrikegmax")
    }

    @Test("Regional and named forms match the TCG's spellings")
    func regionalForms() {
        let raichus = [Self.pokemon("raichu", dex: 26, types: [.electric]),
                       Self.pokemon("raichualola", dex: 26, form: "Alola", kind: .alolan, base: "raichu", types: [.electric, .psychic])]
        #expect(TradingCards.match(Self.card("Alolan Raichu"), among: raichus)?.id == "raichualola")
        #expect(TradingCards.match(Self.card("Raichu"), among: raichus)?.id == "raichu")
        let dialgas = [Self.pokemon("dialga", dex: 483, types: [.steel, .dragon]),
                       Self.pokemon("dialgaorigin", dex: 483, form: "Origin", base: "dialga", types: [.steel, .dragon])]
        #expect(TradingCards.match(Self.card("Origin Forme Dialga V"), among: dialgas)?.id == "dialgaorigin")
        let mimes = [Self.pokemon("mrmime", dex: 122, types: [.psychic, .fairy]),
                     Self.pokemon("mrmimegalar", dex: 122, form: "Galar", kind: .galarian, base: "mrmime", types: [.ice, .psychic])]
        #expect(TradingCards.match(Self.card("Galarian Mr. Mime"), among: mimes)?.id == "mrmimegalar")
    }

    @Test("Mega X and Y cards are told apart by type, or left out")
    func megas() {
        #expect(TradingCards.match(Self.card("M Charizard-EX", types: ["Dragon"]), among: Self.charizards)?.id == "charizardmegax")
        #expect(TradingCards.match(Self.card("M Charizard-EX", types: ["Fire"]), among: Self.charizards) == nil)
        let rayquazas = [Self.pokemon("rayquaza", dex: 384, types: [.dragon, .flying]),
                         Self.pokemon("rayquazamega", dex: 384, form: "Mega", kind: .mega, base: "rayquaza", types: [.dragon, .flying])]
        #expect(TradingCards.match(Self.card("M Rayquaza-EX", types: ["Dragon"]), among: rayquazas)?.id == "rayquazamega")
    }

    @Test("Names normalise to Showdown's spellings")
    func normalize() {
        #expect(TradingCards.normalize("Alolan Raichu-GX") == ["alola", "raichu", "gx"])
        #expect(TradingCards.normalize("Zygarde 10% Forme") == ["zygarde", "10%", "forme"])
        #expect(TradingCards.normalize("M Mewtwo-EX") == ["mega", "mewtwo", "ex"])
    }
}
