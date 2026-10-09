import Foundation
import Testing
@testable import NeodexKit

@Suite("Type matchup summaries and Showdown sprite IDs")
struct TypeMatchupSummaryTests {
    static let charizard = Pokemon(id: "charizard", name: "Charizard", displayName: "Charizard", nationalDexNumber: 6, generation: 1,
                                   types: [.fire, .flying], abilities: AbilitySet(primary: "blaze"), baseStats: StatBlock(repeating: 80),
                                   height: 1.7, weight: 90.5, maleRatio: nil, imageID: "charizard")
    static let megaX = Pokemon(id: "charizardmegax", name: "Charizard-Mega-X", displayName: "Mega Charizard X", nationalDexNumber: 6,
                               generation: 6, baseSpeciesID: "charizard", formName: "Mega-X", formKind: .mega, isBattleOnly: true,
                               types: [.fire, .dragon], abilities: AbilitySet(primary: "toughclaws"), baseStats: StatBlock(repeating: 80),
                               height: 1.7, weight: 110.5, maleRatio: nil, imageID: "charizardmegax")
    static let eevee = Pokemon(id: "eevee", name: "Eevee", displayName: "Eevee", nationalDexNumber: 133, generation: 1,
                               types: [.normal], abilities: AbilitySet(primary: "runaway"), baseStats: StatBlock(repeating: 50),
                               height: 0.3, weight: 6.5, maleRatio: nil, imageID: "eevee")

    @Test("Spoken summaries read naturally")
    func spoken() {
        #expect(TypeMatchupSummary.spoken(for: Self.charizard) ==
                "Charizard is a Fire and Flying type. It takes four times damage from Rock, double damage from Water and Electric, "
                + "half damage from Fire, Fighting, Steel, and Fairy, a quarter from Grass and Bug, and no damage from Ground.")
        #expect(TypeMatchupSummary.spoken(for: Self.eevee) ==
                "Eevee is a Normal type. It takes double damage from Fighting and no damage from Ghost.")
    }

    @Test("Compact summaries for text")
    func compact() {
        #expect(TypeMatchupSummary.compact(profile: Self.charizard.defensiveProfile) ==
                "Weak to Rock (4×), Water, Electric. Resists Fire, Fighting, Steel, Fairy, Grass (¼×), Bug (¼×). Immune to Ground.")
        #expect(TypeMatchupSummary.compact(profile: Self.eevee.defensiveProfile) == "Weak to Fighting. Immune to Ghost.")
    }

    @Test("Showdown sprite stems")
    func spriteIDs() {
        #expect(Self.charizard.showdownSpriteID == "charizard")
        #expect(Self.megaX.showdownSpriteID == "charizard-megax")
        #expect(!Self.eevee.isFullyEvolved == false)
    }
}
