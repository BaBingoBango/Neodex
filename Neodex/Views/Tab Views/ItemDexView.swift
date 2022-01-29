//
//  ItemDexView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/3/21.
//

import SwiftUI

struct ItemDexView: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText : String = ""
    @State var showingSorting = false
    @State var showingFilters = false
    private var filterCount: Binding<Int> { Binding (
        get: { return runFilters().count },
        set: { _ in }
        )
    }
    @State var showingHelp = false
    @State var showingSettings = false
    @State var showingGrid = false
    
    // Filter variables
    @State var pokemonFilters: [Pokemon] = []
    @State var categoryFilters: [ItemType] = []
    
    // Sort variables
    @State var sortCondition: String = "Alphabetical"
    @State var sortDirection: Int = 0
    
    var body: some View {
        
        let chunkedItems = filterAndSort().filter { searchText.isEmpty ? true : $0.name.lowercased().contains(searchText.lowercased()) }.chunked(into: 5)
        
        ScrollView {
            LazyVStack {
                
                SearchBar(text: $searchText)
                    .padding(.vertical)
                
                HStack {
                    
                    Button(action: {
                        showingFilters.toggle()
                    }) {
                        DexEditButton(imageName: "line.horizontal.3.decrease.circle", name: pokemonFilters.count + categoryFilters.count >= 1 ? (pokemonFilters.count + categoryFilters.count == 1 ? "1 Filter On" : "\(pokemonFilters.count + categoryFilters.count) Filters On") : "Filter", backColor: pokemonFilters.count + categoryFilters.count >= 1 ? .blue : .secondary, frontColor: pokemonFilters.count + categoryFilters.count >= 1 ? .white : .black)
                    }
                    .sheet(isPresented: $showingFilters) {
                        ItemDexFilterView(filterCount: filterCount, pokemonFilters: $pokemonFilters, categoryFilters: $categoryFilters).environmentObject(sessionData)
                    }
                    
                    Button(action: {
                        showingSorting.toggle()
                    }) {
                        DexEditButton(imageName: "arrow.up.arrow.down", name: (sortCondition != "Alphabetical" || sortDirection != 0) ? "Sorting" : "Sort", backColor: (sortCondition != "Alphabetical" || sortDirection != 0) ? .blue : .secondary, frontColor: (sortCondition != "Alphabetical" || sortDirection != 0) ? .white : .black)
                    }
                    .sheet(isPresented: $showingSorting) {
                        ItemDexSortView(sortCondition: $sortCondition, sortDirection: $sortDirection)
                    }
                    
                }
                .padding([.leading, .bottom, .trailing])
                
                if !showingGrid {
                    
                    ForEach(filterAndSort().filter {
                        self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                    }, id: \.name) { item in
                        
                        NavigationLink(destination: ItemDetailView(item: item, buttonText: "").environmentObject(sessionData)) {
                            ZStack {
                                Rectangle()
                                    .frame(height: 75)
                                    .foregroundColor(colorScheme == .dark ? .secondary : .white)
                                    .opacity(colorScheme == .dark ? 0.4 : 1.0)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                    .shadow(color: .secondary, radius: colorScheme == .dark ? 0 : 15)
                                
                                HStack {
                                    
                                    if UIImage(named: item.name) != nil {
                                        
                                        Image(item.name)
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                        
                                    } else {
                                        
                                        Image("Question Mark")
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                        
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        
                                        Text(item.name)
                                            .foregroundColor(.primary)
                                            .font(.system(size: 23))
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)

                                    }
                                    
                                    Spacer()
                                    
                                }
                                .padding(.leading, 30)
                                
                            }
                        }
                        .padding(.bottom, 5)
                        
                    }
                    
                } else {
                    
                    // MARK: Grid View
                    
                    ForEach(0 ..< chunkedItems.count) { index in
                        
                        if (index <= (chunkedItems.count - 1)) {
                            
                            HStack {
                                
                                Spacer()
                                
                                ItemRowView(chunkedItems: chunkedItems, index: index).environmentObject(sessionData)
                                
                                if index == chunkedItems.count - 1 {
                                    
                                    ForEach((1..<(6 - (chunkedItems[index]).count)), id: \.self) { i in
                                        
                                        Image("Bulbasaur-sprite")
                                            .resizable()
                                            .frame(width: 50, height: 50, alignment: .center)
                                            .hidden()
                                        Spacer()
                                        
                                    }
                                

                                }
                                
                            
                            }
                            
                        }
                        
                    }
                    .padding(.bottom)
                    
                }
                
            }
        }
        
        .navigationBarTitle(Text("Item Dex"))
        .navigationBarItems(trailing: ItemDexTrailingNavButtons(showingHelp: $showingHelp, showingSettings: $showingSettings, showingGrid: $showingGrid).environmentObject(sessionData))
        
    }
    
    // Functions
    func filterAndSort() -> [Item] {
        let answer = runFilters().sorted(by: {
            
            switch sortCondition {
            
            // 1: Alphabetical
            case "Alphabetical":
                if sortDirection == 0 {
                    return $0.name < $1.name
                } else {
                    return $0.name > $1.name
                }
                
            // 2: No. of evolving pokemon
            case "No. of Evolving Pokémon":
                if sortDirection == 0 {
                    return $0.evoEffects.count < $1.evoEffects.count
                } else {
                    return $0.evoEffects.count > $1.evoEffects.count
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
    
    func runFilters() -> [Item] {
        var answer = Item.itemList
        
        // 1: Causes Evolution
        for eachPokemonFilter in pokemonFilters {
            answer = answer.filter({
                $0.evoEffects.contains(eachPokemonFilter.name)
            })
        }
        
        // 2: Item type
        if categoryFilters.count >= 1 {
            answer = answer.filter({
                $0.category == categoryFilters[0]
            })
        }
        
        return answer
    }
    
}

struct ItemDexView_Previews: PreviewProvider {
    static var previews: some View {
        ItemDexView().environmentObject(SessionData())

    }
}

struct ItemDexTrailingNavButtons: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @Binding var showingHelp: Bool
    @Binding var showingSettings: Bool
    @Binding var showingGrid: Bool
    
    var body: some View {
        HStack {
            
            Button(action: {
                showingGrid.toggle()
            }) {
                Image(systemName: showingGrid ? "list.bullet" : "square.grid.2x2")
                    .foregroundColor(.blue)
                    .padding(.trailing)
                    .imageScale(.large)
            }
            
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
                    Text("Item help guide...?")
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

struct ItemRowView: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    var chunkedItems: [[Item]]
    var index: Int
    
    var body: some View {
        
        ForEach(chunkedItems[index], id: \.name) { item in
            
            if UIImage(named: item.name) == nil {
                
                NavigationLink(destination: ItemDetailView(item: item, buttonText: "").environmentObject(sessionData)) {
                    
                    Image("Question Mark")
                        .resizable()
                        .frame(width: 50, height: 50, alignment: .center)
                    
                }
                
            } else {
                
                NavigationLink(destination: ItemDetailView(item: item, buttonText: "").environmentObject(sessionData)) {
                    Image(item.name)
                        .resizable()
                        .frame(width: 50, height: 50, alignment: .center)
                }
                
            }
            
            Spacer()
                
        }
        
    }
    
}
