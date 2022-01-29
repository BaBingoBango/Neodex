//
//  DualTypeEngine.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/16/20.
//

import Foundation

// This structure exists to take in two types, that is, a dual type, and return the five components of its defense report.

struct DualTypeEngine {
    
    // Functions
    static func hyperweak(type1: Type, type2: Type) -> [Type] {
        var answer: [Type] = []
        for eachType in Type.getTypeList() {
            if type1.weaknesses.contains(eachType.name) && type2.weaknesses.contains(eachType.name) {
                answer.append(eachType)
            }
        }
        return answer
    }
    
    static func weak(type1: Type, type2: Type) -> [Type] {
        var answer: [Type] = []
        for eachType in Type.getTypeList() {
            if (((type1.weaknesses.contains(eachType.name) && !type2.weaknesses.contains(eachType.name)) || (!type1.weaknesses.contains(eachType.name) && type2.weaknesses.contains(eachType.name))) && ((!type1.resistances.contains(eachType.name) && !type1.immunities.contains(eachType.name)) && (!type2.resistances.contains(eachType.name) && !type2.immunities.contains(eachType.name)))) {
                answer.append(eachType)
            }
        }
        return answer
    }
    
    static func resistant(type1: Type, type2: Type) -> [Type] {
        var answer: [Type] = []
        for eachType in Type.getTypeList() {
            if (((type1.resistances.contains(eachType.name) && !type2.resistances.contains(eachType.name)) || (!type1.resistances.contains(eachType.name) && type2.resistances.contains(eachType.name))) && ((!type1.weaknesses.contains(eachType.name) && !type1.immunities.contains(eachType.name)) && (!type2.weaknesses.contains(eachType.name) && !type2.immunities.contains(eachType.name)))) {
                answer.append(eachType)
            }
        }
        return answer
    }
    
    static func hyperresistant(type1: Type, type2: Type) -> [Type] {
        var answer: [Type] = []
        for eachType in Type.getTypeList() {
            if type1.resistances.contains(eachType.name) && type2.resistances.contains(eachType.name) {
                answer.append(eachType)
            }
        }
        return answer
    }
    
    static func immune(type1: Type, type2: Type) -> [Type] {
        var answer: [Type] = []
        for eachType in Type.getTypeList() {
            if type1.immunities.contains(eachType.name) || type2.immunities.contains(eachType.name) {
                answer.append(eachType)
            }
        }
        return answer
    }
    
}
