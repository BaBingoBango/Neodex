import NeodexKit
import SwiftData
import SwiftUI

/// Every screen that can be pushed onto a navigation stack. Using a single route type lets any
/// view link to any entity with `NavigationLink(value: AppRoute.move("flamethrower"))`.
nonisolated enum AppRoute: Hashable, Codable, Identifiable {
    case pokemon(Pokemon.ID)
    case move(Move.ID)
    case moveLearners(Move.ID)
    case ability(Ability.ID)
    case item(Item.ID)
    case nature(Nature.ID)
    case type(PokemonType)
    case typeMatchup([PokemonType])
    /// Type-O-Matic, starting with these types chosen.
    case typeOMatic([PokemonType])
    /// The Pokédex filtered to one type.
    case typePokemon(PokemonType)
    case pokemonMoves(Pokemon.ID)
    /// Face-Off, starting with one or both Pokémon chosen.
    case faceOff(Pokemon.ID?, versus: Pokemon.ID? = nil)
    case usageDetail(UsageSelection, name: String)
    case damageCalculator(attacker: Pokemon.ID?, defender: Pokemon.ID?)
    case dexEntries(Pokemon.ID)
    case team(UUID)
    case usageStats(format: String?)
    case scan
    /// A sidebar feature in a window of its own.
    case feature(AppTab)

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
        case .typeOMatic(let types):
            TypeMatchupView(initial: types)
        case .typePokemon(let type):
            PokedexListContent(title: "\(type.name) Pokémon", filters: PokedexFilters(types: [type]))
        case .pokemonMoves(let id):
            if let pokemon = database.pokemon(id: id) { PokemonMovesView(pokemon: pokemon) } else { missing }
        case .faceOff(let id, let versus):
            FaceOffView(initial: id.flatMap(database.pokemon(id:)), versus: versus.flatMap(database.pokemon(id:)))
        case .usageDetail(let selection, let name):
            UsageDetailView(selection: selection, name: name)
        case .damageCalculator(let attacker, let defender):
            DamageCalculatorView(initialAttackerID: attacker, initialDefenderID: defender)
        case .dexEntries(let id):
            if let pokemon = database.pokemon(id: id) { PokedexEntriesView(pokemon: pokemon) } else { missing }
        case .team(let id):
            TeamRouteView(id: id)
        case .usageStats(let format):
            UsageStatsView()
                .task {
                    if let format { await UsageStatsModel.shared.prefer(formatID: format) }
                }
        case .scan:
            ScanView()
        case .feature(let tab):
            tab.content
        }
    }

    private var missing: some View {
        ContentUnavailableView("Not Found", systemImage: "questionmark.circle", description: Text("This entry isn't in the Pokédex."))
    }
}

/// Finds a saved team by ID for deep links from the Team widget.
struct TeamRouteView: View {
    @Query private var teams: [SavedTeam]

    init(id: UUID) {
        _teams = Query(filter: #Predicate<SavedTeam> { $0.id == id })
    }

    var body: some View {
        if let team = teams.first {
            TeamDetailView(team: team)
        } else {
            ContentUnavailableView("Team Not Found", systemImage: "rectangle.stack.person.crop",
                                   description: Text("This team has been deleted."))
        }
    }
}

extension View {
    /// Registers destinations for every `AppRoute`. Apply once per `NavigationStack`.
    func appDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
    }
}
