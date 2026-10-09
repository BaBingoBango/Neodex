import NeodexKit
import SwiftUI

/// Every screen that can be pushed onto a navigation stack. Using a single route type lets any
/// view link to any entity with `NavigationLink(value: AppRoute.move("flamethrower"))`.
nonisolated enum AppRoute: Hashable, Identifiable {
    case pokemon(Pokemon.ID)
    case move(Move.ID)
    case moveLearners(Move.ID)
    case ability(Ability.ID)
    case item(Item.ID)
    case nature(Nature.ID)
    case type(PokemonType)
    case typeMatchup([PokemonType])
    case pokemonMoves(Pokemon.ID)
    case faceOff(Pokemon.ID?)
    case usageDetail(UsageSelection, name: String)
    case damageCalculator(attacker: Pokemon.ID?, defender: Pokemon.ID?)

    var id: String { String(describing: self) }

    /// Spotlight identifiers look like `pokemon:bulbasaur` or `move:flamethrower`.
    init?(spotlightIdentifier: String) {
        let parts = spotlightIdentifier.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "pokemon": self = .pokemon(parts[1])
        case "move": self = .move(parts[1])
        case "ability": self = .ability(parts[1])
        case "item": self = .item(parts[1])
        case "nature": self = .nature(parts[1])
        default: return nil
        }
    }

    var spotlightIdentifier: String? {
        switch self {
        case .pokemon(let id): "pokemon:\(id)"
        case .move(let id): "move:\(id)"
        case .ability(let id): "ability:\(id)"
        case .item(let id): "item:\(id)"
        case .nature(let id): "nature:\(id)"
        default: nil
        }
    }
}

/// Resolves a route to its destination view.
struct AppRouteView: View {
    @Environment(\.database) private var database
    var route: AppRoute

    var body: some View {
        switch route {
        case .pokemon(let id):
            if let pokemon = database.pokemon(id: id) { PokemonDetailView(pokemon: pokemon) } else { missing }
        case .move(let id):
            if let move = database.move(id: id) { MoveDetailView(move: move) } else { missing }
        case .moveLearners(let id):
            if let move = database.move(id: id) { MoveLearnersView(move: move) } else { missing }
        case .ability(let id):
            if let ability = database.ability(id: id) { AbilityDetailView(ability: ability) } else { missing }
        case .item(let id):
            if let item = database.item(id: id) { ItemDetailView(item: item) } else { missing }
        case .nature(let id):
            if let nature = database.nature(id: id) { NatureDetailView(nature: nature) } else { missing }
        case .type(let type):
            TypeDetailView(types: [type])
        case .typeMatchup(let types):
            TypeDetailView(types: types)
        case .pokemonMoves(let id):
            if let pokemon = database.pokemon(id: id) { PokemonMovesView(pokemon: pokemon) } else { missing }
        case .faceOff(let id):
            FaceOffView(initial: id.flatMap(database.pokemon(id:)))
        case .usageDetail(let selection, let name):
            UsageDetailView(selection: selection, name: name)
        case .damageCalculator(let attacker, let defender):
            DamageCalculatorView(initialAttackerID: attacker, initialDefenderID: defender)
        }
    }

    private var missing: some View {
        ContentUnavailableView("Not Found", systemImage: "questionmark.circle", description: Text("This entry isn't in the Pokédex."))
    }
}

extension View {
    /// Registers destinations for every `AppRoute`. Apply once per `NavigationStack`.
    func appDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
    }
}
