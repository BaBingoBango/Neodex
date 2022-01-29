//
//  Nature.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/26/21.
//

import Foundation
import SwiftUI

struct Nature: Codable {
    
    // Variables
    var name: String
    var plus: String // The stat that is increased
    var minus: String // The stat that is decreased
    var berryPlus: String {
        if plus == minus {
            return "No Preference"
        }
        switch plus {
        case "Attack":
            return "Spicy"
        case "Defense":
            return "Sour"
        case "Speed":
            return "Sweet"
        case "Sp. Atk":
            return "Dry"
        case "Sp. Def":
            return "Bitter"
        default:
            return "No Preference"
        }
    }
    var berryMinus: String {
        if plus == minus {
            return "No Preference"
        }
        switch minus {
        case "Attack":
            return "Spicy"
        case "Defense":
            return "Sour"
        case "Speed":
            return "Sweet"
        case "Sp. Atk":
            return "Dry"
        case "Sp. Def":
            return "Bitter"
        default:
            return "No Preference"
        }
    }
    var confusingBerry: String {
        switch name {
        case "Naughty", "Rash", "Naive", "Lax":
            return "Aguav Berry"
        case "Modest", "Timid", "Calm", "Bold":
            return "Figy Berry"
        case "Lonely", "Mild", "Gentle", "Hasty":
            return "Iapapa Berry"
        case "Brave", "Quiet", "Sassy", "Relaxed":
            return "Mago Berry"
        case "Adamant", "Jolly", "Careful", "Impish":
            return "Wiki Berry"
        default:
            return "None"
        }
    }
    
    static let natureList: [Nature] = [
    
    Nature(name: "Adamant", plus: "Attack", minus: "Sp. Atk"),
        
    Nature(name: "Bashful", plus: "Sp. Atk", minus: "Sp. Atk"),
        
    Nature(name: "Bold", plus: "Defense", minus: "Attack"),
    
    Nature(name: "Brave", plus: "Attack", minus: "Speed"),
    
    Nature(name: "Calm", plus: "Sp. Def", minus: "Attack"),
    
    Nature(name: "Careful", plus: "Sp. Def", minus: "Sp. Atk"),
    
    Nature(name: "Docile", plus: "Defense", minus: "Defense"),
    
    Nature(name: "Gentle", plus: "Sp. Def", minus: "Defense"),
    
    Nature(name: "Hardy", plus: "Attack", minus: "Attack"),
    
    Nature(name: "Hasty", plus: "Speed", minus: "Defense"),
    
    Nature(name: "Impish", plus: "Defense", minus: "Sp. Atk"),
    
    Nature(name: "Jolly", plus: "Speed", minus: "Sp. Atk"),
    
    Nature(name: "Lax", plus: "Defense", minus: "Sp. Def"),
    
    Nature(name: "Lonely", plus: "Attack", minus: "Defense"),
    
    Nature(name: "Mild", plus: "Sp. Atk", minus: "Defense"),
    
    Nature(name: "Modest", plus: "Sp. Atk", minus: "Attack"),
    
    Nature(name: "Naive", plus: "Speed", minus: "Sp. Def"),
    
    Nature(name: "Naughty", plus: "Attack", minus: "Sp. Def"),
    
    Nature(name: "Quiet", plus: "Sp. Atk", minus: "Speed"),
    
    Nature(name: "Quirky", plus: "Sp. Def", minus: "Sp. Def"),
    
    Nature(name: "Rash", plus: "Sp. Atk", minus: "Sp. Def"),
    
    Nature(name: "Relaxed", plus: "Defense", minus: "Speed"),
    
    Nature(name: "Sassy", plus: "Sp. Def", minus: "Speed"),
    
    Nature(name: "Serious", plus: "Speed", minus: "Speed"),
    
    Nature(name: "Timid", plus: "Speed", minus: "Attack")
        
    ]
    
    // Functions
    static func natureLookup(_ name: String) -> Nature? {
        for eachNature in Nature.natureList {
            if eachNature.name == name {
                return eachNature
            }
        }
        return nil
    }
    
}
