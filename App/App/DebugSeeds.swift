#if DEBUG
import Foundation
import NeodexKit
import SwiftData

/// Development helpers that run only when a launch argument asks for them.
enum DebugSeeds {
    /// `-neodexSeedSampleTeam YES` puts one finished team into an empty store, so a simulator has
    /// something to send to the watch without tapping through the Teambuilder.
    @MainActor
    static func seedSampleTeamIfRequested(context: ModelContext, database: PokedexDatabase) {
        guard UserDefaults.standard.bool(forKey: "neodexSeedSampleTeam"),
              ((try? context.fetchCount(FetchDescriptor<SavedTeam>())) ?? 0) == 0 else { return }
        let picks: [(pokemon: String, item: String?, moves: [String])] = [
            ("garchomp", "lifeorb", ["earthquake", "dragonclaw", "swordsdance", "scaleshot"]),
            ("incineroar", "sitrusberry", ["fakeout", "flareblitz", "knockoff", "partingshot"]),
            ("rillaboom", "assaultvest", ["grassyglide", "woodhammer", "uturn", "knockoff"]),
            ("fluttermane", "choicespecs", ["moonblast", "shadowball", "thunderbolt", "icywind"]),
            ("amoonguss", "rockyhelmet", ["spore", "ragepowder", "pollenpuff", "protect"]),
            ("urshifurapidstrike", "choiceband", ["surgingstrikes", "closecombat", "aquajet", "uturn"]),
        ]
        var members: [TeamMember] = []
        for pick in picks {
            guard let pokemon = database.pokemon(id: pick.pokemon) else { continue }
            var member = TeamMember(pokemon: pokemon)
            member.level = 50
            member.itemID = pick.item.flatMap { database.item(id: $0)?.id }
            member.moveIDs = pick.moves.map { database.move(id: $0)?.id }
            members.append(member)
        }
        context.insert(SavedTeam(name: "Simulator Team", format: "gen9vgc2026", members: members))
        try? context.save()
    }
}
#endif
