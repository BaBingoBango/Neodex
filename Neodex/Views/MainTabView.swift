//
//  MainTabView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/29/20.
//

import SwiftUI
import CoreSpotlight

/// The entry point for the app. Based on the user's settings, it prepares the app-wide navigation bar and sets up the views to be displayed.
struct MainTabView: View {
    
    // MARK: Variables
    
    /// The SessionData variable for this view.
    @EnvironmentObject var sessionData: SessionData
    
    /// The  variable responsible for presenting modals from deeplinks.
    @State var showingDeeplinkModal = false

    // MARK: View Body
    var body: some View {
        ZStack {
            
            // If there is more than one quick access tab, prepare a TabView to place them in.
            if sessionData.tabs.count >= 2 {
                
                TabView {
                    
                    ForEach(sessionData.tabs, id: \.self) { tab in
                        
                        tabDelegator(tab: tab)
                        
                    }
                   
                }
            
            // Otherwise, skip the TabView and just get the view on screen.
            } else {
                
                ForEach(sessionData.tabs, id: \.self) { tab in
                    
                    tabDelegator(tab: tab)
                    
                }
                
            }
            
        }
        // MARK: Spotlight Deeplink Handler
        .onContinueUserActivity(CSSearchableItemActionType, perform: { userActivity in
            let rawDeeplinkData = userActivity.userInfo!["kCSSearchableItemActivityIdentifier"] as! String
            deeplinkString = rawDeeplinkData.components(separatedBy: "*")[0]
            if rawDeeplinkData.contains("*pokemon") {
                deeplinkType = .pokemon
            } else if rawDeeplinkData.contains("*move") {
                deeplinkType = .move
            } else if rawDeeplinkData.contains("*ability") {
                deeplinkType = .ability
            } else if rawDeeplinkData.contains("*nature") {
                deeplinkType = .nature
            } else if rawDeeplinkData.contains("*item") {
                deeplinkType = .item
            }
            showingDeeplinkModal = true
            print(deeplinkString)
            print(deeplinkType)
        })
        .sheet(isPresented: $showingDeeplinkModal) {
            switch deeplinkType {
            case .pokemon:
                NavigationView { PokemonDetailView(pokemon: Pokemon.findPokemon(name: deeplinkString), buttonText: "Done") }
            case .move:
                NavigationView { MoveDetailView(move: Move.moveLookup(name: deeplinkString), buttonText: "Done")
                }
            case .ability:
                NavigationView { AbilityDetailView(name: deeplinkString, detail: Ability.getDetail(ability: deeplinkString), buttonText: "Done") }
            case .nature:
                NavigationView { NatureDetailView(nature: Nature.natureLookup(deeplinkString)!, buttonText: "Done") }
            case .item:
                NavigationView { ItemDetailView(item: Item.itemLookup(deeplinkString)!, buttonText: "Done") }
            }
        }
    }
    
    // Functions
    /// Given a String which identifies a tab view, returns the associated View object. If applicable, the view is wrapped in a NavigationView.
    func tabDelegator(tab: String) -> some View {
    
        switch tab {
        
        case "Home":
            return AnyView(FeatureGallery().environmentObject(sessionData).tabItem { Image(systemName: "house.fill"); Text("Home") })
            
        case "Pokédex":
            return AnyView(NavigationView { PokedexView().environmentObject(sessionData) }.tabItem { Image(systemName: "person.fill"); Text("Pokédex") })
            
        case "Search":
            return AnyView(NavigationView { SearchTabView().environmentObject(sessionData) }.tabItem { Image(systemName: "magnifyingglass"); Text("Search") })
            
        case "Ability Dex":
            return AnyView(NavigationView { AbilityDexView().environmentObject(sessionData) }.tabItem { Image(systemName: "sparkles"); Text("Ability Dex") })
            
        case "Move Dex":
            return AnyView(NavigationView { MoveDexView().environmentObject(sessionData) }.tabItem { Image(systemName: "burst.fill"); Text("Move Dex") })
            
        case "Item Dex":
            return AnyView(NavigationView { ItemDexView().environmentObject(sessionData) }.tabItem { Image(systemName: "cube.fill"); Text("Item Dex") })
            
        case "Type-O-Matic":
            return AnyView(NavigationView { TypeOMaticView().environmentObject(sessionData) }.tabItem { Image(systemName: "circle.grid.cross.fill"); Text("Type-O-Matic") })
            
        case "Help Guide":
            return AnyView(NavigationView { HelpGuideView().environmentObject(sessionData) }.tabItem { Image(systemName: "questionmark.circle.fill"); Text("Help Guide") })
            
        case "Face-Off":
            return AnyView(NavigationView { FaceOffView(buttonText: "Settings").environmentObject(sessionData) }.tabItem { Image(systemName: "bolt.circle.fill"); Text("Face-Off") })
            
        case "Nature Checker":
            return AnyView(NavigationView { NatureGuide().environmentObject(sessionData) }.tabItem { Image(systemName: "leaf.fill"); Text("Natures") })
            
        case "Teambuilder":
            return AnyView(NavigationView { Teambuilder().environmentObject(sessionData) }.tabItem { Image(systemName: "rectangle.stack.person.crop.fill"); Text("Teambuilder")})
            
        case "Global Stats":
            return AnyView(NavigationView { GlobalStats() }.tabItem { Image(systemName: "network"); Text("Global Stats") })
            
        case "Explore":
            return AnyView(NavigationView { ExploreView() }.tabItem { Image(systemName: "wand.and.stars"); Text("Explore") })
            
        default:
            return AnyView(FeatureGallery().environmentObject(sessionData).tabItem { Image(systemName: "house.fill"); Text("Home") })
        
        }
    
    }
}

/// The preview provider for the MainTabView.
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView().environmentObject(SessionData())
    }
}

// MARK: Deeplink Helper Data
enum DeeplinkModalType {
    case pokemon
    case move
    case ability
    case nature
    case item
}
var deeplinkString = ""
var deeplinkType: DeeplinkModalType = .pokemon
