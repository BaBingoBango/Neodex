//
//  Move.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/12/20.
//

import Foundation

struct Move: Codable {
    
    // Enumerations
    enum CodingKeys: String, CodingKey {
        case name
        case type
        case category
        case description
        case power
        case accuracy
        case PP
        case maxPP
        case priority
        case discID
        case viaLevel
        case viaTM
        case viaEgg
        case viaTutor
    }
    
    // Variables
    
    // These variables define the characteristics of a Pokémon move
    var name: String
    var type: String
    var category: String
    var description: String
    var power: Int
    var accuracy: Int
    var PP: Int
    var maxPP: Int
    var priority: Int
    var discID: String
    
    // These variables define which Pokémon can learn the move in each of the four methods
    var viaLevel: [Method]
    var viaTM: [Method]
    var viaEgg: [Method]
    var viaTutor: [Method]
    
    // First three moves
    static let moveList: [Move] = [
        
        Move(name: "10,000,000 Volt Thunderbolt", type: "Electric", category: "Special", description: "The user, Pikachu wearing a cap, powers up a jolt of electricity using its Z-Power and unleashes it. Critical hits land more easily.", power: 195, accuracy: -1, PP: 1, maxPP: 1, priority: 0, discID: "", viaLevel: [], viaTM: [], viaEgg: [], viaTutor: []),

        Move(name: "Absorb", type: "Grass", category: "Special", description: "A nutrient-draining attack. The user’s HP is restored by half the damage taken by the target.", power: 20, accuracy: 100, PP: 25, maxPP: 40, priority: 0, discID: "", viaLevel: [Method(name: "Zubat", methodText: "1"), Method(name: "Golbat", methodText: "1"), Method(name: "Oddish", methodText: "1"), Method(name: "Gloom", methodText: "1"), Method(name: "Vileplume", methodText: "1"), Method(name: "Exeggcute", methodText: "1"), Method(name: "Exeggutor", methodText: "1"), Method(name: "Exeggutor-Alola", methodText: "1"), Method(name: "Tangela", methodText: "1"), Method(name: "Kabuto", methodText: "1"), Method(name: "Kabutops", methodText: "1"), Method(name: "Crobat", methodText: "1"), Method(name: "Bellossom", methodText: "1"), Method(name: "Lotad", methodText: "3"), Method(name: "Lombre", methodText: "1"), Method(name: "Ludicolo", methodText: "1"), Method(name: "Seedot", methodText: "3"), Method(name: "Nuzleaf", methodText: "1"), Method(name: "Shiftry", methodText: "1"), Method(name: "Nincada", methodText: "21"), Method(name: "Ninjask", methodText: "23"), Method(name: "Shedinja", methodText: "23"), Method(name: "Roselia", methodText: "1"), Method(name: "Budew", methodText: "1"), Method(name: "Roserade", methodText: "1"), Method(name: "Tangrowth", methodText: "1"), Method(name: "Cottonee", methodText: "1"), Method(name: "Whimsicott", methodText: "1"), Method(name: "Petilil", methodText: "1"), Method(name: "Lilligant", methodText: "1"), Method(name: "Maractus", methodText: "1"), Method(name: "Foongus", methodText: "1"), Method(name: "Amoonguss", methodText: "1"), Method(name: "Frillish", methodText: "1"), Method(name: "Jellicent", methodText: "1"), Method(name: "Joltik", methodText: "1"), Method(name: "Galvantula", methodText: "1"), Method(name: "Shelmet", methodText: "1"), Method(name: "Accelgor", methodText: "1"), Method(name: "Goomy", methodText: "1"), Method(name: "Sliggoo", methodText: "1"), Method(name: "Goodra", methodText: "1"), Method(name: "Noibat", methodText: "1"), Method(name: "Noivern", methodText: "1"), Method(name: "Cutiefly", methodText: "1"), Method(name: "Ribombee", methodText: "1"), Method(name: "Morelull", methodText: "1"), Method(name: "Shiinotic", methodText: "1"), Method(name: "Sandygast", methodText: "1"), Method(name: "Palossand", methodText: "1"), Method(name: "Dhelmise", methodText: "1"), Method(name: "Celesteela", methodText: "1")], viaTM: [], viaEgg: [Method(name: "Treecko", methodText: ""), Method(name: "Larvesta", methodText: ""), Method(name: "Volcarona", methodText: "")], viaTutor: []),

        Move(name: "Accelerock", type: "Rock", category: "Physical", description: "The user smashes into the target at high speed. This move always goes first.", power: 40, accuracy: 100, PP: 20, maxPP: 32, priority: 1, discID: "", viaLevel: [Method(name: "Lycanroc", methodText: "1"), Method(name: "Lycanroc-Dusk", methodText: "1")], viaTM: [], viaEgg: [], viaTutor: [])
        
    ]
    
    // Functions
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(category, forKey: .category)
        try container.encode(description, forKey: .description)
        try container.encode(power, forKey: .power)
        try container.encode(accuracy, forKey: .accuracy)
        try container.encode(PP, forKey: .PP)
        try container.encode(maxPP, forKey: .maxPP)
        try container.encode(priority, forKey: .priority)
        try container.encode(discID, forKey: .discID)
        try container.encode(viaLevel, forKey: .viaLevel)
        try container.encode(viaTM, forKey: .viaTM)
        try container.encode(viaEgg, forKey: .viaEgg)
        try container.encode(viaTutor, forKey: .viaTutor)
    }
    static func moveLookup(name: String) -> Move {
        for eachMove in moveDataList {
            if eachMove.name == name {
                return eachMove
            }
        }
        return moveDataList[0]
    }
    
}

extension Move {
    // Initalizer
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        type = try values.decode(String.self, forKey: .type)
        category = try values.decode(String.self, forKey: .category)
        description = try values.decode(String.self, forKey: .description)
        power = try values.decode(Int.self, forKey: .power)
        accuracy = try values.decode(Int.self, forKey: .accuracy)
        PP = try values.decode(Int.self, forKey: .PP)
        maxPP = try values.decode(Int.self, forKey: .maxPP)
        priority = try values.decode(Int.self, forKey: .priority)
        discID = try values.decode(String.self, forKey: .discID)
        viaLevel = try values.decode([Method].self, forKey: .viaLevel)
        viaTM = try values.decode([Method].self, forKey: .viaTM)
        viaEgg = try values.decode([Method].self, forKey: .viaEgg)
        viaTutor = try values.decode([Method].self, forKey: .viaTutor)
    }
}

struct Method: Codable {
    
    // Variables
    var name: String
    var methodText: String
    
}
