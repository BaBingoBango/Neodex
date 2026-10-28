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

    /// `-neodexSeedSampleChats YES` fills an empty Dexbot list with chats spread over the past year,
    /// so the day grouping can be checked without waiting for real conversations to age.
    @MainActor
    static func seedSampleChatsIfRequested(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "neodexSeedSampleChats"),
              ((try? context.fetchCount(FetchDescriptor<DexbotConversation>())) ?? 0) == 0 else { return }
        let chats: [(daysAgo: Int, question: String, answer: String)] = [
            (0, "What is Garchomp weak to?",
             "**Garchomp** is Dragon/Ground, so Ice hits it for 4× damage, and Dragon and Fairy for 2×. It's immune to Electric."),
            (0, "Who's most used in OU right now?",
             "In September's Gen 9 OU statistics (1695+), **Great Tusk** leads at 33.1%, ahead of Kingambit and Gholdengo."),
            (1, "Best special Fire moves for Charizard",
             "**Fire Blast** hits hardest (110 power, 85% accuracy). **Flamethrower** (90, 100%) is the reliable choice, and Heat Wave hits both foes in doubles."),
            (3, "Can Kingambit learn Sucker Punch?",
             "Yes. Kingambit learns **Sucker Punch**, and its Supreme Overlord Ability makes it hit even harder late in a battle."),
            (20, "Is my team legal in OU?",
             "All six of your Pokémon are allowed in Gen 9 OU, and none of their moves, Abilities or items are banned."),
            (400, "Hello Dexbot!",
             "Hi! Ask me anything about Pokémon, moves, matchups, Smogon stats or your teams."),
        ]
        for (index, chat) in chats.enumerated() {
            let date = Date.now.addingTimeInterval(-Double(chat.daysAgo) * 86_400 - Double(index) * 3_600)
            let messages = [DexbotMessage(role: .user, text: chat.question), DexbotMessage(role: .dexbot, text: chat.answer)]
                .map { message in
                    var message = message
                    message.date = date
                    return message
                }
            let conversation = DexbotConversation(title: chat.question, messages: messages)
            conversation.createdAt = date
            conversation.updatedAt = date
            context.insert(conversation)
        }
        try? context.save()
    }
}
#endif
