import Foundation
import NeodexKit
import Testing
@testable import Neodex

/// The Pokémon that Siri and Shortcuts know by name.
@Suite("Siri's Pokémon")
@MainActor
struct ShortcutPokemonTests {
    @Test("Siri's phrases name favorites first, newest first, then well-known Pokémon")
    func picksShortcutPokemon() {
        let picked = ShortcutPokemon.pick(favorites: ["tinkaton", "zubat", "charizard"], limit: 6)
        #expect(picked == ["charizard", "zubat", "tinkaton", "pikachu", "eevee", "mewtwo"])
        #expect(ShortcutPokemon.pick(favorites: []) == ShortcutPokemon.wellKnown)

        // However many favorites, the phrases stay well inside the system's 1,000.
        let many = (1...200).map { "pokemon\($0)" }
        #expect(ShortcutPokemon.pick(favorites: many).count == ShortcutPokemon.limit)
        #expect(ShortcutPokemon.pick(favorites: many).first == "pokemon200")
    }

    @Test("Every well-known Pokémon is in the Pokédex, once")
    func wellKnownPokemonExist() async throws {
        let database = try await DatabaseProvider.shared.database()
        for id in ShortcutPokemon.wellKnown {
            #expect(database.pokemon(id: id) != nil, "\(id) isn't a Pokémon")
        }
        #expect(Set(ShortcutPokemon.wellKnown).count == ShortcutPokemon.wellKnown.count)
        #expect(ShortcutPokemon.wellKnown.count == ShortcutPokemon.limit)
    }
}
