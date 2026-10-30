import Foundation
import NeodexKit
import Testing
@testable import Neodex

/// Routes that open in new windows, and Pokémon carried in a drag.
@Suite("Entry windows and dragging")
struct EntryActionsTests {
    @Test("Routes survive the trip through a window's saved state")
    func routesRoundTrip() throws {
        for route: AppRoute in [.faceOff("garchomp"), .faceOff("garchomp", versus: "dragapult"), .faceOff(nil), .feature(.pokedex)] {
            let data = try JSONEncoder().encode(route)
            #expect(try JSONDecoder().decode(AppRoute.self, from: data) == route)
        }
    }

    @Test("A Face-Off window saved before Face-Off took two Pokémon still opens")
    func decodesOldFaceOff() throws {
        let saved = Data(#"{"faceOff":{"_0":"garchomp"}}"#.utf8)
        #expect(try JSONDecoder().decode(AppRoute.self, from: saved) == .faceOff("garchomp"))
    }

    @Test("A dragged Pokémon travels as its Neodex link, and other links are ignored")
    func dragLinks() throws {
        let url = PokemonDrag.url(for: "garchomp")
        #expect(url.absoluteString == "neodex://pokemon/garchomp")
        #expect(PokemonDrag.pokemonID(in: url) == "garchomp")
        #expect(PokemonDrag.pokemonID(in: try #require(URL(string: "neodex://team/1234"))) == nil)
        #expect(PokemonDrag.pokemonID(in: try #require(URL(string: "https://pokemon.example/garchomp"))) == nil)
    }
}
