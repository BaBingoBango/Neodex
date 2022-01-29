//
//  MoveDexFilterView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/5/21.
//

import SwiftUI

struct MoveDexFilterView: View {
    
    // Variables
    @State var showingPokemonFilterPicker = false
    @Environment(\.presentationMode) var presentationMode
    @Binding var filterCount: Int
    @EnvironmentObject var sessionData: SessionData
    
    // Filter variables
    @Binding var typeFilters: [String]
    @Binding var categoryFilters: [String]
    @Binding var powerFilters: [String]
    @Binding var priorityFilters: [String]
    @Binding var accuracyFilters: [String]
    @Binding var pokemonFilters: [Pokemon]
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                
                VStack {
                    
                    // MARK: No Category
                    HStack {
                        
                        Button(action: {
                            if powerFilters.contains("100+") {
                                powerFilters.removeAll()
                            } else {
                                powerFilters.append("100+")
                            }
                        }) {
                            FilterOptionView(imageName: "bolt.fill", filterName: "100+ Power", color: powerFilters.contains("100+") ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            if accuracyFilters.contains("Perfect") {
                                accuracyFilters.removeAll()
                            } else {
                                accuracyFilters.append("Perfect")
                            }
                        }) {
                            FilterOptionView(imageName: "scope", filterName: "Always Hits", color: accuracyFilters.contains("Perfect") ? .blue : .secondary)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    
                    // MARK: Category
                    HeadingText(text: "Category")
                        .padding(.top)
                    
                    HStack {
                        
                        Button(action: {
                            if categoryFilters.contains("Physical") {
                                categoryFilters.removeAll()
                            } else if categoryFilters.count == 0 {
                                categoryFilters.append("Physical")
                            } else if categoryFilters.count == 1 {
                                categoryFilters.removeAll()
                                categoryFilters.append("Physical")
                            }
                        }) {
                            MoveDexFilterCategoryPicker(imageName: "burst.fill", color: categoryFilters.contains("Physical") ? .blue : .secondary, filterName: "Physical")
                        }
                        
                        Button(action: {
                            if categoryFilters.contains("Special") {
                                categoryFilters.removeAll()
                            } else if categoryFilters.count == 0 {
                                categoryFilters.append("Special")
                            } else if categoryFilters.count == 1 {
                                categoryFilters.removeAll()
                                categoryFilters.append("Special")
                            }
                        }) {
                            MoveDexFilterCategoryPicker(imageName: "wand.and.stars", color: categoryFilters.contains("Special") ? .blue : .secondary, filterName: "Special")
                        }
                        
                        Button(action: {
                            if categoryFilters.contains("Status") {
                                categoryFilters.removeAll()
                            } else if categoryFilters.count == 0 {
                                categoryFilters.append("Status")
                            } else if categoryFilters.count == 1 {
                                categoryFilters.removeAll()
                                categoryFilters.append("Status")
                            }
                        }) {
                            MoveDexFilterCategoryPicker(imageName: "waveform.path.ecg", color: categoryFilters.contains("Status") ? .blue : .secondary, filterName: "Status")
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    // MARK: Type
                    HeadingText(text: "Type")
                        .padding(.top)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            
                            VStack {
                                Button(action: {
                                    if typeFilters.contains("Normal") {
                                        typeFilters = typeFilters.filter({ $0 != "Normal" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Normal")
                                    } else if typeFilters.count == 1 {
                                        typeFilters.removeAll()
                                        typeFilters.append("Normal")
                                    }
                                }) {
                                    if typeFilters.contains("Normal") {
                                        CheckedType(types: ["Normal", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Normal", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Fighting") {
                                        typeFilters = typeFilters.filter({ $0 != "Fighting" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Fighting")
                                    } else if typeFilters.count == 1 {
                                        typeFilters.removeAll()
                                        typeFilters.append("Fighting")
                                    }
                                }) {
                                    if typeFilters.contains("Fighting") {
                                        CheckedType(types: ["Fighting", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Fighting", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Rock") {
                                        typeFilters = typeFilters.filter({ $0 != "Rock" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Rock")
                                    } else if typeFilters.count == 1 {
                                        typeFilters.removeAll()
                                        typeFilters.append("Rock")
                                    }
                                }) {
                                    if typeFilters.contains("Rock") {
                                        CheckedType(types: ["Rock", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Rock", ""])
                                    }
                                }
                            }
                            VStack {
                                Button(action: {
                                    if typeFilters.contains("Fire") {
                                        typeFilters = typeFilters.filter({ $0 != "Fire" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Fire")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Fire")
                                }
                                }) {
                                    if typeFilters.contains("Fire") {
                                        CheckedType(types: ["Fire", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Fire", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Poison") {
                                        typeFilters = typeFilters.filter({ $0 != "Poison" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Poison")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Poison")
                                }
                                }) {
                                    if typeFilters.contains("Poison") {
                                        CheckedType(types: ["Poison", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Poison", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Ghost") {
                                        typeFilters = typeFilters.filter({ $0 != "Ghost" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Ghost")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Ghost")
                                }
                                }) {
                                    if typeFilters.contains("Ghost") {
                                        CheckedType(types: ["Ghost", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Ghost", ""])
                                    }
                                }
                            }
                            VStack {
                                Button(action: {
                                    if typeFilters.contains("Water") {
                                        typeFilters = typeFilters.filter({ $0 != "Water" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Water")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Water")
                                }
                                }) {
                                    if typeFilters.contains("Water") {
                                        CheckedType(types: ["Water", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Water", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Ground") {
                                        typeFilters = typeFilters.filter({ $0 != "Ground" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Ground")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Ground")
                                }
                                }) {
                                    if typeFilters.contains("Ground") {
                                        CheckedType(types: ["Ground", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Ground", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Dragon") {
                                        typeFilters = typeFilters.filter({ $0 != "Dragon" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Dragon")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Dragon")
                                }
                                }) {
                                    if typeFilters.contains("Dragon") {
                                        CheckedType(types: ["Dragon", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Dragon", ""])
                                    }
                                }
                            }
                            VStack {
                                Button(action: {
                                    if typeFilters.contains("Electric") {
                                        typeFilters = typeFilters.filter({ $0 != "Electric" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Electric")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Electric")
                                }
                                }) {
                                    if typeFilters.contains("Electric") {
                                        CheckedType(types: ["Electric", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Electric", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Flying") {
                                        typeFilters = typeFilters.filter({ $0 != "Flying" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Flying")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Flying")
                                }
                                }) {
                                    if typeFilters.contains("Flying") {
                                        CheckedType(types: ["Flying", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Flying", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Dark") {
                                        typeFilters = typeFilters.filter({ $0 != "Dark" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Dark")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Dark")
                                }
                                }) {
                                    if typeFilters.contains("Dark") {
                                        CheckedType(types: ["Dark", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Dark", ""])
                                    }
                                }
                            }
                            VStack {
                                Button(action: {
                                    if typeFilters.contains("Grass") {
                                        typeFilters = typeFilters.filter({ $0 != "Grass" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Grass")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Grass")
                                }
                                }) {
                                    if typeFilters.contains("Grass") {
                                        CheckedType(types: ["Grass", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Grass", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Psychic") {
                                        typeFilters = typeFilters.filter({ $0 != "Psychic" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Psychic")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Psychic")
                                }
                                }) {
                                    if typeFilters.contains("Psychic") {
                                        CheckedType(types: ["Psychic", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Psychic", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Steel") {
                                        typeFilters = typeFilters.filter({ $0 != "Steel" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Steel")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Steel")
                                }
                                }) {
                                    if typeFilters.contains("Steel") {
                                        CheckedType(types: ["Steel", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Steel", ""])
                                    }
                                }
                            }
                            VStack {
                                Button(action: {
                                    if typeFilters.contains("Ice") {
                                        typeFilters = typeFilters.filter({ $0 != "Ice" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Ice")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Ice")
                                }
                                }) {
                                    if typeFilters.contains("Ice") {
                                        CheckedType(types: ["Ice", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Ice", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Bug") {
                                        typeFilters = typeFilters.filter({ $0 != "Bug" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Bug")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Bug")
                                }
                                }) {
                                    if typeFilters.contains("Bug") {
                                        CheckedType(types: ["Bug", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Bug", ""])
                                    }
                                }
                                Button(action: {
                                    if typeFilters.contains("Fairy") {
                                        typeFilters = typeFilters.filter({ $0 != "Fairy" })
                                    } else if typeFilters.count != 1 {
                                        typeFilters.append("Fairy")
                                } else if typeFilters.count == 1 {
                                    typeFilters.removeAll()
                                    typeFilters.append("Fairy")
                                }
                                }) {
                                    if typeFilters.contains("Fairy") {
                                        CheckedType(types: ["Fairy", ""])
                                    } else {
                                        PokemonDetailTypeView(types: ["Fairy", ""])
                                    }
                                }
                            }
                            
                        }
                        .padding(.horizontal)
                        
                    }
                    
                    // MARK: Priority
                    HeadingText(text: "Priority")
                        .padding(.top)
                    
                    HStack {
                        
                        Button(action:{
                            if priorityFilters.contains("Positive") {
                                priorityFilters.removeAll()
                            } else if priorityFilters.count == 1 {
                                priorityFilters.removeAll()
                                priorityFilters.append("Positive")
                            } else if priorityFilters.count == 0 {
                                priorityFilters.append("Positive")
                            }
                        }) {
                            FilterOptionView(imageName: "goforward.plus", filterName: "Positive Priority", color: priorityFilters.contains("Positive") ? .blue : .secondary)
                        }
                        
                        Button(action:{
                            if priorityFilters.contains("Negative") {
                                priorityFilters.removeAll()
                            } else if priorityFilters.count == 1 {
                                priorityFilters.removeAll()
                                priorityFilters.append("Negative")
                            } else if priorityFilters.count == 0 {
                                priorityFilters.append("Negative")
                            }
                        }) {
                            FilterOptionView(imageName: "gobackward.minus", filterName: "Negative Priority", color: priorityFilters.contains("Negative") ? .blue : .secondary)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    // MARK: Pokemon
                    HeadingText(text: "Compatibility")
                        .padding(.top)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            
                            Button(action: {
                                self.showingPokemonFilterPicker.toggle()
                            }) {
                                FilterOptionView(imageName: "plus", filterName: "Add Pokémon Filter", color: .secondary)
                            }
                            .frame(width: 195)
                            .sheet(isPresented: $showingPokemonFilterPicker) {
                                
                                NavigationView {
                                    MoveDexFilterPokedexView(pokemonFilters: $pokemonFilters).environmentObject(sessionData)
                                }
                                
                            }
                            
                            if pokemonFilters.count == 0 {
                                FilterOptionView(imageName: "plus", filterName: "Add Pokémon Filter", color: .secondary)
                                    .hidden()
                            }
                            
                            ForEach(pokemonFilters, id: \.name) { filter in
                                
                                Button(action: {
                                    
                                    pokemonFilters = pokemonFilters.filter({
                                        $0.name != filter.name
                                    })
                                    
                                }) {
                                    ZStack {
                                        FilterOptionView(imageName: "person.fill", filterName: filter.name, color: .blue)
                                            .frame(width: 195)
                                        HStack {
                                            Spacer()
                                            Image(systemName: "xmark.circle.fill")
                                                .resizable()
                                                .frame(width: 25, height: 25)
                                                .foregroundColor(.white)
                                        }
                                        .padding(.trailing)
                                    }
                                }
                                
                            }
                            
                        }
                        .padding(.horizontal)
                    }
                    
                }
                .padding(.vertical)
                
            }
           
            .navigationBarTitle(filterCount == 1 ? Text("\(filterCount) Result") : Text("\(filterCount) Results"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                powerFilters.removeAll()
                typeFilters.removeAll()
                accuracyFilters.removeAll()
                categoryFilters.removeAll()
                typeFilters.removeAll()
                priorityFilters.removeAll()
                pokemonFilters.removeAll()
            }) {
                Text("Clear All")
                    .fontWeight(.regular)
            }.disabled(countMoveFilters() == 0), trailing: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
            })
        }
        
    }
    
    // Functions
    func countMoveFilters() -> Int {
        
        return powerFilters.count + typeFilters.count + accuracyFilters.count + categoryFilters.count + priorityFilters.count + pokemonFilters.count
        
    }
    
}

//struct MoveDexFilterView_Previews: PreviewProvider {
//    static var previews: some View {
//        MoveDexFilterView()
//    }
//}

struct MoveDexFilterCategoryPicker: View {
    
    // Variables
    var imageName: String
    var color: Color
    var filterName: String
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(height: 150)
                .foregroundColor(color)
                .cornerRadius(20)
            
            VStack {
                
                Image(systemName: imageName)
                    .resizable()
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                
                Text(filterName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 5)
                
            }
            
        }
        
    }
}

struct MoveDexFilterPokedexView: View {
    
    // Variables
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
    @State var showingSorting = false
    @State var showingGrid = false
    @State var showingHelp = false
    @State var showingSettings = false
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    
    // Move dex only
    @Binding var pokemonFilters: [Pokemon]
    
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
    
    /// An array of grid items to size and position each row of the grid. It was provided by Developer Support.
    var columns: [GridItem] = Array(repeating: .init(.flexible()), count: 5)
    
    var body: some View {
        
        ScrollView {
            
            LazyVStack {
                
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
                    .sheet(isPresented: $showingFilters) {
                        PokedexFilterView(filterCount: filterCount, filtersOn: filtersOn, typeFilters: $typeFilters, abilityFilters: $abilityFilters, evolutionFilters: $evolutionFilters, eggGroupFilters: $eggGroupFilters, growthRateFilters: $growthRateFilters, canBeCaughtFilters: $canBeCaughtFilters, moveFilters: $moveFilters, megaEvolutionFilters: $megaEvolutionFilters, alolanFormFilters: $alolanFormFilters, galarianFormFilters: $galarianFormFilters, EVYieldTypeFilters: $EVYieldTypeFilters)
                    }
                    
//                    NavigationLink(destination: FaceOffView().environmentObject(sessionData)) {
//                        PokedexFaceOffButtonView(imageName: "bolt.circle.fill", text: "Face-Off", filtersOn: filtersOn)
//                    }
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
                    // This is the main list view
                    
                    ForEach(filterAndSort().filter {
                        self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                    }, id: \.id) { pokemon in

                        Button(action: {
                            pokemonFilters.append(pokemon)
                            self.presentationMode.wrappedValue.dismiss()
                        }) {

                                PokemonListOption(pokemon: pokemon)
                                    .padding(.bottom, 5)

                        }
                    }
                    
                } else {
                    // This is the grid version of the list view
                    
                    LazyVGrid(columns: columns) {
                        ForEach(filterAndSort().filter {
                            searchText.isEmpty ? true : $0.name.lowercased().contains(searchText.lowercased())
                        }, id: \.id) { pokemon in
                            
                            Button(action: {
                                pokemonFilters.append(pokemon)
                                self.presentationMode.wrappedValue.dismiss()
                            }) {
                                
                                Image(uiImage: UIImage(named: "\(pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50, alignment: .center)
                                
                            }
                            
                        }
                    }
                    
//                    ForEach(0..<getChunked().count) { index in
//                        HStack {
//                            
//                            Spacer()
//                            
//                            if !(index >= getChunked().count) {
//                                MoveDexRowView(array: getChunked(), index: index, pokemonFilters: $pokemonFilters, presentationMode: presentationMode)
//                            }
//                            
//                            if index == getChunked().count - 1 {
//                                
//                                ForEach((1..<(6 - (getChunked()[index]).count)), id: \.self) { i in
//                                    
//                                    Image("Bulbasaur-sprite")
//                                        .resizable()
//                                        .frame(width: 50, height: 50, alignment: .center)
//                                        .hidden()
//                                    Spacer()
//                                    
//                                }
//                            
//
//                            }
//                            
//                        }
//                        
//                    }
                    
                    
                }
                
            }
            .padding(.bottom)
        }
        
        .navigationBarItems(leading: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel") }, trailing: LeadingNavButtons(sortCondition: $sortCondition, sortDirection: $sortDirection, showingSorting: $showingSorting, showingGrid: $showingGrid, dontIncludeSortButton: true))
        .navigationBarTitle(Text("Add Pokémon Filter"), displayMode: .inline)
        
    }
    
    // Functions
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

struct MoveDexRowView: View {
    
    // Variables
    var array: [[Pokemon]]
    var index: Int
    @Binding var pokemonFilters: [Pokemon]
    var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        ForEach(array[index]) { pokemon in
            
            Button(action: {
                pokemonFilters.append(pokemon)
                self.presentationMode.wrappedValue.dismiss()
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
