import Foundation
import NeodexKit

/// Cross-checks the generated dataset for dangling references and compares the hard-coded
/// game constants in NeodexKit against Showdown's data.
enum Verifier {
    struct VerificationError: Error, LocalizedError {
        var problems: [String]
        var errorDescription: String? { "Verification failed:\n" + problems.map { "  • \($0)" }.joined(separator: "\n") }
    }

    static func verify(_ dataset: Dataset, showdown: ShowdownData) throws -> [String] {
        var problems: [String] = []
        var warnings: [String] = []

        let pokemonIDs = Set(dataset.pokemon.map(\.id))
        let abilityIDs = Set(dataset.abilities.map(\.id))
        let itemIDs = Set(dataset.items.map(\.id))
        let moveIDs = Set(dataset.moves.map(\.id))

        if Set(dataset.pokemon.map(\.id)).count != dataset.pokemon.count { problems.append("Duplicate Pokémon IDs") }
        for pokemon in dataset.pokemon {
            for abilityID in pokemon.abilities.all where !abilityIDs.contains(abilityID) {
                problems.append("\(pokemon.name) references unknown ability \(abilityID)")
            }
            for evolution in pokemon.evolutions where !pokemonIDs.contains(evolution.to) {
                problems.append("\(pokemon.name) evolves into unknown Pokémon \(evolution.to)")
            }
            if let from = pokemon.evolvesFrom, !pokemonIDs.contains(from) {
                problems.append("\(pokemon.name) evolves from unknown Pokémon \(from)")
            }
            for form in pokemon.otherFormIDs where !pokemonIDs.contains(form) {
                problems.append("\(pokemon.name) lists unknown form \(form)")
            }
            for item in pokemon.requiredItems ?? [] where !itemIDs.contains(item) {
                problems.append("\(pokemon.name) requires unknown item \(item)")
            }
            if pokemon.baseStats.total == 0 { problems.append("\(pokemon.name) has no base stats") }
            if pokemon.dexEntries.isEmpty, pokemon.isBaseForm { warnings.append("\(pokemon.name) has no Pokédex entries") }
        }
        for (pokemonID, learnset) in dataset.learnsets {
            if !pokemonIDs.contains(pokemonID) { problems.append("Learnset for unknown Pokémon \(pokemonID)") }
            for moveID in learnset.moves.keys where !moveIDs.contains(moveID) {
                problems.append("Learnset of \(pokemonID) references unknown move \(moveID)")
            }
        }
        let withoutLearnsets = dataset.pokemon.filter { $0.isBaseForm && dataset.learnsets[$0.id] == nil }
        if !withoutLearnsets.isEmpty {
            warnings.append("Base forms without learnsets: " + withoutLearnsets.map(\.name).joined(separator: ", "))
        }

        // Natures: the kit hard-codes them; make sure Showdown agrees.
        for (id, nature) in showdown.natures {
            guard let name = nature["name"]?.string else { continue }
            guard let kitNature = Nature.named(name) else { problems.append("Showdown nature \(name) is missing from NeodexKit"); continue }
            let plus = nature["plus"]?.string.flatMap(Stat.init(rawValue:))
            let minus = nature["minus"]?.string.flatMap(Stat.init(rawValue:))
            if plus != kitNature.increased || minus != kitNature.decreased {
                problems.append("Nature \(id) differs: Showdown +\(plus?.rawValue ?? "-") −\(minus?.rawValue ?? "-"), kit +\(kitNature.increased?.rawValue ?? "-") −\(kitNature.decreased?.rawValue ?? "-")")
            }
        }
        if showdown.natures.count != Nature.all.count { problems.append("Showdown has \(showdown.natures.count) natures, kit has \(Nature.all.count)") }

        // Type chart: Showdown stores damage *taken* by each type (0 normal, 1 weak, 2 resist, 3 immune).
        for (defenderKey, entry) in showdown.typeChart {
            guard let defender = PokemonType(name: defenderKey), let taken = entry["damageTaken"]?.object else { continue }
            for (attackerKey, code) in taken {
                guard let attacker = PokemonType(name: attackerKey), let code = code.int else { continue }
                let expected: Effectiveness = switch code {
                case 1: .superEffective
                case 2: .notVeryEffective
                case 3: .immune
                default: .neutral
                }
                if attacker.effectiveness(against: defender) != expected {
                    problems.append("Type chart mismatch: \(attacker.name) → \(defender.name) should be \(expected)")
                }
            }
        }

        if !problems.isEmpty { throw VerificationError(problems: problems) }
        return warnings
    }
}
