//
//  Team.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/31/21.
//

import Foundation
import JavaScriptCore

struct Team: Codable, Identifiable {
    
    // Enumerations
    enum CodingKeys: String, CodingKey {
        case name
        case members
    }
    
    
    // Variables
    var context = JSContext()
    var id = UUID()
    var name: String = "New Team" // Default team name
    var members: [TeamMember?] = [nil, nil, nil, nil, nil, nil] // A new team begins with 6 empty slots
    
    // Functions
    func export() -> String {
        
        var answer = ""
        
        for eachMember in self.members {
            
            if eachMember != nil {
                
                answer += "\(eachMember!.export())\n\n"
                
            }
            
        }
        
        return answer
        
    }
    static func importTeam(input: String) -> Team {
        
        // Prepare the JS file
        let context = generateJSContext()
        loadJSBundle(for: context)
        
        // Create and load up the Team object
        var team = Team()
        context?.setObject(input, forKeyedSubscript: "teamCode" as NSCopying & NSObjectProtocol)
        team.name = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].name")?.toString() ?? "Untitled"
        
        team.members = []
        for i in 0..<(context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon")?.toArray() ?? []).count {
            team.members.append(TeamMember.importMember(input: context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[\(i)]")?.toString() ?? ""))
        }
        for _ in 0..<(6 - team.members.count) {
            team.members.append(nil)
        }
        
        // Return the Team object
        return team
        
    }
    // MARK: JAVASCRIPT FUNCTIONS
    static func generateJSContext() -> JSContext? {
        
        let context = JSContext()
        
        context?.evaluateScript("var console = { log: function(message) { _consoleLog(message) } }")
        
        let consoleLog: (String) -> Void = { message in
            print("JS Log: \(message)")
        }
        context?.setObject(consoleLog, forKeyedSubscript: "_consoleLog" as NSCopying & NSObjectProtocol)
        
        context?.exceptionHandler = { context, exception in
            print("JS Error: \(exception.debugDescription)")
        }
        
        return context
        
    }
    static func loadJSBundle(for context: JSContext?) {
        
        guard let libraryPath = Bundle.main.path(forResource: "koffingbundle", ofType: "js"),
            let libraryCode = try? String(contentsOfFile: libraryPath) else {
                return
        }
        
        context?.evaluateScript(libraryCode)
        
    }
    static func calculateStat(member: TeamMember, index: Int) -> Int {
        
        let level = member.level
        let base = member.pokemon.baseStats[index]
        let EV = member.EVs[index]
        let IV = member.IVs[index]
        
        if index == 0 {
            
            // Use the HP stat formula to calculate the total HP value
            let EV4 = Int(Double(EV) / 4.0)
            let numerator = (2.0 * Double(base) + Double(IV) + Double(EV4)) * Double(level)
            let fraction = Int(numerator / 100.0)
            let HP = fraction + level + 10
            return HP
            
        } else {
            
            // Use the general formula to calculate the total stat value
            let EV4 = Int(Double(EV) / 4.0)
            let numerator = (2.0 * Double(base) + Double(IV) + Double(EV4)) * Double(level)
            let fraction = Int(numerator / 100.0)
            let stat = Int(Double(fraction + 5) * getNatureValue(member: member, index: index))
            return stat
            
        }
        
    }
    func getNumMembers() -> Int {
        var answer = 0
        
        if self.members[0] != nil {
            answer += 1
        }
        if self.members[1] != nil {
            answer += 1
        }
        if self.members[2] != nil {
            answer += 1
        }
        if self.members[3] != nil {
            answer += 1
        }
        if self.members[4] != nil {
            answer += 1
        }
        if self.members[5] != nil {
            answer += 1
        }
        
        return answer
    }
    
    func getTypesUsed() -> Int {
        var uniqueTypes = [String]()
        
        for eachMember in self.members {
            if eachMember != nil {
                if !uniqueTypes.contains(eachMember!.pokemon.type1) {
                    uniqueTypes.append(eachMember!.pokemon.type1)
                }
                
                if eachMember!.pokemon.type2 != "" {
                    if !uniqueTypes.contains(eachMember!.pokemon.type2) {
                        uniqueTypes.append(eachMember!.pokemon.type2)
                    }
                }
            }
        }
        
        return uniqueTypes.count
    }
    
    func getSumStatTotal() -> Int {
        var answer = 0
        
        for eachMember in self.members {
            if eachMember != nil {
                
                answer += (Team.calculateStat(member: eachMember!, index: 0) + Team.calculateStat(member: eachMember!, index: 1) + Team.calculateStat(member: eachMember!, index: 2) + Team.calculateStat(member: eachMember!, index: 3) + Team.calculateStat(member: eachMember!, index: 4) + Team.calculateStat(member: eachMember!, index: 5))
                
            }
        }
        
        return answer
    }
    
    func getSingleStatTotal(index: Int) -> Int {
        var answer = 0
        
        for eachMember in self.members {
            if eachMember != nil {
                
                answer += Team.calculateStat(member: eachMember!, index: index)
                
            }
        }
        
        return answer
    }
    
    func getResistantMembers(type: String) -> Int {
        var answer = 0
        
        for eachMember in self.members {
            if eachMember != nil {
                
                // Check single types
                if eachMember!.pokemon.type2 == "" {
                    
                    let typeLookup = Type.typeLookup(name: eachMember!.pokemon.type1)!
                    
                    if typeLookup.resistances.contains(type) || typeLookup.immunities.contains(type) {
                        answer += 1
                    }
                    
                } else {

                    let typeLookup1 = Type.typeLookup(name: eachMember!.pokemon.type1)!
                    let typeLookup2 = Type.typeLookup(name: eachMember!.pokemon.type2)!
                    
                    // Check double types
                    if DualTypeEngine.resistant(type1: typeLookup1, type2: typeLookup2).contains(where: { $0.name == type }) || DualTypeEngine.hyperresistant(type1: typeLookup1, type2: typeLookup2).contains(where: { $0.name == type }) || DualTypeEngine.immune(type1: typeLookup1, type2: typeLookup2).contains(where: { $0.name == type }) {
                        
                        answer += 1
                        
                    }
                    
                }
                
            }
        }
        
        return answer
    }
    
    func getWeakMembers(type: String) -> Int {
        var answer = 0
        
        for eachMember in self.members {
            if eachMember != nil {
                
                // Check single types
                if eachMember!.pokemon.type2 == "" {
                    
                    let typeLookup = Type.typeLookup(name: eachMember!.pokemon.type1)!
                    
                    if typeLookup.weaknesses.contains(type) {
                        answer += 1
                    }
                    
                } else {

                    let typeLookup1 = Type.typeLookup(name: eachMember!.pokemon.type1)!
                    let typeLookup2 = Type.typeLookup(name: eachMember!.pokemon.type2)!
                    
                    // Check double types
                    if DualTypeEngine.weak(type1: typeLookup1, type2: typeLookup2).contains(where: { $0.name == type }) || DualTypeEngine.hyperweak(type1: typeLookup1, type2: typeLookup2).contains(where: { $0.name == type }) {
                        
                        answer += 1
                        
                    }
                    
                }
                
            }
        }
        
        return answer
    }
    
    // Initializers
    init() {
        name = "New Team"
        members = [nil, nil, nil, nil, nil, nil]
    }
    init(name: String, members: [TeamMember?]) {
        self.name = name
        self.members = members
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        members = try values.decode([TeamMember?].self, forKey: .members)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(members, forKey: .members)
    }
    
    static func getNatureValue(member: TeamMember, index: Int) -> Double {
        
        // Return 1.0 if the team member has a neutral nature
        if member.nature.plus == member.nature.minus {
            return 1.0
        }
        
        // Determine the stat being calculated
        var stat = ""
        switch index {
        case 1:
            stat = "Attack"
        case 2:
            stat = "Sp. Atk"
        case 3:
            stat = "Defense"
        case 4:
            stat = "Sp. Def"
        case 5:
            stat = "Speed"
        default:
            stat = "???"
        }
        
        if stat == member.nature.plus {
            return 1.1
        } else if stat == member.nature.minus {
            return 0.9
        } else {
            return 1.0
        }
        
    }
    
}

struct TeamMember: Codable {
    
    // Enumerations
    enum CodingKeys: String, CodingKey {
        case pokemon
        case name
        case nickname
        case level
        case gender
        case isShiny
        case item
        case ability
        case moves
        case EVs
        case IVs
        case nature
    }
    
    // Variables
    var context = JSContext()
    var pokemon: Pokemon
    var name: String
    var nickname: String
    var level: Int
    var gender: String
    var isShiny: Bool
    var item: String
    var ability: String
    var moves: [Move?]
    var EVs: [Int]
    var IVs: [Int]
    var nature: Nature
    
    // Initalizers
    init(pokemon: Pokemon) {
        
        self.pokemon = pokemon
        name = pokemon.name
        nickname = pokemon.name // Default nickname is the pokemon's name
        level = 100 // Default level is 50
        
        // Sets gender to male if male rate is 50%+, female otherwise
        if pokemon.maleRate < 0 {
            gender = "Genderless"
        } else if pokemon.maleRate >= 50 {
            gender = "Male"
        } else {
            gender = "Female"
        }
        
        isShiny = false // Not shiny by default
        item = "" // Blank string denotes no item (by default)
        ability = pokemon.ability1 // Use first ability by default
        moves = [nil, nil, nil, nil] // No moves by default
        EVs = [0, 0, 0, 0, 0, 0] // No EV investment by default
        IVs = [31, 31, 31, 31, 31, 31] // Max IVs by default
        nature = Nature(name: "Serious", plus: "Speed", minus: "Speed") // Serious by default
        
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        pokemon = try values.decode(Pokemon.self, forKey: .pokemon)
        name = try values.decode(String.self, forKey: .name)
        nickname = try values.decode(String.self, forKey: .nickname)
        level = try values.decode(Int.self, forKey: .level)
        gender = try values.decode(String.self, forKey: .gender)
        isShiny = try values.decode(Bool.self, forKey: .isShiny)
        item = try values.decode(String.self, forKey: .item)
        ability = try values.decode(String.self, forKey: .ability)
        moves = try values.decode([Move?].self, forKey: .moves)
        EVs = try values.decode([Int].self, forKey: .EVs)
        IVs = try values.decode([Int].self, forKey: .IVs)
        nature = try values.decode(Nature.self, forKey: .nature)
    }
    
    // MARK: JAVASCRIPT FUNCTIONS
    static func generateJSContext() -> JSContext? {
        
        let context = JSContext()
        
        context?.evaluateScript("var console = { log: function(message) { _consoleLog(message) } }")
        
        let consoleLog: (String) -> Void = { message in
            print("JS Log: \(message)")
        }
        context?.setObject(consoleLog, forKeyedSubscript: "_consoleLog" as NSCopying & NSObjectProtocol)
        
        context?.exceptionHandler = { context, exception in
            print("JS Error: \(exception.debugDescription)")
        }
        
        return context
        
    }
    static func loadJSBundle(for context: JSContext?) {
        
        guard let libraryPath = Bundle.main.path(forResource: "koffingbundle", ofType: "js"),
            let libraryCode = try? String(contentsOfFile: libraryPath) else {
                return
        }
        
        context?.evaluateScript(libraryCode)
        
    }
    
    // Functions
    static func importMember(input: String) -> TeamMember {
        
        // Prepare the JS file
        let context = generateJSContext()
        loadJSBundle(for: context)
        
        // Create a TeamMember object
        var answer = TeamMember(pokemon: pokemonDataList[0])
        
        // Run the Koffing function to parse the team and set the TeamMember variables
        context?.setObject(input, forKeyedSubscript: "teamCode" as NSCopying & NSObjectProtocol)
        
        var parsedPokemonName = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].name")?.toString() ?? "Bulbasaur"
        if parsedPokemonName.contains("-Mega") {
            let realName = parsedPokemonName.prefix(upTo: parsedPokemonName.firstIndex(of: "-")!)
            parsedPokemonName = "Mega \(realName)"
        } else if parsedPokemonName.contains("-Alola") {
            let realName = parsedPokemonName.prefix(upTo: parsedPokemonName.firstIndex(of: "-")!)
            parsedPokemonName = "Alolan \(realName)"
        }
        answer.pokemon = pokemonDataList[pokemonDataList.firstIndex(where: { $0.name == parsedPokemonName }) ?? 0]
        
        answer.name = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].name")?.toString() ?? "Bulbasaur"
        
        answer.nickname = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].nickname")?.toString() ?? context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].name")?.toString() ?? "Bulbasaur"
        if answer.nickname == "undefined" { answer.nickname = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].name")?.toString() ?? "Bulbasaur" }
        
        answer.level = Int(context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].level")?.toInt32() ?? 100)
        if answer.level == 0 { answer.level = 100 }
        
        answer.gender = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].gender")?.toString() ?? "Male"
        if answer.gender == "M" { answer.gender = "Male" }; if answer.gender == "F" { answer.gender = "Female" }; if answer.gender == "undefined" { if answer.pokemon.maleRate < 0 { answer.gender = "Genderless" } else if answer.pokemon.maleRate >= 50 { answer.gender = "Male" } else { answer.gender = "Female" } }
        
        answer.isShiny = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].shiny")?.toBool() ?? false
        
        answer.item = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].item")?.toString() ?? ""
        if answer.item == "undefined" { answer.item = "" }
        
        answer.ability = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].ability")?.toString() ?? pokemonDataList[pokemonDataList.firstIndex(where: { $0.name == context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].name")?.toString() }) ?? 0].ability1
        if answer.ability == "undefined" { answer.ability = answer.pokemon.ability1 }
        
        let importedMoves: [String] = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].moves")?.toArray() as! [String]
        for index in 0...3 {
            if importedMoves.count - 1 >= index {
                answer.moves[index] = Move.moveLookup(name: importedMoves[index])
                if (answer.moves[index]!.name == "Vine Whip") && (importedMoves[index] != "Vine Whip") {
                    answer.moves[index] = nil
                }
            }
        }
        
        if context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].evs")?.toDictionary() != nil {
            let EVdict = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].evs")?.toDictionary() as! [String: Int]
            for (stat, value) in EVdict {
                var index = -1
                switch stat {
                case "hp": index = 0
                case "atk": index = 1
                case "def": index = 2
                case "spa": index = 3
                case "spd": index = 4
                case "spe": index = 5
                default: index = -1
                }
                if index != -1 {
                    answer.EVs[index] = value
                }
            }
        }
        
        if context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].ivs")?.toDictionary() != nil {
            let IVdict = context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].ivs")?.toDictionary() as! [String: Int]
            for (stat, value) in IVdict {
                var index = -1
                switch stat {
                case "hp": index = 0
                case "atk": index = 1
                case "def": index = 2
                case "spa": index = 3
                case "spd": index = 4
                case "spe": index = 5
                default: index = -1
                }
                if index != -1 {
                    answer.IVs[index] = value
                }
            }
        }
        
        answer.nature = Nature.natureList[Nature.natureList.firstIndex(where: { $0.name == context?.evaluateScript("KOFFING.Koffing.parse(teamCode).teams[0].pokemon[0].nature")?.toString() }) ?? 23]
        
        // Return the TeamMember object
        return answer
        
    }
    
    func export() -> String {
        
        // This function encodes the team into a string to be exported to Showdown
        
        var answer = ""
        
        // LINE 1: Nickname (Pokemon) (gender) @ Item
        
        if !self.pokemon.name.contains("Alolan") {
            if self.nickname == self.pokemon.name {
                answer += "\(self.pokemon.name)"
            } else {
                answer += "\(self.nickname) (\(self.pokemon.name))"
            }
        } else {
            if self.nickname == self.pokemon.name {
                answer += "\(self.pokemon.name.suffix(7))-Alola"
            } else {
                answer += "\(self.nickname) (\(self.pokemon.name.suffix(7)))-Alola"
            }
        }
        
        if self.gender == "Male" {
            answer += " (M)"
        } else if self.gender == "Female" {
            answer += " (F)"
        }
        
        if self.item != "" {
            answer += " @ \(self.item)"
        }
        
        // LINE 2: Ability
        answer += "\nAbility: \(self.ability)"
        
        // LINE 3: Level
        answer += "\nLevel: \(self.level)"
        
        // LINE 4: Shiny status
        if self.isShiny {
            answer += "\nShiny: Yes"
        }
        
        // LINE 5: EVs
        var hasSetTitle = false
        
        for index in 0...5 {
            var statName = ""
            switch index {
            case 0: statName = "HP"
            case 1: statName = "Atk"
            case 2: statName = "Def"
            case 3: statName = "SpA"
            case 4: statName = "SpD"
            case 5: statName = "Spe"
            default: statName = ""
            }
            
            if self.EVs[index] != 0 {
                if !hasSetTitle {
                    answer += "\nEVs: "
                    hasSetTitle = true
                }
                answer += "\(self.EVs[index]) \(statName)"
                answer += " / "
            }
        }
        
        if answer.suffix(2) == "/ " {
            answer = String(answer.prefix(answer.count - 3))
        }
        
        // LINE 6: Nature
        answer += "\n\(self.nature.name) Nature"
        
        // LINE 7: IVs
        var hasSetTitle2 = false
        
        for index in 0...5 {
            var statName = ""
            switch index {
            case 0: statName = "HP"
            case 1: statName = "Atk"
            case 2: statName = "Def"
            case 3: statName = "SpA"
            case 4: statName = "SpD"
            case 5: statName = "Spe"
            default: statName = ""
            }
            
            if self.IVs[index] != 31 {
                if !hasSetTitle2 {
                    answer += "\nIVs: "
                    hasSetTitle2 = true
                }
                answer += "\(self.IVs[index]) \(statName)"
                answer += " / "
            }
        }
        
        if answer.suffix(2) == "/ " {
            answer = String(answer.prefix(answer.count - 3))
        }
        
        // LINES 8, 9, 10, AND 11
        if self.moves[0] != nil {
            answer += "\n- \(self.moves[0]!.name)"
        }
        if self.moves[1] != nil {
            answer += "\n- \(self.moves[1]!.name)"
        }
        if self.moves[2] != nil {
            answer += "\n- \(self.moves[2]!.name)"
        }
        if self.moves[3] != nil {
            answer += "\n- \(self.moves[3]!.name)"
        }
        
        return answer
        
    }
    
    func getStatTotal() -> Int {
        var answer = 0
        
        for eachIndex in 0...5 {
            
            answer += Team.calculateStat(member: self, index: eachIndex)
            
        }
        
        return answer
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pokemon, forKey: .pokemon)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(level, forKey: .level)
        try container.encode(gender, forKey: .gender)
        try container.encode(isShiny, forKey: .isShiny)
        try container.encode(item, forKey: .item)
        try container.encode(ability, forKey: .ability)
        try container.encode(moves, forKey: .moves)
        try container.encode(EVs, forKey: .EVs)
        try container.encode(IVs, forKey: .IVs)
        try container.encode(nature, forKey: .nature)
    }
    
}

struct ParsedPokemon {
    
    // Variables
    var name: String
    var item: String
    var ability: String
    var nature: String
    var evs: [String: Int]
    var moves: [String]
    
}
