import NeodexKit
import SwiftUI

extension PokedexDatabase {
    /// An empty database used as the environment default before data has loaded (and in previews).
    nonisolated static let empty = PokedexDatabase(pokemon: [], moves: [], abilities: [], items: [], learnsets: [:])
}

extension EnvironmentValues {
    /// The loaded Pokédex. Views below `RootView` can rely on it being fully populated.
    @Entry var database: PokedexDatabase = .empty
}
