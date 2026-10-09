import Foundation
import NeodexKit
import Observation

/// Which side of a calculation a view is talking about.
enum CalcRole: String, Identifiable, Hashable {
    case attacker, defender

    var id: String { rawValue }
    var title: String { self == .attacker ? "Attacker" : "Defender" }
    var opposite: CalcRole { self == .attacker ? .defender : .attacker }
}

/// One side of the calculator: a set (the Teambuilder's `TeamMember`) plus its in-battle state.
struct CalcSide: Hashable {
    var member: TeamMember?
    /// Stat stages from −6 to +6.
    var boosts: StatBlock = .zero
    var status: StatusCondition = .none
    var hpPercent: Double = 100
    var terastallized = false
    /// For Supreme Overlord and Last Respects.
    var faintedAllies = 0
    var reflect = false
    var lightScreen = false
    var auroraVeil = false

    /// A side with a Pokémon's default set and up to four of its strongest attacks, favouring coverage.
    static func make(_ pokemon: Pokemon, database: PokedexDatabase) -> CalcSide {
        var member = TeamMember(pokemon: pokemon)
        // Rank attacks the way a player would: power, STAB and the stat the move actually uses.
        func score(_ move: Move) -> Double {
            let stab = pokemon.types.contains(move.type) ? 1.5 : 1.0
            let stat = Double(move.category == .physical ? pokemon.baseStats.attack : pokemon.baseStats.specialAttack)
            let accuracy = Double(move.accuracy ?? 100) / 100
            return Double(move.basePower) * stab * stat * accuracy
        }
        let attacks = database.learnset(for: pokemon)
            .map(\.move)
            .filter { move in
                move.basePower > 0 && move.kind == .standard && move.availability == .current && !move.isOneHitKO
                    && !move.flags.contains("recharge") && !move.flags.contains("charge")
                    && !["explosion", "selfdestruct", "mistyexplosion", "finalgambit"].contains(move.id)
            }
            .sorted { lhs, rhs in
                let lhsScore = score(lhs), rhsScore = score(rhs)
                return lhsScore != rhsScore ? lhsScore > rhsScore : lhs.name < rhs.name
            }
        var chosen: [String] = []
        var seenTypes: Set<PokemonType> = []
        for move in attacks where chosen.count < 4 {
            if seenTypes.insert(move.type).inserted { chosen.append(move.id) }
        }
        for move in attacks where chosen.count < 4 && !chosen.contains(move.id) {
            chosen.append(move.id)
        }
        member.moveIDs = (0..<4).map { $0 < chosen.count ? chosen[$0] : nil }
        return CalcSide(member: member)
    }

    func pokemon(in database: PokedexDatabase) -> Pokemon? {
        member.flatMap { database.pokemon(id: $0.pokemonID) }
    }

    func combatant(in database: PokedexDatabase) -> BattleCombatant? {
        guard let member, let pokemon = database.pokemon(id: member.pokemonID) else { return nil }
        let abilityID = member.abilityID ?? pokemon.abilities.primary
        let ability = database.ability(id: abilityID) ?? Ability(id: abilityID, name: abilityID, generation: 9)
        return BattleCombatant(pokemon: pokemon, ability: ability, level: member.level,
                               nature: Nature.named(member.natureID) ?? .serious, evs: member.evs, ivs: member.ivs,
                               boosts: boosts, item: member.itemID.flatMap { database.item(id: $0) }, status: status,
                               teraType: terastallized ? member.teraType : nil, currentHPPercent: hpPercent,
                               faintedAllies: faintedAllies)
    }

    /// E.g. `"252+ Atk / 4 Def · Choice Band · Rough Skin"`.
    func summary(in database: PokedexDatabase) -> String {
        guard let member else { return "" }
        let nature = Nature.named(member.natureID) ?? .serious
        let invested = member.evs.nonZero.map { entry -> String in
            let mark = nature.increased == entry.stat ? "+" : nature.decreased == entry.stat ? "-" : ""
            return "\(entry.value)\(mark) \(entry.stat.showdownAbbreviation)"
        }
        var parts = [invested.isEmpty ? "No EVs" : invested.joined(separator: " / ")]
        if let item = member.itemID.flatMap({ database.item(id: $0) }) { parts.append(item.name) }
        if let ability = member.abilityID.flatMap({ database.ability(id: $0) }) { parts.append(ability.name) }
        if terastallized, let tera = member.teraType { parts.append("Tera \(tera.name)") }
        if status != .none { parts.append(status.name) }
        if member.level != 100 { parts.append("Lv. \(member.level)") }
        let stages = Stat.allCases.filter { $0 != .hp && boosts[$0] != 0 }
            .map { "\(boosts[$0] > 0 ? "+" : "")\(boosts[$0]) \($0.showdownAbbreviation)" }
        if !stages.isEmpty { parts.append(stages.joined(separator: " ")) }
        if hpPercent < 100 { parts.append("\(Int(hpPercent))% HP") }
        return parts.joined(separator: " · ")
    }
}

/// A move's result against the other side.
struct CalcLine: Identifiable, Hashable {
    var move: Move
    var result: DamageResult

    var id: String { move.id }
}

/// The two sides and the field. Results are derived on demand; the calculation is cheap.
@Observable
@MainActor
final class DamageCalcModel {
    var attacker = CalcSide()
    var defender = CalcSide()
    var weather: Weather = .none
    var terrain: Terrain = .none
    var isDoubles = false
    var isCritical = false
    var gravity = false

    /// Sets handed over from the Teambuilder or Face-Off just before the calculator is pushed.
    static var handoff: (attacker: TeamMember?, defender: TeamMember?)?

    subscript(role: CalcRole) -> CalcSide {
        get { role == .attacker ? attacker : defender }
        set { if role == .attacker { attacker = newValue } else { defender = newValue } }
    }

    func field(defending side: CalcSide) -> BattleField {
        BattleField(weather: weather, terrain: terrain, isDoubles: isDoubles, isCritical: isCritical,
                    defenderHasReflect: side.reflect, defenderHasLightScreen: side.lightScreen,
                    defenderHasAuroraVeil: side.auroraVeil, gravity: gravity)
    }

    /// Every chosen move of one side against the other.
    func lines(from role: CalcRole, database: PokedexDatabase) -> [CalcLine] {
        let from = self[role]
        let against = self[role.opposite]
        guard let attacker = from.combatant(in: database), let defender = against.combatant(in: database),
              let member = from.member else { return [] }
        let field = field(defending: against)
        return member.chosenMoveIDs.compactMap { database.move(id: $0) }.map { move in
            CalcLine(move: move, result: DamageCalculator.calculate(attacker: attacker, defender: defender, move: move, field: field))
        }
    }

    func swap() {
        let attacker = attacker
        self.attacker = defender
        defender = attacker
    }
}
