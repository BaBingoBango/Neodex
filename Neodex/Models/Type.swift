//
//  Type.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/16/20.
//

import Foundation

// This structure defines a Pokémon type - it is weak and resistant to other types (defense), as well as effective and not effective against other types (attack). When combined with another type, a dual type is created. Dual types can be held by Pokémon, but not moves. The weak report of a dual type is simply the components of the two types' weak reports added. Thus, dual types can have hyperweaknesses and hyperresistances, while single types cannot. Dual types cannot ne held by a move, and thus have no attack information.

struct Type {
    
    // Variables
    var name: String
    
    var weaknesses: [String] // Defense
    var resistances: [String] // Defense
    var immunities: [String] // Defense
    
    var superEffective: [String] // Attack
    var notVeryEffective: [String] // Attack
    var noEffect: [String] // Attack
    
    // Functions
    static func typeLookup(name: String) -> Type? {
        switch name {
        case "Normal":
            return Type(name: "Normal", weaknesses: ["Fighting"], resistances: [], immunities: ["Ghost"], superEffective: [], notVeryEffective: ["Rock", "Steel"], noEffect: ["Ghost"])
        case "Fire":
            return Type(name: "Fire", weaknesses: ["Water", "Ground", "Rock"], resistances: ["Fire", "Grass", "Ice", "Bug", "Steel", "Fairy"], immunities: [], superEffective: ["Grass", "Ice", "Bug", "Steel"], notVeryEffective: ["Fire", "Water", "Rock", "Dragon"], noEffect: [])
        case "Water":
            return Type(name: "Water", weaknesses: ["Electric", "Grass"], resistances: ["Fire", "Water", "Ice", "Steel"], immunities: [], superEffective: ["Fire", "Ground", "Rock"], notVeryEffective: ["Water", "Grass", "Dragon"], noEffect: [])
        case "Electric":
            return Type(name: "Electric", weaknesses: ["Ground"], resistances: ["Electric", "Flying", "Steel"], immunities: [], superEffective: ["Water", "Flying"], notVeryEffective: ["Electric", "Grass", "Dragon"], noEffect: ["Ground"])
        case "Grass":
            return Type(name: "Grass", weaknesses: ["Fire", "Ice", "Poison", "Flying", "Bug"], resistances: ["Water", "Electric", "Grass", "Ground"], immunities: [], superEffective: ["Water", "Ground", "Rock"], notVeryEffective: ["Fire", "Grass", "Poison", "Flying", "Bug", "Dragon", "Steel"], noEffect: [])
        case "Ice":
            return Type(name: "Ice", weaknesses: ["Fire", "Fighting", "Rock", "Steel"], resistances: ["Ice"], immunities: [], superEffective: ["Grass", "Ground", "Flying", "Dragon"], notVeryEffective: ["Fire", "Water", "Ice", "Steel"], noEffect: [])
        case "Fighting":
            return Type(name: "Fighting", weaknesses: ["Flying", "Psychic", "Fairy"], resistances: ["Bug", "Rock", "Dark"], immunities: [], superEffective: ["Normal", "Ice", "Rock", "Dark", "Steel"], notVeryEffective: ["Poison", "Flying", "Psychic", "Bug", "Fairy"], noEffect: ["Ghost"])
        case "Poison":
            return Type(name: "Poison", weaknesses: ["Ground", "Psychic"], resistances: ["Grass", "Fighting", "Poison", "Bug", "Fairy"], immunities: [], superEffective: ["Grass", "Fairy"], notVeryEffective: ["Poison", "Ground", "Rock", "Ghost"], noEffect: ["Steel"])
        case "Ground":
            return Type(name: "Ground", weaknesses: ["Water", "Grass", "Ice"], resistances: ["Poison", "Rock"], immunities: ["Electric"], superEffective: ["Fire", "Electric", "Poison", "Rock", "Steel"], notVeryEffective: ["Grass", "Bug"], noEffect: ["Flying"])
        case "Flying":
            return Type(name: "Flying", weaknesses: ["Electric", "Ice", "Rock"], resistances: ["Grass", "Fighting", "Bug"], immunities: ["Ground"], superEffective: ["Grass", "Fighting", "Bug"], notVeryEffective: ["Electric", "Rock", "Steel"], noEffect: [])
        case "Psychic":
            return Type(name: "Psychic", weaknesses: ["Bug", "Ghost", "Dark"], resistances: ["Fighting", "Psychic"], immunities: [], superEffective: ["Fighting", "Poison"], notVeryEffective: ["Psychic", "Steel"], noEffect: ["Dark"])
        case "Bug":
            return Type(name: "Bug", weaknesses: ["Fire", "Flying", "Rock"], resistances: ["Grass", "Fighting", "Ground"], immunities: [], superEffective: ["Grass", "Psychic", "Dark"], notVeryEffective: ["Fire", "Fighting", "Poison", "Flying", "Ghost", "Steel", "Fairy"], noEffect: [])
        case "Rock":
            return Type(name: "Rock", weaknesses: ["Water", "Grass", "Fighting", "Ground", "Steel"], resistances: ["Normal", "Fire", "Poison", "Flying"], immunities: [], superEffective: ["Fire", "Ice", "Flying", "Bug"], notVeryEffective: ["Fighting", "Ground", "Steel"], noEffect: [])
        case "Ghost":
            return Type(name: "Ghost", weaknesses: ["Ghost", "Dark"], resistances: ["Poison", "Bug"], immunities: ["Normal", "Fighting"], superEffective: ["Psychic", "Ghost"], notVeryEffective: ["Dark"], noEffect: ["Normal"])
        case "Dragon":
            return Type(name: "Dragon", weaknesses: ["Ice", "Dragon", "Fairy"], resistances: ["Fire", "Water", "Electric", "Grass"], immunities: [], superEffective: ["Dragon"], notVeryEffective: ["Steel"], noEffect: ["Fairy"])
        case "Dark":
            return Type(name: "Dark", weaknesses: ["Fighting", "Bug", "Fairy"], resistances: ["Ghost", "Dark"], immunities: ["Psychic"], superEffective: ["Psychic", "Ghost"], notVeryEffective: ["Fighting", "Dark", "Fairy"], noEffect: [])
        case "Steel":
            return Type(name: "Steel", weaknesses: ["Fire", "Fighting", "Ground"], resistances: ["Normal", "Grass", "Ice", "Flying", "Psychic", "Bug", "Rock", "Dragon", "Steel", "Fairy"], immunities: ["Poison"], superEffective: ["Ice", "Rock", "Fairy"], notVeryEffective: ["Fire", "Water", "Electric", "Steel"], noEffect: [])
        case "Fairy":
            return Type(name: "Fairy", weaknesses: ["Poison", "Steel"], resistances: ["Fighting", "Bug", "Dark"], immunities: ["Dragon"], superEffective: ["Fighting", "Dragon", "Dark"], notVeryEffective: ["Fire", "Poison", "Steel"], noEffect: [])
        case "":
            return nil
        default:
            return Type(name: "???", weaknesses: [], resistances: [], immunities: [], superEffective: [], notVeryEffective: [], noEffect: [])
        }
    }
    
    static func getTypeList() -> [Type] {
        return [
            Type(name: "Normal", weaknesses: ["Fighting"], resistances: [], immunities: ["Ghost"], superEffective: [], notVeryEffective: ["Rock", "Steel"], noEffect: ["Ghost"]),
            Type(name: "Fire", weaknesses: ["Water", "Ground", "Rock"], resistances: ["Fire", "Grass", "Ice", "Bug", "Steel", "Fairy"], immunities: [], superEffective: ["Grass", "Ice", "Bug", "Steel"], notVeryEffective: ["Fire", "Water", "Rock", "Dragon"], noEffect: []),
            Type(name: "Water", weaknesses: ["Electric", "Grass"], resistances: ["Fire", "Water", "Ice", "Steel"], immunities: [], superEffective: ["Fire", "Ground", "Rock"], notVeryEffective: ["Water", "Grass", "Dragon"], noEffect: []),
            Type(name: "Electric", weaknesses: ["Ground"], resistances: ["Electric", "Flying", "Steel"], immunities: [], superEffective: ["Water", "Flying"], notVeryEffective: ["Electric", "Grass", "Dragon"], noEffect: ["Ground"]),
            Type(name: "Grass", weaknesses: ["Fire", "Ice", "Poison", "Flying", "Bug"], resistances: ["Water", "Electric", "Grass", "Ground"], immunities: [], superEffective: ["Water", "Ground", "Rock"], notVeryEffective: ["Fire", "Grass", "Poison", "Flying", "Bug", "Dragon", "Steel"], noEffect: []),
            Type(name: "Ice", weaknesses: ["Fire", "Fighting", "Rock", "Steel"], resistances: ["Ice"], immunities: [], superEffective: ["Grass", "Ground", "Flying", "Dragon"], notVeryEffective: ["Fire", "Water", "Ice", "Steel"], noEffect: []),
            Type(name: "Fighting", weaknesses: ["Flying", "Psychic", "Fairy"], resistances: ["Bug", "Rock", "Dark"], immunities: [], superEffective: ["Normal", "Ice", "Rock", "Dark", "Steel"], notVeryEffective: ["Poison", "Flying", "Psychic", "Bug", "Fairy"], noEffect: ["Ghost"]),
            Type(name: "Poison", weaknesses: ["Ground", "Psychic"], resistances: ["Grass", "Fighting", "Poison", "Bug", "Fairy"], immunities: [], superEffective: ["Grass", "Fairy"], notVeryEffective: ["Poison", "Ground", "Rock", "Ghost"], noEffect: ["Steel"]),
            Type(name: "Ground", weaknesses: ["Water", "Grass", "Ice"], resistances: ["Poison", "Rock"], immunities: ["Electric"], superEffective: ["Fire", "Electric", "Poison", "Rock", "Steel"], notVeryEffective: ["Grass", "Bug"], noEffect: ["Flying"]),
            Type(name: "Flying", weaknesses: ["Electric", "Ice", "Rock"], resistances: ["Grass", "Fighting", "Bug"], immunities: ["Ground"], superEffective: ["Grass", "Fighting", "Bug"], notVeryEffective: ["Electric", "Rock", "Steel"], noEffect: []),
            Type(name: "Psychic", weaknesses: ["Bug", "Ghost", "Dark"], resistances: ["Fighting", "Psychic"], immunities: [], superEffective: ["Fighting", "Poison"], notVeryEffective: ["Psychic", "Steel"], noEffect: ["Dark"]),
            Type(name: "Bug", weaknesses: ["Fire", "Flying", "Rock"], resistances: ["Grass", "Fighting", "Ground"], immunities: [], superEffective: ["Grass", "Psychic", "Dark"], notVeryEffective: ["Fire", "Fighting", "Poison", "Flying", "Ghost", "Steel", "Fairy"], noEffect: []),
            Type(name: "Rock", weaknesses: ["Water", "Grass", "Fighting", "Ground", "Steel"], resistances: ["Normal", "Fire", "Poison", "Flying"], immunities: [], superEffective: ["Fire", "Ice", "Flying", "Bug"], notVeryEffective: ["Fighting", "Ground", "Steel"], noEffect: []),
            Type(name: "Ghost", weaknesses: ["Ghost", "Dark"], resistances: ["Poison", "Bug"], immunities: ["Normal", "Fighting"], superEffective: ["Psychic", "Ghost"], notVeryEffective: ["Dark"], noEffect: ["Normal"]),
            Type(name: "Dragon", weaknesses: ["Ice", "Dragon", "Fairy"], resistances: ["Fire", "Water", "Electric", "Grass"], immunities: [], superEffective: ["Dragon"], notVeryEffective: ["Steel"], noEffect: ["Fairy"]),
            Type(name: "Dark", weaknesses: ["Fighting", "Bug", "Fairy"], resistances: ["Ghost", "Dark"], immunities: ["Psychic"], superEffective: ["Psychic", "Ghost"], notVeryEffective: ["Fighting", "Dark", "Fairy"], noEffect: []),
            Type(name: "Steel", weaknesses: ["Fire", "Fighting", "Ground"], resistances: ["Normal", "Grass", "Ice", "Flying", "Psychic", "Bug", "Rock", "Dragon", "Steel", "Fairy"], immunities: ["Poison"], superEffective: ["Ice", "Rock", "Fairy"], notVeryEffective: ["Fire", "Water", "Electric", "Steel"], noEffect: []),
            Type(name: "Fairy", weaknesses: ["Poison", "Steel"], resistances: ["Fighting", "Bug", "Dark"], immunities: ["Dragon"], superEffective: ["Fighting", "Dragon", "Dark"], notVeryEffective: ["Fire", "Poison", "Steel"], noEffect: [])
        ]
    }
    
    static func toType(list: [String]) -> [Type] {
        var answer: [Type] = []
        for eachString in list {
            answer.append(Type.typeLookup(name: eachString)!)
        }
        return answer
    }
    
}
