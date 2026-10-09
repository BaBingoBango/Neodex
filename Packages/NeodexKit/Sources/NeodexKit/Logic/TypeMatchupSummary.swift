import Foundation

/// Natural-language descriptions of a Pokémon's type matchups, for Siri and accessibility.
public enum TypeMatchupSummary {
    /// E.g. "Charizard is a Fire and Flying type. It takes four times damage from Rock, double damage
    /// from Water and Electric, half damage from Fighting, Steel and Fairy, a quarter from Bug, Fire and
    /// Grass, and no damage from Ground."
    public static func spoken(for pokemon: Pokemon) -> String {
        let types = pokemon.types.map(\.name)
        let typeSentence = types.count == 2
            ? "\(pokemon.displayName) is a \(types[0]) and \(types[1]) type."
            : "\(pokemon.displayName) is a \(types[0]) type."
        return typeSentence + " " + describe(profile: pokemon.defensiveProfile, subject: "It")
    }

    /// Just the matchup sentence for a type combination, e.g. for Type-O-Matic.
    public static func describe(profile: TypeMatchup.DefensiveProfile, subject: String = "It") -> String {
        var clauses: [String] = []
        if !profile.doubleWeaknesses.isEmpty { clauses.append("four times damage from " + list(profile.doubleWeaknesses)) }
        if !profile.weaknesses.isEmpty { clauses.append("double damage from " + list(profile.weaknesses)) }
        if !profile.resistances.isEmpty { clauses.append("half damage from " + list(profile.resistances)) }
        if !profile.doubleResistances.isEmpty { clauses.append("a quarter from " + list(profile.doubleResistances)) }
        if !profile.immunities.isEmpty { clauses.append("no damage from " + list(profile.immunities)) }
        guard !clauses.isEmpty else { return "\(subject) takes neutral damage from every type." }
        return "\(subject) takes " + join(clauses) + "."
    }

    /// A compact version for text, e.g. "Weak to Rock (4×), Water, Electric. Resists …"
    public static func compact(profile: TypeMatchup.DefensiveProfile) -> String {
        var lines: [String] = []
        let weak = profile.doubleWeaknesses.map { "\($0.name) (4×)" } + profile.weaknesses.map(\.name)
        if !weak.isEmpty { lines.append("Weak to " + weak.joined(separator: ", ")) }
        let resists = profile.resistances.map(\.name) + profile.doubleResistances.map { "\($0.name) (¼×)" }
        if !resists.isEmpty { lines.append("Resists " + resists.joined(separator: ", ")) }
        if !profile.immunities.isEmpty { lines.append("Immune to " + profile.immunities.map(\.name).joined(separator: ", ")) }
        return lines.joined(separator: ". ") + (lines.isEmpty ? "" : ".")
    }

    private static func list(_ types: [PokemonType]) -> String { join(types.map(\.name)) }

    private static func join(_ parts: [String]) -> String {
        switch parts.count {
        case 0: ""
        case 1: parts[0]
        case 2: "\(parts[0]) and \(parts[1])"
        default: parts.dropLast().joined(separator: ", ") + ", and " + parts.last!
        }
    }
}
