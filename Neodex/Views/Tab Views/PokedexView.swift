//
//  PokedexView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/29/20.
//

import SwiftUI
import Foundation
import UIKit

/// The view listing Pokémon in a grid form or a list form, with each entry linking to that Pokémon's detail view. It also includes a search bar.
struct PokedexView: View {
    
    // MARK: Variables
    
    /// The SessionData variable for this view.
    @EnvironmentObject var sessionData: SessionData
    
    /// The state variable for this view representing the currently entered text in the search bar.
    @State private var searchText : String = ""
    
    // Filter state variables
    @State var showingFilters = false
    private var filterCount: Binding<Int> { Binding (
        get: { return runFilters().count },
        set: { _ in }
        )
    }
    private var filtersOn: Binding<Bool> { Binding (
        get: { return areFiltersOn() },
        set: { _ in }
        )
    }
    
    // General state variables for the view
    @State var showingSorting = false
    @State var showingGrid = false
    @State var showingHelp = false
    @State var showingSettings = false
    
    /// An array of grid items to size and position each row of the grid. It was provided by Developer Support.
    var columns: [GridItem] = Array(repeating: .init(.flexible()), count: 5)
    
    // Filter state variables
    @State var typeFilters: [String] = []
    @State var abilityFilters: [String] = []
    @State var evolutionFilters: [String] = []
    @State var eggGroupFilters: [String] = []
    @State var growthRateFilters: [String] = []
    @State var canBeCaughtFilters: [String] = []
    @State var moveFilters: [String] = []
    @State var megaEvolutionFilters: [String] = []
    @State var alolanFormFilters: [String] = []
    @State var galarianFormFilters: [String] = []
    @State var EVYieldTypeFilters: [String] = []
    
    // Sorting state variables
    @State var sortCondition: String = "Dex Number"
    @State var sortDirection: Int = 0
    
    /// A variable to run code if the view is being used in Face-Off.
    var isInFaceOff: Bool
    
    // Variables & initalizers for use in Face-Off
    @Binding var pokemon: Pokemon?
    init(pokemon: Binding<Pokemon?> = .constant(pokemonDataList[0]), isInFaceOff: Bool) {
        _pokemon = pokemon
        self.isInFaceOff = isInFaceOff
    }
    init(pokemon: Binding<Pokemon?> = .constant(pokemonDataList[0])) {
        _pokemon = pokemon
        isInFaceOff = false
    }
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: View Body
    var body: some View {
        
        ScrollView {
            
            VStack {
                
                // Search bar
                SearchBar(text: $searchText)
                    .padding(.top)
                
                // The buttons under the search bar
                HStack {
                    
                    // Filter button
                    Button(action: {
                        self.showingFilters.toggle()
                    }) {
                        HStack {
                            if numFilters() >= 2 {
                                PokedexFilterButtonView(imageName: "line.horizontal.3.decrease.circle", text: filtersOn.wrappedValue ? "\(numFilters()) Filters On" : "Filter", filtersOn: filtersOn)
                            } else {
                                PokedexFilterButtonView(imageName: "line.horizontal.3.decrease.circle", text: filtersOn.wrappedValue ? "\(numFilters()) Filter On" : "Filter", filtersOn: filtersOn)
                            }
                        }
                    }
                    .sheet(isPresented: $showingFilters, content: {
                        PokedexFilterView(filterCount: filterCount, filtersOn: filtersOn, typeFilters: $typeFilters, abilityFilters: $abilityFilters, evolutionFilters: $evolutionFilters, eggGroupFilters: $eggGroupFilters, growthRateFilters: $growthRateFilters, canBeCaughtFilters: $canBeCaughtFilters, moveFilters: $moveFilters, megaEvolutionFilters: $megaEvolutionFilters, alolanFormFilters: $alolanFormFilters, galarianFormFilters: $galarianFormFilters, EVYieldTypeFilters: $EVYieldTypeFilters)
                    })
                    
                    // Sort button
                    Button(action: {
                        showingSorting.toggle()
                    }) {
                        DexEditButton(imageName: "arrow.up.arrow.down", name: (sortCondition != "Dex Number" || sortDirection != 0) ? "Sorting" : "Sort", backColor: (sortCondition != "Dex Number" || sortDirection != 0) ? .blue : .secondary, frontColor: (sortCondition != "Dex Number" || sortDirection != 0) ? .white : .black)
                    }
                    .sheet(isPresented: $showingSorting) { PokedexSortView(sortCondition: $sortCondition, sortDirection: $sortDirection) }
                    
                }
                .padding(.all)
                
                if !showingGrid {
                    
                    // List view for the Pokédex
                    
                    LazyVStack {
                        NavigationLink(destination: EmptyView()) {
                            EmptyView()
                        }
                        ForEach(filterAndSort().filter {
                            searchText.isEmpty ? true : $0.name.lowercased().contains(searchText.lowercased())
                        }, id: \.id) { pokemon in
                            
                            if !isInFaceOff {
                                
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData).navigationBarTitle(Text(""), displayMode: .inline)) {
                                    PokemonListOption(pokemon: pokemon)
                                        .padding(.bottom, 5)
                                }
                                
                            } else {
                                
                                // Face-Off code for the list view
                                Button(action: {
                                    self.pokemon = pokemon
                                    self.presentationMode.wrappedValue.dismiss()
                                }) {
                                    PokemonListOption(pokemon: pokemon)
                                }
                                .padding(.bottom, 5)
                                
                            }
                            
                        }
                    }

                } else {
                    
                    // Grid view for the Pokédex
                    
                    LazyVGrid(columns: columns) {
                        ForEach(filterAndSort().filter {
                            searchText.isEmpty ? true : $0.name.lowercased().contains(searchText.lowercased())
                        }, id: \.id) { pokemon in
                            
                            if !isInFaceOff {
                                
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData).navigationBarTitle(Text(""), displayMode: .inline)) {
                                    Image(uiImage: UIImage(named: "\(pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50, alignment: .center)
                                    
                                }
                                
                            } else {
                                
                                // Face-Off code for the grid view
                                Button(action: {
                                    self.pokemon = pokemon
                                    self.presentationMode.wrappedValue.dismiss()
                                }) {
                                    Image(uiImage: UIImage(named: "\(pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50, alignment: .center)
                                }
                                
                            }
                            
                        }
                    }
                    
                }
                
            }
            .padding(.bottom)
        }
        
        // MARK: Navigation Bar Settings
        
        .navigationBarItems(leading: isInFaceOff ? Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel") } : Button(action: {}) { Text("") }, trailing: isInFaceOff ? PokedexTrailingNavButtons(showingHelp: $showingHelp, showingSettings: $showingSettings, showingGrid: $showingGrid, isInFaceOff: true).environmentObject(sessionData) : PokedexTrailingNavButtons(showingHelp: $showingHelp, showingSettings: $showingSettings, showingGrid: $showingGrid).environmentObject(sessionData))
        .navigationBarTitle("Pokédex")
        
    }
    
    // MARK: View Functions
    
    /// Filters pokemonDataList, sorts pokemonDataList, runs it through the search bar, and returns it chunked into five for use in the grid view.
    func getChunked() -> [[Pokemon]] {
        let answer = (filterAndSort().filter { self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased()) }).chunked(into: 5)
        
        return answer
    }
    
    /// Filters the pokemonDataList using runFilters(), then sorts the list.
    func filterAndSort() -> [Pokemon] {
        
        let answer = runFilters().sorted(by: {
            
            switch sortCondition {
            
            // 1: National dex number
            case "Dex Number":
                if sortDirection == 0 {
                    return $0.nationalDexNum < $1.nationalDexNum
                } else {
                    return $0.nationalDexNum > $1.nationalDexNum
                }
                
            // 2: Alphabetical
            case "Alphabetical":
                if sortDirection == 0 {
                    return $0.name < $1.name
                } else {
                    return $0.name > $1.name
                }
                
            // 3: HP
            case "HP":
                if sortDirection == 0 {
                    return $0.baseStats[0] < $1.baseStats[0]
                } else {
                    return $0.baseStats[0] > $1.baseStats[0]
                }
                
            // 4: Special Attack
            case "Special Attack":
                if sortDirection == 0 {
                    return $0.baseStats[3] < $1.baseStats[3]
                } else {
                    return $0.baseStats[3] > $1.baseStats[3]
                }
                
            // 5: Special Defense
            case "Special Defense":
                if sortDirection == 0 {
                    return $0.baseStats[4] < $1.baseStats[4]
                } else {
                    return $0.baseStats[4] > $1.baseStats[4]
                }
                
            // 6: Attack
            case "Attack":
                if sortDirection == 0 {
                    return $0.baseStats[1] < $1.baseStats[1]
                } else {
                    return $0.baseStats[1] > $1.baseStats[1]
                }
                
            // 7: Defense
            case "Defense":
                if sortDirection == 0 {
                    return $0.baseStats[2] < $1.baseStats[2]
                } else {
                    return $0.baseStats[2] > $1.baseStats[2]
                }
                
            // 8: HP
            case "Speed":
                if sortDirection == 0 {
                    return $0.baseStats[5] < $1.baseStats[5]
                } else {
                    return $0.baseStats[5] > $1.baseStats[5]
                }
                
            // 9: Base Stat Total
            case "Base Stat Total":
                if sortDirection == 0 {
                    return getBST(pokemon: $0) < getBST(pokemon: $1)
                } else {
                    return getBST(pokemon: $0) > getBST(pokemon: $1)
                }
                
            // 10: Height
            case "Height":
                if sortDirection == 0 {
                    return $0.height < $1.height
                } else {
                    return $0.height > $1.height
                }
                
            // 11: Weight
            case "Weight":
                if sortDirection == 0 {
                    return $0.weight < $1.weight
                } else {
                    return $0.weight > $1.weight
                }
                
            // 12: Catch Rate
            case "Catch Rate":
                if sortDirection == 0 {
                    return $0.catchRate < $1.catchRate
                } else {
                    return $0.catchRate > $1.catchRate
                }
                
            // 13: Friendship
            case "Friendship":
                if sortDirection == 0 {
                    return $0.baseFriendship < $1.baseFriendship
                } else {
                    return $0.baseFriendship > $1.baseFriendship
                }
                
            // 14: Base Exp.
            case "Base Exp.":
                if sortDirection == 0 {
                    return $0.baseEXP < $1.baseEXP
                } else {
                    return $0.baseEXP > $1.baseEXP
                }
                
            // 15: Egg Cycles
            case "Egg Cycles":
                if sortDirection == 0 {
                    return $0.eggCycles < $1.eggCycles
                } else {
                    return $0.eggCycles > $1.eggCycles
                }
                
            // 16: Male Rate
            case "Male Rate":
                if sortDirection == 0 {
                    return $0.maleRate < $1.maleRate
                } else {
                    return $0.maleRate > $1.maleRate
                }
                
            // 17: Growth Rate
            case "Growth Rate":
                
                // Assign IDs to each growth rate
                
                if sortDirection == 0 {
                    return getIDFromGrowthRate(rate: $0.growthRate) < getIDFromGrowthRate(rate: $1.growthRate)
                } else {
                    return getIDFromGrowthRate(rate: $0.growthRate) > getIDFromGrowthRate(rate: $1.growthRate)
                }
                
            default:
            return $0.nationalDexNum > $1.nationalDexNum
            }
            
        })
        
        return answer
        
    }
    
    // Given a Pokémon growth rate as a String, returns an Int representing it.
    func getIDFromGrowthRate(rate: String) -> Int {
        switch rate {
        case "Erratic":
            return 6
        case "Fast":
            return 5
        case "Medium Fast":
            return 4
        case "Medium Slow":
            return 3
        case "Slow":
            return 2
        case "Fluctuating":
            return 1
        default:
            return 0
        }
    }
    
    /// Given a Pokémon, returns its base stat total as an integer.
    func getBST(pokemon: Pokemon) -> Int {
        var answer = 0
        for eachStat in pokemon.baseStats {
            answer += eachStat
        }
        return answer
    }
    
    /// Filters the pokemonDataList according to the user's selections and returns the filtered array.
    func runFilters() -> [Pokemon] {
        var answer: [Pokemon] = pokemonDataList
        
        // 1: Can be caught in the wild
        if canBeCaughtFilters.contains("Found in Wild") {
            answer = answer.filter({
                $0.locations.count != 0
            })
        }
        
        // 2: Is mega evolved
        if megaEvolutionFilters.contains("Mega Evolved") {
            answer = answer.filter({
                $0.name.contains("-Mega")
            })
        }
        
        // 3: Is an Alolan form
        if alolanFormFilters.contains("Alolan Form") {
            answer = answer.filter({
                $0.name.contains("-Alola")
            })
        }
        
        // 4: Is a Galarian form
        if galarianFormFilters.contains("Galarian Form") {
            answer = answer.filter({
                $0.name.contains("-Galar")
            })
        }
        
        // 5-1: Has a certain single type
        if typeFilters.count == 1 {
            answer = answer.filter({
                $0.type1 == typeFilters[0] || $0.type2 == typeFilters[0]
            })
        }
        
        // 5-2: Is a certain dual type
        if typeFilters.count == 2 {
            answer = answer.filter({
                ($0.type1 == typeFilters[0] && $0.type2 == typeFilters[1]) || ($0.type1 == typeFilters[1] && $0.type2 == typeFilters[0])
            })
        }
        
        // 6: Has a certain number of evolutions
        if evolutionFilters.count == 1 {
            answer = answer.filter({
                switch evolutionFilters[0] {
                case "0":
                    return String($0.evolutions.count) == evolutionFilters[0]
                case "1":
                    return String($0.evolutions.count - 1) == evolutionFilters[0]
                case "2":
                    return String($0.evolutions.count - 1) == evolutionFilters[0]
                default:
                    return true
                }
            })
        }
        
        // 7: Is compatible with one or more moves
        if moveFilters.count >= 1 {
            for eachFilter in moveFilters {
                let move = Move.moveLookup(name: eachFilter)
                answer = answer.filter({
                    
                    for eachMethod in move.viaLevel {
                        if eachMethod.name == $0.name {
                            return true
                        }
                    }
                    
                    for eachMethod in move.viaTM {
                        if eachMethod.name == $0.name {
                            return true
                        }
                    }
                    
                    for eachMethod in move.viaEgg {
                        if eachMethod.name == $0.name {
                            return true
                        }
                    }
                    
                    for eachMethod in move.viaTutor {
                        if eachMethod.name == $0.name {
                            return true
                        }
                    }
                    
                    return false
                        
                })
            }
        }
        
        // 8: Is compatible with a certain Ability
        if abilityFilters.count == 1 {
            answer = answer.filter({
                $0.ability1 == abilityFilters[0] || $0.ability2 == abilityFilters[0] || $0.hiddenAbility == abilityFilters[0]
            })
        }
        
        // 9: Yields one or more types of EVs
        if EVYieldTypeFilters.count >= 1 {
            for eachFilter in EVYieldTypeFilters {
                answer = answer.filter({
                    $0.EVYield.contains(eachFilter)
                })
            }
        }
        
        // 10: Grows at a certain rate
        if growthRateFilters.count == 1 {
            answer = answer.filter({
                $0.growthRate == growthRateFilters[0]
            })
        }
        
        // 11: Belongs to one or more Egg Groups
        if eggGroupFilters.count >= 1 {
            answer = answer.filter({
                for eachGroup in eggGroupFilters {
                    if !$0.eggGroups.contains(eachGroup) {
                        return false
                    }
                }
                return true
            })
        }
        
        return answer
    }
    
    /// Returns true if there are any Pokémon filters currently on, and false otherwise.
    func areFiltersOn() -> Bool {
        if typeFilters.count != 0 || abilityFilters.count != 0 || evolutionFilters.count != 0 || eggGroupFilters.count != 0 || growthRateFilters.count != 0 || canBeCaughtFilters.count != 0 || moveFilters.count != 0 || megaEvolutionFilters.count != 0 || alolanFormFilters.count != 0 || galarianFormFilters.count != 0 || EVYieldTypeFilters.count != 0 {
            return true
        } else {
            return false
        }
    }
    
    /// Returns the number of filters the user has currently turned on.
    func numFilters() -> Int {
        var answer = 0
        if typeFilters.count >= 1 { answer += 1 }
        if abilityFilters.count >= 1 { answer += 1 }
        if evolutionFilters.count >= 1 { answer += 1 }
        if eggGroupFilters.count >= 1 { answer += eggGroupFilters.count }
        if growthRateFilters.count >= 1 { answer += 1 }
        if canBeCaughtFilters.count >= 1 { answer += 1 }
        if moveFilters.count >= 1 { answer += moveFilters.count }
        if megaEvolutionFilters.count >= 1 { answer += 1 }
        if alolanFormFilters.count >= 1 { answer += 1 }
        if galarianFormFilters.count >= 1 { answer += 1 }
        if EVYieldTypeFilters.count >= 1 { answer += EVYieldTypeFilters.count }
        return answer
    }
    
}

/// The preview provider for the PokedexView.
struct PokedexView_Previews: PreviewProvider {
    static var previews: some View {
        PokedexView().environmentObject(SessionData())
    }
}

// MARK: Support Views

struct LeadingNavButtons: View {
    
    // Variables
    @Binding var sortCondition: String
    @Binding var sortDirection: Int
    @Binding var showingSorting: Bool
    @Binding var showingGrid: Bool
    
    var dontIncludeSortButton = false
    
    var body: some View {
        HStack {
            if !dontIncludeSortButton {
                Button(action: {
                        self.showingSorting = true }
                ) { Image(systemName: !(sortCondition != "Dex Number" || sortDirection != 0) ? "arrow.up.arrow.down.square" : "arrow.up.arrow.down.square.fill")
                    .foregroundColor(.blue)
                    .imageScale(.large)
                    
                }
                .sheet(isPresented: $showingSorting) { PokedexSortView(sortCondition: $sortCondition, sortDirection: $sortDirection)
                }
            }
            Button(action: {
                self.showingGrid.toggle()
            }) {
                Image(systemName: showingGrid ? "list.bullet" : "square.grid.2x2")
                    .foregroundColor(.blue)
                    .padding(.leading)
                    .imageScale(.large)
            }
        }
    }
}

struct PokedexTrailingNavButtons: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @Binding var showingHelp: Bool
    @Binding var showingSettings: Bool
    @Binding var showingGrid: Bool
    var isInFaceOff = false
    
    var body: some View {
        HStack {
            Button(action: {
                self.showingGrid.toggle()
            }) {
                Image(systemName: showingGrid ? "list.bullet" : "square.grid.2x2")
                    .foregroundColor(.blue)
                    .padding(.leading)
                    .imageScale(.large)
            }
            .padding(.trailing, 5)
            
            if !isInFaceOff {
                
                Button(action: {
                    showingHelp.toggle()
                }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                        .padding(.trailing, 5)
                        .imageScale(.large)
                }
                .sheet(isPresented: $showingHelp) {
                    NavigationView {
                        PokemonHelpGuide(text: "Done")
                    }
                }
                
                Button(action: {
                    showingSettings.toggle()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(showingSettings: $showingSettings).environmentObject(sessionData)
                }
                
            }
            
        }
    }
}
struct TrailingNavButtons: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @Binding var showingHelp: Bool
    @Binding var showingSettings: Bool
    
    var body: some View {
            Button(action: {
                showingHelp.toggle()
            }) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.blue)
                    .padding(.trailing)
                    .imageScale(.large)
            }
            .sheet(isPresented: $showingHelp) {
                NavigationView {
                    PokemonHelpGuide(text: "Done")
                }
            }
            
            Button(action: {
                showingSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .foregroundColor(.blue)
                    .imageScale(.large)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(showingSettings: $showingSettings).environmentObject(sessionData)
            }
    }
}

struct PokedexFilterButtonView: View {
    
    // Variables
    var imageName: String
    var text: String
    @Binding var filtersOn: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
                .frame(height: 50)
                .foregroundColor(filtersOn ? .blue : .secondary)
                .cornerRadius(15)
            HStack {
                Image(systemName: imageName)
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundColor(filtersOn ? .white : .black)
                Text(text)
                    .fontWeight(.bold)
                    .foregroundColor(filtersOn ? .white : .black)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.leading)
        }
    }
}

struct PokedexFaceOffButtonView: View {
    
    // Variables
    var imageName: String
    var text: String
    @Binding var filtersOn: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
                .frame(height: 50)
                .foregroundColor(.secondary)
                .cornerRadius(15)
            HStack {
                Image(systemName: imageName)
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundColor(.black)
                Text(text)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.leading)
        }
    }
}
