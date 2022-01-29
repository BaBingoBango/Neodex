//
//  SpotlightServices.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/4/21.
//

import Foundation
import CoreSpotlight
import MobileCoreServices

/// Provides methods which index app content into Spotlight or de-index it out of Spotlight.
struct SpotlightServices {
    
    /// Indexes all Pokémon in pokemonDataList into Spotlight.
    static func indexPokemon() {
        for eachPokemon in pokemonDataList {
            // Define the item's attributes
            let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
            attributeSet.thumbnailURL = AssetExtractor.createLocalUrl(forImageNamed: "\(eachPokemon.name)-art")
            attributeSet.title = eachPokemon.name
            if eachPokemon.type2.isEmpty {
                attributeSet.contentDescription = "\(eachPokemon.type1)-type Pokémon"
            } else {
                attributeSet.contentDescription = "\(eachPokemon.type1) and \(eachPokemon.type2)-type Pokémon"
            }
            
            // Add the attributes to a searchable item
            let item = CSSearchableItem(uniqueIdentifier: eachPokemon.name + "*pokemon", domainIdentifier: nil, attributeSet: attributeSet)
            item.expirationDate = Date.distantFuture
            
            // Index the searchable item
            CSSearchableIndex.default().indexSearchableItems([item]) { error in
                if let error = error {
                    print("Indexing error: \(error.localizedDescription)")
                } else {
                    print("\(eachPokemon.name) successfully indexed!")
                }
            }
        }
    }
    /// Indexes all moves in moveDataList into Spotlight.
    static func indexMoves() {
        for eachMove in moveDataList {
            // Define the item's attributes
            let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
            attributeSet.title = eachMove.name
            if eachMove.category == "--" {
                attributeSet.contentDescription = "\(eachMove.type)-type Pokémon move"
                attributeSet.thumbnailURL = AssetExtractor.createLocalUrl(forImageNamed: "\(eachMove.type.lowercased())-physical")
            } else {
                attributeSet.contentDescription = "\(eachMove.type)-type \(eachMove.category.lowercased()) Pokémon move"
                attributeSet.thumbnailURL = AssetExtractor.createLocalUrl(forImageNamed: "\(eachMove.type.lowercased())-\(eachMove.category.lowercased())")
            }
            
            // Add the attributes to a searchable item
            let item = CSSearchableItem(uniqueIdentifier: eachMove.name + "*move", domainIdentifier: nil, attributeSet: attributeSet)
            item.expirationDate = Date.distantFuture
            
            // Index the searchable item
            CSSearchableIndex.default().indexSearchableItems([item]) { error in
                if let error = error {
                    print("Indexing error: \(error.localizedDescription)")
                } else {
                    print("\(eachMove.name) successfully indexed!")
                }
            }
        }
    }
    /// Indexes all abilities in Ability.abilityList into Spotlight.
    static func indexAbilities() {
        for eachAbility in Ability.abilityList {
            // Define the item's attributes
            let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
            attributeSet.thumbnailURL = AssetExtractor.createLocalUrl(forImageNamed: "ability-icon")
            attributeSet.title = eachAbility.name
            attributeSet.contentDescription = "Pokémon Ability"
            
            // Add the attributes to a searchable item
            let item = CSSearchableItem(uniqueIdentifier: eachAbility.name + "*ability", domainIdentifier: nil, attributeSet: attributeSet)
            item.expirationDate = Date.distantFuture
            
            // Index the searchable item
            CSSearchableIndex.default().indexSearchableItems([item]) { error in
                if let error = error {
                    print("Indexing error: \(error.localizedDescription)")
                } else {
                    print("\(eachAbility.name) successfully indexed!")
                }
            }
        }
    }
    /// Indexes all Natures in Nature.natureList into Spotlight.
    static func indexNatures() {
        for eachNature in Nature.natureList {
            // Define the item's attributes
            let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
            attributeSet.thumbnailURL = AssetExtractor.createLocalUrl(forImageNamed: "nature-icon")
            attributeSet.title = eachNature.name
            attributeSet.contentDescription = "Pokémon Nature"
            
            // Add the attributes to a searchable item
            let item = CSSearchableItem(uniqueIdentifier: eachNature.name + "*nature", domainIdentifier: nil, attributeSet: attributeSet)
            item.expirationDate = Date.distantFuture
            
            // Index the searchable item
            CSSearchableIndex.default().indexSearchableItems([item]) { error in
                if let error = error {
                    print("Indexing error: \(error.localizedDescription)")
                } else {
                    print("\(eachNature.name) successfully indexed!")
                }
            }
        }
    }
    /// Indexes all items in Item.itemList into Spotlight.
    static func indexItems() {
        for eachItem in Item.itemList {
            // Define the item's attributes
            let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
            attributeSet.thumbnailURL = AssetExtractor.createLocalUrl(forImageNamed: (eachItem.name))
            attributeSet.title = eachItem.name
            switch eachItem.category {
            case .battle: attributeSet.contentDescription = "Pokémon battle item"
            case .enhancer: attributeSet.contentDescription = "Pokémon enhancement item"
            case .megaEvolution: attributeSet.contentDescription = "Pokémon Mega Evolution item"
            case .heldItems: attributeSet.contentDescription = "Pokémon held item"
            case .zcrystals: attributeSet.contentDescription = "Pokémon Z-Crystal"
            case .evolution: attributeSet.contentDescription = "Pokémon evolution item"
            case .keyItems: attributeSet.contentDescription = "Pokémon key item"
            case .berriesAndApricorns: attributeSet.contentDescription = "Pokémon berry"
            case .medicine: attributeSet.contentDescription = "Pokémon medicine"
            case .fossils: attributeSet.contentDescription = "Pokémon fossil"
            case .treasures: attributeSet.contentDescription = "Pokémon treasure item"
            case .ingredients: attributeSet.contentDescription = "Pokémon curry ingredient"
            case .pokeBalls: attributeSet.contentDescription = "Poké Ball"
            case .machines: attributeSet.contentDescription = "Pokémon move machine"
            }
            
            // Add the attributes to a searchable item
            let item = CSSearchableItem(uniqueIdentifier: eachItem.name + "*item", domainIdentifier: nil, attributeSet: attributeSet)
            item.expirationDate = Date.distantFuture
            
            // Index the searchable item
            CSSearchableIndex.default().indexSearchableItems([item]) { error in
                if let error = error {
                    print("Indexing error: \(error.localizedDescription)")
                } else {
                    print("\(eachItem.name) successfully indexed!")
                }
            }
        }
    }
    /// De-indexes all Pokémon in pokemonDataLIst from Spotlight.
    static func deIndexPokemon() {
        for eachPokemon in pokemonDataList {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [eachPokemon.name + "*pokemon"]) { error in
                if let error = error {
                    print("Deindexing error: \(error.localizedDescription)")
                } else {
                    print("Search item successfully removed!")
                }
            }
        }
    }
    /// De-indexes all moves in moveDataList from Spotlight.
    static func deIndexMoves() {
        for eachMove in moveDataList {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [eachMove.name + "*move"]) { error in
                if let error = error {
                    print("Deindexing error: \(error.localizedDescription)")
                } else {
                    print("Search item successfully removed!")
                }
            }
        }
    }
    /// De-indexes all abilities in Ability.abilityList from Spotlight.
    static func deIndexAbilities() {
        for eachAbility in Ability.abilityList {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [eachAbility.name + "*ability"]) { error in
                if let error = error {
                    print("Deindexing error: \(error.localizedDescription)")
                } else {
                    print("Search item successfully removed!")
                }
            }
        }
    }
    /// De-indexes all Natures in Nature.natureList from Spotlight.
    static func deIndexNatures() {
        for eachNature in Nature.natureList {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [eachNature.name + "*nature"]) { error in
                if let error = error {
                    print("Deindexing error: \(error.localizedDescription)")
                } else {
                    print("Search item successfully removed!")
                }
            }
        }
    }
    /// De-indexes all items in Item.itemList from Spotlight.
    static func deIndexItems() {
        for eachItem in Item.itemList {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [eachItem.name + "*item"]) { error in
                if let error = error {
                    print("Deindexing error: \(error.localizedDescription)")
                } else {
                    print("Search item successfully removed!")
                }
            }
        }
    }
    
}
