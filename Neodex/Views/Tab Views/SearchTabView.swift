//
//  SearchTabView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/12/21.
//

import SwiftUI

struct SearchTabView: View {
    
    // Variables
    @State var searchText = ""
    @State var showingPokemon = true
    @State var showingMoves = true
    @State var showingItems = true
    @State var showingAbilities = true
    @State var showingTypes = true
    @State var showingNatures = true
    @State var showingFilters = false
    var types = ["Normal", "Fire", "Water", "Electric", "Grass", "Ice", "Fighting", "Poison", "Ground", "Flying", "Psychic", "Bug", "Rock", "Ghost", "Dragon", "Dark", "Steel", "Fairy"]
    var natures = ["Hardy", "Lonely", "Brave", "Adamant", "Naughty", "Bold", "Docile", "Relaxed", "Impish", "Lax", "Timid", "Hasty", "Serious", "Jolly", "Naive", "Modest", "Mild", "Quiet", "Bashful", "Rash", "Calm", "Gentle", "Sassy", "Careful", "Quirky"]
    private var searchResults: Binding<Int> { Binding (
        get: { return getSearchResults() },
        set: { _ in }
        )
    }
    @EnvironmentObject var sessionData: SessionData
    @State var showingSettings = false
    
    var body: some View {
        
//        NavigationView {
            
            ScrollView {
                LazyVStack {
                    
                    SearchBar(text: $searchText, placeholder: "Pokémon, Moves, etc.")
                    
                    // MARK: Searching View
                    
                    if searchText != "" {
                        
                        HStack {
                            
                            Button(action: {
                                showingFilters.toggle()
                            }) {
                                DexEditButton(imageName: "line.horizontal.3.decrease.circle", name: (showingPokemon == false || showingMoves == false || showingItems == false || showingAbilities == false || showingTypes == false || showingNatures == false) ? "Filtering" : "Filter", backColor: (showingPokemon == false || showingMoves == false || showingItems == false || showingAbilities == false || showingTypes == false || showingNatures == false) ? .blue : .secondary, frontColor: (showingPokemon == false || showingMoves == false || showingItems == false || showingAbilities == false || showingTypes == false || showingNatures == false) ? .white : .black)
                            }
                            .sheet(isPresented: $showingFilters) {
                                SearchFilterView(searchResults: searchResults, showingPokemon: $showingPokemon, showingMoves: $showingMoves, showingItems: $showingItems, showingAbilities: $showingAbilities, showingTypes: $showingTypes, showingNatures: $showingNatures)
                            }
                            
    //                        DexEditButton(imageName: "arrow.up.arrow.down", name: "Reorder", backColor: .secondary, frontColor: .black)
                            
                        }
                        .padding([.top, .leading, .trailing])
                        
                        if searchResults.wrappedValue == 0 {
                            
                            Text("No Results")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.top, 100)
                            
                            Text("There were no results for \"\(searchText)\". Try a new search or try adjusting the filters.")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 5)
                            
                        }
                        
                        // Extra argument VStack (ignore)
                        LazyVStack {
                            
                            // Pokémon display area
                            
                            if showingPokemon {
                                
                                if (pokemonDataList.filter {
                                    self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                                }.count >= 1) {
                                    HeadingText(text: "Pokémon")
                                        .padding(.top)
                                }
                                
                                ForEach(pokemonDataList.filter {
                                    self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                                }, id: \.id) { pokemon in
                                    NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData).navigationBarTitle(Text(""), displayMode: .inline)) {
                                        PokemonListOption(pokemon: pokemon)
                                            .padding(.bottom, 5)
                                    }
                                }
                                
                            }
                            
                            // Move display area
                            
                            if showingMoves {
                                
                                if (moveDataList.filter {
                                    self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                                }.count >= 1) {
                                    
                                    HeadingText(text: "Moves")
                                        .padding(.top)
                                    
                                }
                                
                                ForEach(moveDataList.filter {
                                    self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                                }, id: \.name) { move in
                                    NavigationLink(destination: MoveDetailView(move: move).environmentObject(sessionData)) {
                                        MoveOption(move: move, removeTopPadding: true)
                                    }
                                }
                                
                            }
                        }
                        
                        // Item display area
                        
                        if showingItems {
                            
                            if (Item.itemList.filter {
                                self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                            }.count >= 1) {
                                
                                HeadingText(text: "Items")
                                    .padding(.top)
                                
                            }
                            
                            ForEach(Item.itemList.filter {
                                self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                            }, id: \.name) { item in
                                
                                SearchViewItemOption(item: item).environmentObject(sessionData)
                                
                            }
                        }
                        
                        // Ability display area
                        
                        if showingAbilities {
                            
                            if (Ability.abilityList.filter {
                                self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                            }.count >= 1) {
                                
                                HeadingText(text: "Abilities")
                                    .padding(.top)
                                
                            }
                            
                            ForEach(Ability.abilityList.filter {
                                self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                            }, id: \.name) { ability in
                                
                                NavigationLink(destination: AbilityDetailView(name: ability.name, detail: ability.detail, buttonText: "").environmentObject(sessionData)) {
                                    NavAbilityListOption(ability: ability).environmentObject(sessionData)
                                }
                                    .padding(.bottom, 5)
                            }
                        
                        }
                        // Type display area
                        
                        if showingTypes {
                            
                            if (types.filter {
                                self.searchText.isEmpty ? true : $0.lowercased().contains(self.searchText.lowercased())
                            }.count >= 1) {
                                
                                HeadingText(text: "Types")
                                    .padding(.top)
                                
                            }
                            
                            ForEach(types.filter {
                                self.searchText.isEmpty ? true : $0.lowercased().contains(self.searchText.lowercased())
                            }, id: \.self) { type in
                                
                                NavigationLink(destination: TypeDetailViewN(type: Type.typeLookup(name: type)!).navigationBarTitle(Text(""), displayMode: .inline)) {
                                    ZStack {
                                        
                                        Rectangle()
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                            .foregroundColor(typeColorDelegator(type: type))
                                            .frame(height: 75)
                                        
                                        Text(type.uppercased())
                                            .font(Font.custom("Andale Mono", size: 35))
                                            .foregroundColor(.white)
                                        
                                    }
                                }
                                
                            }
                            
                        }
                        
                        // Nature display area
                        
                        if showingNatures {
                            
                            if (natures.filter {
                                self.searchText.isEmpty ? true : $0.lowercased().contains(self.searchText.lowercased())
                            }.count >= 1) {
                                
                                HeadingText(text: "Natures")
                                    .padding(.top)
                                
                            }
                            
                            ForEach(natures.filter {
                                self.searchText.isEmpty ? true : $0.lowercased().contains(self.searchText.lowercased())
                            }, id: \.self) { nature in
                                
                                NavigationLink(destination: NatureDetailView(nature: Nature.natureList[Nature.natureList.firstIndex(where: { $0.name == nature }) ?? 0]).environmentObject(sessionData)) {
                                    
                                    NatureOption(nature: Nature.natureList[Nature.natureList.firstIndex(where: { $0.name == nature })!])
                                    
                                }
                                
                            }
                            
                        }
                        
                    } else {
                        
                        // MARK: Not Yet Searching View
                        
                        HStack {
                            
                            NavigationLink(destination: PokedexView().environmentObject(sessionData)) {
                                SearchViewPreviewButton(color: .blue, text: "Pokémon", imageName: "person.fill")
                                    .padding(.trailing, 5)
                            }
                            
                            NavigationLink(destination: MoveDexView().environmentObject(sessionData)) {
                                SearchViewPreviewButton(color: .red, text: "Moves", imageName: "burst.fill")
                                    .padding(.leading, 5)
                            }
                            
                        }
                        .padding([.top, .leading, .trailing])
                        
                        HStack {
                            
                            NavigationLink(destination: ItemDexView().environmentObject(sessionData)) {
                                SearchViewPreviewButton(color: .flying, text: "Items", imageName: "cube.fill")
                                    .padding(.trailing, 5)
                            }
                            
                            NavigationLink(destination: AbilityDexView().environmentObject(sessionData)) {
                                SearchViewPreviewButton(color: .gold, text: "Abilities", imageName: "sparkles")
                                    .padding(.leading, 5)
                            }
                            
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        HStack {
                            
                            NavigationLink(destination: TypeOMaticView().environmentObject(sessionData)) {
                                SearchViewPreviewButton(color: .gray, text: "Types", imageName: "circle.grid.cross.fill")
                                    .padding(.trailing, 5)
                            }
                            
                            NavigationLink(destination: NatureGuide().environmentObject(sessionData)) {
                                SearchViewPreviewButton(color: .green, text: "Natures", imageName: "leaf.fill")
                                    .padding(.leading, 5)
                            }
                            
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                    }
                    
                }
                .padding(.bottom)
            }
            
                .navigationBarTitle(Text("Search"))
                .navigationBarItems(trailing: FeatureGalleryTrailingNavButtons(showingSettings: $showingSettings).environmentObject(sessionData))
//        }
    }
    
    // Functions
    func getSearchResults() -> Int {
        
        var answer = 0
        
        if showingPokemon {
            answer += pokemonDataList.filter {
                self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
            }.count
        }
        
        if showingMoves {
            answer += moveDataList.filter {
                self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
            }.count
        }
        
        if showingItems {
            answer += Item.itemList.filter {
                self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
            }.count
        }
    
        if showingAbilities {
            answer += Ability.abilityList.filter {
                self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
            }.count
        }
    
        if showingTypes {
            answer += types.filter {
                self.searchText.isEmpty ? true : $0.lowercased().contains(self.searchText.lowercased())
            }.count
        }
    
        if showingNatures {
            answer += natures.filter {
                self.searchText.isEmpty ? true : $0.lowercased().contains(self.searchText.lowercased())
            }.count
        }
        
        return answer
        
    }
    
}

struct SearchTabView_Previews: PreviewProvider {
    static var previews: some View {
        SearchTabView().environmentObject(SessionData())
    }
}

struct SearchViewItemOption: View {
    
    // Variables
    var item: Item
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
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
                    
                    Image(item.name)
                        .resizable()
                        .frame(width: 60, height: 60)
                    
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
}

struct SearchViewPreviewButton: View {
    
    // Variables
    var color: Color
    var text: String
    var imageName: String
    
    var body: some View {
        ZStack {
            
            Rectangle()
                .frame(height: 130)
                .cornerRadius(15)
                .foregroundColor(color)
            
            Image(systemName: imageName)
                .resizable()
                .foregroundColor(.white)
                .frame(width: 90, height: 90)
                .opacity(0.225)
            
            Text(text.uppercased())
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
        }
    }
}

struct NavAbilityListOption: View {
    
    // Variables
    var ability: Ability
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .cornerRadius(10)
                .padding(.horizontal)
                .frame(height: 50, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                .shadow(color: .secondary, radius: 15)
            
            HStack {
                
                VStack(alignment: .leading) {
                    Text(ability.name)
                        .foregroundColor(.primary)
                        .font(.system(size: 23))
                        .fontWeight(.bold)
                }
                
                Spacer()
                
            }
            .padding(.leading, 30)
            
        }
        
    }
}

struct NoResultsAlert: View {
    
    var body: some View {
        
        VStack {
            
            
            
        }
        
    }
    
}
