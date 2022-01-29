//
//  TeambuilderPokemonPicker.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/1/21.
//

import SwiftUI

struct TeambuilderPokemonPicker: View {
    
    // Variables
    
    /// An array of grid items to size and position each row of the grid. It was provided by Developer Support.
    var columns: [GridItem] = Array(repeating: .init(.flexible()), count: 5)
    
    var tIndex: Int
    @Binding var editingIndex: Int
    var memberIndex: Int
    @EnvironmentObject var sessionData: SessionData
    @Environment(\.presentationMode) var presentationMode
    @State var showingSorting = false
    @State var showingGrid = false
    @State private var searchText : String = ""
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
    @State var showingPokemonImporter = false
    
    // Filter variables
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
    
    // Sort variables
    @State var sortCondition: String = "Dex Number"
    @State var sortDirection: Int = 0
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                
                VStack {
                    
                    SearchBar(text: $searchText)
                        .padding(.top)
                    
                    HStack {
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
                    
                    HStack {
                        Button(action: {
                            sessionData.teams[tIndex].members[memberIndex] = nil
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            ZStack {
                                
                                Rectangle()
                                    .frame(height: 75)
                                    .foregroundColor(.red)
                                    .opacity(0.5)
                                    .cornerRadius(10)
                                    .padding(.leading)
                                
                                HStack {
                                    
                                    Image(systemName: "nosign")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.red)
                                        .padding(.leading, 35)
                                    
                                    Text("None")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                        .padding(.leading, 5)
                                    
                                    Spacer()
                                    
                                }
                                
                            }
                        }
                        Button(action: {
                            showingPokemonImporter.toggle()
                        }) {
                            ZStack {
                                
                                Rectangle()
                                    .frame(height: 75)
                                    .foregroundColor(.blue)
                                    .opacity(0.5)
                                    .cornerRadius(10)
                                    .padding(.trailing)
                                
                                HStack {
                                    
                                    Image(systemName: "square.and.arrow.down")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.blue)
                                        .padding(.leading)
                                    
                                    Text("Import")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                        .padding(.leading, 5)
                                    
                                    Spacer()
                                    
                                }
                                
                            }
                        }
                        .sheet(isPresented: $showingPokemonImporter) {
                            TeamMemberImportView(tIndex: tIndex, pIndex: memberIndex, eStorage: TeamMember(pokemon: pokemonDataList[0]), prez: presentationMode)
                        }
                    }
                    .padding(.bottom)
                    
                    if !showingGrid {
                        // This is the main list view
                        
                        LazyVStack {
                            
                            ForEach(filterAndSort().filter {
                                self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                            }, id: \.id) { pokemon in
                                
                                Button(action: {
                                    
                                    // MARK: Update the team with the selected Pokemon (list)
                                    
                                    sessionData.teams[tIndex].members[memberIndex] = TeamMember(pokemon: pokemon)
                                    
                                    editingIndex = memberIndex
                                    
                                    self.presentationMode.wrappedValue.dismiss()
                                    
                                }) {
                                    
                                    PokemonListOption(pokemon: pokemon)
                                        .padding(.bottom, 5)
                                    
                                }
                                
                            }
                            
                        }
                        
                    } else {
                        // This is the grid version of the list view
                        
                        LazyVGrid(columns: columns) {
                            ForEach(filterAndSort().filter {
                                searchText.isEmpty ? true : $0.name.lowercased().contains(searchText.lowercased())
                            }, id: \.id) { pokemon in
                                
                                Button(action: {
                                    
                                    // MARK: Update the team with the selected Pokemon (grid)
                                    
                                    sessionData.teams[tIndex].members[memberIndex] = TeamMember(pokemon: pokemon)
                                    
                                    editingIndex = memberIndex
                                    
                                    presentationMode.wrappedValue.dismiss()
                                    
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
            
            // MARK: Nav bar settings
            
                .navigationBarItems(leading: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel") }, trailing:
                    Button(action: {
                        self.showingGrid.toggle()
                    }) {
                        Image(systemName: showingGrid ? "list.bullet" : "square.grid.2x2")
                            .foregroundColor(.blue)
                            .padding(.leading)
                            .imageScale(.large)
                    })
                .navigationBarTitle(Text("Add Pokémon"), displayMode: .inline)
            
        }
        
    }
    
    // MARK: Functions
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
    
    func getBST(pokemon: Pokemon) -> Int {
        var answer = 0
        for eachStat in pokemon.baseStats {
            answer += eachStat
        }
        return answer
    }
    func getChunked() -> [[Pokemon]] {
        let answer = (filterAndSort().filter { self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased()) }).chunked(into: 5)
        
        return answer
    }
    
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
    
    func areFiltersOn() -> Bool {
        if typeFilters.count != 0 || abilityFilters.count != 0 || evolutionFilters.count != 0 || eggGroupFilters.count != 0 || growthRateFilters.count != 0 || canBeCaughtFilters.count != 0 || moveFilters.count != 0 || megaEvolutionFilters.count != 0 || alolanFormFilters.count != 0 || galarianFormFilters.count != 0 || EVYieldTypeFilters.count != 0 {
            return true
        } else {
            return false
        }
    }
    
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

//struct TeambuilderPokemonPicker_Previews: PreviewProvider {
//    static var previews: some View {
//        TeambuilderPokemonPicker(team: Team(), memberIndex: 0).environmentObject(SessionData())
//    }
//}

struct TeambuilderPokemonPickerRowView: View {
    
    // Variables
    @Binding var editingIndex: Int
    var array: [[Pokemon]]
    var index: Int
    @EnvironmentObject var sessionData: SessionData
    var memberIndex: Int
    var tIndex: Int
    var prez: Binding<PresentationMode>
    
    var body: some View {
        ForEach(array[index]) { pokemon in
            
            Button(action: {
                
                // MARK: Update the team with the selected Pokemon (grid)
                
                sessionData.teams[tIndex].members[memberIndex] = TeamMember(pokemon: pokemon)
                
                editingIndex = memberIndex
                
                prez.wrappedValue.dismiss()
                
            }) {
                Image(uiImage: UIImage(named: "\(pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50, alignment: .center)
            }
            
            Spacer()
        }
    }
    
}
