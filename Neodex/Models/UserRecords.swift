//
//  UserRecords.swift
//  Neodex
//
//  Created by Ethan Marshall on 6/9/21.
//

import Foundation

struct UserRecords: Codable {
    
    // MARK: Enumerations
    enum CodingKeys: String, CodingKey {
        case pokemonHistory
        case abilityHistory
        case moveHistory
        case itemHistory
        case hasIndexedPokemon
        case hasIndexedMoves
        case hasIndexedAbilities
        case hasIndexedNatures
        case hasIndexedItems
        case firstTimeIndex
    }
    
    // MARK: Misc. variables
    var firstTimeIndex: Bool = false
    
    // MARK: User browsing history variables
    var pokemonHistory: [Pokemon]
    var abilityHistory: [Ability]
    var moveHistory: [Move]
    var itemHistory: [Item]
    
    // MARK: User preference variables
    var hasIndexedPokemon = false {
        didSet {
            workingOnPokemonSP = true
            if hasIndexedPokemon == true {
                DispatchQueue.main.async {
                    SpotlightServices.indexPokemon()
                }
            } else {
                DispatchQueue.main.async {
                    SpotlightServices.deIndexPokemon()
                }
            }
            workingOnPokemonSP = false
        }
    }
    var hasIndexedMoves = false {
        didSet {
            workingOnMovesSP = true
            if hasIndexedMoves == true {
                DispatchQueue.main.async {
                    SpotlightServices.indexMoves()
                }
            } else {
                DispatchQueue.main.async {
                    SpotlightServices.deIndexMoves()
                }
            }
            workingOnMovesSP = false
        }
    }
    var hasIndexedAbilities = false {
        didSet {
            workingOnAbilitiesSP = true
            if hasIndexedAbilities == true {
                DispatchQueue.main.async {
                    SpotlightServices.indexAbilities()
                }
            } else {
                DispatchQueue.main.async {
                    SpotlightServices.deIndexAbilities()
                }
            }
            workingOnAbilitiesSP = false
        }
    }
    var hasIndexedNatures = false {
        didSet {
            workingOnNaturesSP = true
            if hasIndexedNatures == true {
                DispatchQueue.main.async {
                    SpotlightServices.indexNatures()
                }
            } else {
                DispatchQueue.main.async {
                    SpotlightServices.deIndexNatures()
                }
            }
            workingOnNaturesSP = false
        }
    }
    var hasIndexedItems = false {
        didSet {
            workingOnItemsSP = true
            if hasIndexedItems == true {
                DispatchQueue.main.async {
                    SpotlightServices.indexItems()
                }
            } else {
                DispatchQueue.main.async {
                    SpotlightServices.deIndexItems()
                }
            }
            workingOnItemsSP = false
        }
    }
    
    // MARK: Functions to get the user's most viewed items of each data type
    func reportPokemonUsage() -> [(Pokemon, Int)] {
        var answer: [(Pokemon, Int)] = []
        for eachPokemon in pokemonDataList {
            answer.append((eachPokemon, pokemonViews(eachPokemon)))
        }
        answer.sort(by: {
            return $0.1 > $1.1
        })
        return answer
    }
    
    func reportAbilityUsage() -> [(Ability, Int)] {
        var answer: [(Ability, Int)] = []
        for eachAbility in Ability.abilityList {
            answer.append((eachAbility, abilityViews(eachAbility)))
        }
        answer.sort(by: {
            return $0.1 > $1.1
        })
        return answer
    }
    
    func reportMoveUsage() -> [(Move, Int)] {
        var answer: [(Move, Int)] = []
        for eachMove in moveDataList {
            answer.append((eachMove, moveViews(eachMove)))
        }
        answer.sort(by: {
            return $0.1 > $1.1
        })
        return answer
    }
    
    func reportItemUsage() -> [(Item, Int)] {
        var answer: [(Item, Int)] = []
        for eachItem in Item.itemList {
            answer.append((eachItem, itemViews(eachItem)))
        }
        answer.sort(by: {
            return $0.1 > $1.1
        })
        return answer
    }
    
    // MARK: Functions to see how often a user has viewed a certain data item
    func pokemonViews(_ pokemon: Pokemon) -> Int {
        var answer = 0
        for eachPokemon in pokemonHistory {
            if eachPokemon.name == pokemon.name {
                answer += 1
            }
        }
        return answer
    }
    func abilityViews(_ ability: Ability) -> Int {
        var answer = 0
        for eachAbility in abilityHistory {
            if eachAbility.name == ability.name {
                answer += 1
            }
        }
        return answer
    }
    func moveViews(_ move: Move) -> Int {
        var answer = 0
        for eachMove in moveHistory {
            if eachMove.name == move.name {
                answer += 1
            }
        }
        return answer
    }
    func itemViews(_ item: Item) -> Int {
        var answer = 0
        for eachItem in itemHistory {
            if eachItem.name == item.name {
                answer += 1
            }
        }
        return answer
    }
    
    // MARK: Records analysis
    
    func reccomend5Pokemon(usage: [(Pokemon, Int)]) -> [Pokemon] {
        // Find the types of the user's 5 most viewed pokemon
        let pokemonUsage = usage
        let top5types: [String] = [pokemonUsage[0].0.type1, pokemonUsage[1].0.type1, pokemonUsage[2].0.type1, pokemonUsage[3].0.type1, pokemonUsage[4].0.type1]
        
        // From the pokemon master list, remove the user's top 5
        var pokemonMasterList = pokemonDataList
        pokemonMasterList = pokemonMasterList.filter({
            $0.name != pokemonUsage[0].0.name && $0.name != pokemonUsage[1].0.name && $0.name != pokemonUsage[2].0.name && $0.name != pokemonUsage[3].0.name && $0.name != pokemonUsage[4].0.name
        })
        
        // For each of the top 5 types, choose a random pokemon of that same type. Then, remove it from the master list.
        var recs: [Pokemon] = []
        for eachType in top5types {
            let chosen = pokemonMasterList.filter({ $0.type1 == eachType || $0.type2 == eachType }).randomElement() ?? pokemonMasterList[0]
            recs.append(chosen)
            pokemonMasterList = pokemonMasterList.filter({ $0.name != chosen.name })
        }
        
        // Return.
        return recs
        
    }
    
    func reccomend5Abilities(usage: [(Ability, Int)]) -> [Ability] {
        // Literally just remove the user's 5 most popular abilities from the master list and then pick 5 random ones lmao
        var abilityMasterList = Ability.abilityList
        abilityMasterList = abilityMasterList.filter({
            $0.name != usage[0].0.name && $0.name != usage[1].0.name && $0.name != usage[2].0.name && $0.name != usage[3].0.name && $0.name != usage[4].0.name
        })
        var recs: [Ability] = []
        for _ in 1...5 {
            let randIndex = abilityMasterList.indices.randomElement()!
            recs.append(abilityMasterList[randIndex])
            abilityMasterList.remove(at: randIndex)
        }
        return recs
    }
    
    func reccomend5Items(usage: [(Item, Int)]) -> [Item] {
        // Find the categories of the user's 5 most viewed items
        let itemUsage = usage
        let top5Categories: [ItemType] = [itemUsage[0].0.category, itemUsage[1].0.category, itemUsage[2].0.category, itemUsage[3].0.category, itemUsage[4].0.category]
        
        // From the item master list, remove the user's top 5
        var itemMasterList = Item.itemList
        itemMasterList = itemMasterList.filter({
            $0.name != itemUsage[0].0.name && $0.name != itemUsage[1].0.name && $0.name != itemUsage[2].0.name && $0.name != itemUsage[3].0.name && $0.name != itemUsage[4].0.name
        })
        
        // For each of the top 5 categories, choose a random category of that same type. Then, remove it from the master list.
        var recs: [Item] = []
        for eachCategory in top5Categories {
            let chosen = itemMasterList.filter({ $0.category == eachCategory }).randomElement() ?? itemMasterList[0]
            recs.append(chosen)
            itemMasterList = itemMasterList.filter({ $0.name != chosen.name })
        }
        
        // Return.
        return recs
    }
    
    // MARK: Inits & Coding
    init() {
        pokemonHistory = []
        abilityHistory = []
        moveHistory = []
        itemHistory = []
        firstTimeIndex = false
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        pokemonHistory = try values.decode([Pokemon].self, forKey: .pokemonHistory)
        abilityHistory = try values.decode([Ability].self, forKey: .abilityHistory)
        moveHistory = try values.decode([Move].self, forKey: .moveHistory)
        itemHistory = try values.decode([Item].self, forKey: .itemHistory)
        hasIndexedPokemon = try values.decode(Bool.self, forKey: .hasIndexedPokemon)
        hasIndexedMoves  = try values.decode(Bool.self, forKey: .hasIndexedMoves)
        hasIndexedAbilities  = try values.decode(Bool.self, forKey: .hasIndexedAbilities)
        hasIndexedNatures  = try values.decode(Bool.self, forKey: .hasIndexedNatures)
        hasIndexedItems = try values.decode(Bool.self, forKey: .hasIndexedItems)
        firstTimeIndex = try values.decode(Bool.self, forKey: .firstTimeIndex)
        
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pokemonHistory, forKey: .pokemonHistory)
        try container.encode(abilityHistory, forKey: .abilityHistory)
        try container.encode(moveHistory, forKey: .moveHistory)
        try container.encode(itemHistory, forKey: .itemHistory)
        try container.encode(hasIndexedPokemon, forKey: .hasIndexedPokemon)
        try container.encode(hasIndexedMoves, forKey: .hasIndexedMoves)
        try container.encode(hasIndexedAbilities, forKey: .hasIndexedAbilities)
        try container.encode(hasIndexedNatures, forKey: .hasIndexedNatures)
        try container.encode(hasIndexedItems, forKey: .hasIndexedItems)
        try container.encode(firstTimeIndex, forKey: .firstTimeIndex)
    }
    
}
