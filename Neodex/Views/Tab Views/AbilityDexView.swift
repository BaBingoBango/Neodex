//
//  AbilityDexView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/29/20.
//

import SwiftUI

struct AbilityDexView: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @State private var searchText : String = ""
    let abilityList: [Ability] = Ability.abilityList
    @State var showingSorting = false
    @State var showingHelp = false
    @State var showingSettings = false
    @State var showingFilters = false
    private var filterCount: Binding<Int> { Binding (
        get: { return runFilters().count },
        set: { _ in }
        )
    }
    
    // Filter variables
    @State var pokemonFilters: [Pokemon] = []
    
    // Sort variables
    @State var sortCondition: String = "Alphabetical"
    @State var sortDirection: Int = 0
    
    var body: some View {
        
        ScrollView {
            
            LazyVStack {
                
                SearchBar(text: $searchText)
                    .padding(.vertical)
                
                HStack {
                    
                    Button(action: {
                        showingFilters.toggle()
                    }) {
                        DexEditButton(imageName: "line.horizontal.3.decrease.circle", name: pokemonFilters.count >= 1 ? (pokemonFilters.count == 1 ? "1 Filter On" : "\(pokemonFilters.count) Filters On") : "Filter", backColor: pokemonFilters.count >= 1 ? .blue : .secondary, frontColor: pokemonFilters.count >= 1 ? .white : .black)
                    }
                    .sheet(isPresented: $showingFilters) {
                        AbilityDexFilterView(filterCount: filterCount, pokemonFilters: $pokemonFilters).environmentObject(sessionData)
                    }
                    
                    Button(action: {
                        showingSorting.toggle()
                    }) {
                        DexEditButton(imageName: "arrow.up.arrow.down", name: (sortCondition != "Alphabetical" || sortDirection != 0) ? "Sorting" : "Sort", backColor: (sortCondition != "Alphabetical" || sortDirection != 0) ? .blue : .secondary, frontColor: (sortCondition != "Alphabetical" || sortDirection != 0) ? .white : .black)
                    }
                    .sheet(isPresented: $showingSorting) {
                        AbilityDexSortView(sortCondition: $sortCondition, sortDirection: $sortDirection)
                    }
                    
                }
                .padding([.leading, .bottom, .trailing])
                
                ForEach(filterAndSort().filter {
                    self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                }, id: \.name) { ability in
                    AbilityListOption(ability: ability).environmentObject(sessionData)
                        .padding(.bottom, 5)
                }
                
            }
        }
        
        .navigationBarTitle("Ability Dex")
        .navigationBarItems(trailing: AbilityDexTrailingNavButtons(showingHelp: $showingHelp, showingSettings: $showingSettings).environmentObject(sessionData))
        
    }
    
    // Functions
    func filterAndSort() -> [Ability] {
        let answer = runFilters().sorted(by: {
            
            switch sortCondition {
            
            // 1: Alphabetical
            case "Alphabetical":
                if sortDirection == 0 {
                    return $0.name < $1.name
                } else {
                    return $0.name > $1.name
                }
                
            // 2: No. of compatible Pokémon
            case "No. of Compatible Pokémon":
                if sortDirection == 0 {
                    return filterPokemonFromAbility(ability: $0.name).count < filterPokemonFromAbility(ability: $1.name).count
                } else {
                    return filterPokemonFromAbility(ability: $0.name).count > filterPokemonFromAbility(ability: $1.name).count
                }
                
            default:
                if sortDirection == 0 {
                    return $0.name < $1.name
                } else {
                    return $0.name > $1.name
                }
            
            }
            
        })
        
        return answer
    }
    
    func filterPokemonFromAbility(ability: String) -> [Pokemon] {
        var answer: [Pokemon] = []
        for eachPokemon in pokemonDataList {
            if eachPokemon.ability1 == ability || eachPokemon.ability2 == ability || eachPokemon.hiddenAbility == ability {
                answer.append(eachPokemon)
            }
        }
        return answer
    }
    
    func runFilters() -> [Ability] {
        var answer = Ability.abilityList
        
        // 1: Compatibility
        if pokemonFilters.count >= 1 {
            for eachPokemon in pokemonFilters {
                answer = answer.filter({
                    if (eachPokemon.ability1 == $0.name || eachPokemon.ability2 == $0.name || eachPokemon.hiddenAbility == $0.name) {
                        return true
                    } else {
                        return false
                    }
                })
            }
        }
        
        return answer
    }
    
}

struct AbilityDexView_Previews: PreviewProvider {
    static var previews: some View {
        AbilityDexView().environmentObject(SessionData())
    }
}

struct AbilityDexTrailingNavButtons: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @Binding var showingHelp: Bool
    @Binding var showingSettings: Bool
    
    var body: some View {
        HStack {
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
                    AbilityHelpGuide(text: "Done")
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
