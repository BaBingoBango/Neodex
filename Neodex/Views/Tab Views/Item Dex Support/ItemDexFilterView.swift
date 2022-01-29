//
//  ItemDexFilterView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/8/21.
//

import SwiftUI

struct ItemDexFilterView: View {
    
    // Variables
    @State var showingPokemonFilterPicker = false
    @Environment(\.presentationMode) var presentationMode
    @Binding var filterCount: Int
    @EnvironmentObject var sessionData: SessionData
    
    // Filter variables
    @Binding var pokemonFilters: [Pokemon]
    @Binding var categoryFilters: [ItemType]
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    
                    HeadingText(text: "Item Type")
                        .padding(.top)
                    
                    HStack {
                        
                        Button(action: {
                            if categoryFilters.isEmpty {
                                categoryFilters.append(.battle)
                            } else if categoryFilters[0] == .battle {
                                categoryFilters.removeAll()
                            } else {
                                categoryFilters.removeAll()
                                categoryFilters.append(.battle)
                            }
                        }) {
                            FilterOptionView(imageName: "burst.fill", filterName: "Battle Items", color: categoryFilters.contains(.battle) ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            if categoryFilters.isEmpty {
                                categoryFilters.append(.enhancer)
                            } else if categoryFilters[0] == .enhancer {
                                categoryFilters.removeAll()
                            } else {
                                categoryFilters.removeAll()
                                categoryFilters.append(.enhancer)
                            }
                        }) {
                            FilterOptionView(imageName: "pills.fill", filterName: "Enhancers", color: categoryFilters.contains(.enhancer) ? .blue : .secondary)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        
                        Button(action: {
                            if categoryFilters.isEmpty {
                                categoryFilters.append(.megaEvolution)
                            } else if categoryFilters[0] == .megaEvolution {
                                categoryFilters.removeAll()
                            } else {
                                categoryFilters.removeAll()
                                categoryFilters.append(.megaEvolution)
                            }
                        }) {
                            FilterOptionView(imageName: "bolt.fill", filterName: "Mega Stones", color: categoryFilters.contains(.megaEvolution) ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            if categoryFilters.isEmpty {
                                categoryFilters.append(.heldItems)
                            } else if categoryFilters[0] == .heldItems {
                                categoryFilters.removeAll()
                            } else {
                                categoryFilters.removeAll()
                                categoryFilters.append(.heldItems)
                            }
                        }) {
                            FilterOptionView(imageName: "hand.raised.fill", filterName: "Held Items", color: categoryFilters.contains(.heldItems) ? .blue : .secondary)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    // Extra argument stack
                    VStack {
                        
                        HStack {
                            
                            Button(action: {
                                if categoryFilters.isEmpty {
                                    categoryFilters.append(.zcrystals)
                                } else if categoryFilters[0] == .zcrystals {
                                    categoryFilters.removeAll()
                                } else {
                                    categoryFilters.removeAll()
                                    categoryFilters.append(.zcrystals)
                                }
                            }) {
                                FilterOptionView(imageName: "suit.diamond.fill", filterName: "Z-Crystals", color: categoryFilters.contains(.zcrystals) ? .blue : .secondary)
                            }
                            
                            Button(action: {
                                if categoryFilters.isEmpty {
                                    categoryFilters.append(.evolution)
                                } else if categoryFilters[0] == .evolution {
                                    categoryFilters.removeAll()
                                } else {
                                    categoryFilters.removeAll()
                                    categoryFilters.append(.evolution)
                                }
                            }) {
                                FilterOptionView(imageName: "arrow.up", filterName: "Evolution", color: categoryFilters.contains(.evolution) ? .blue : .secondary)
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            
                            Button(action: {
                                if categoryFilters.isEmpty {
                                    categoryFilters.append(.keyItems)
                                } else if categoryFilters[0] == .keyItems {
                                    categoryFilters.removeAll()
                                } else {
                                    categoryFilters.removeAll()
                                    categoryFilters.append(.keyItems)
                                }
                            }) {
                                FilterOptionView(imageName: "key.fill", filterName: "Key Items", color: categoryFilters.contains(.keyItems) ? .blue : .secondary)
                            }
                            
                            Button(action: {
                                if categoryFilters.isEmpty {
                                    categoryFilters.append(.berriesAndApricorns)
                                } else if categoryFilters[0] == .berriesAndApricorns {
                                    categoryFilters.removeAll()
                                } else {
                                    categoryFilters.removeAll()
                                    categoryFilters.append(.berriesAndApricorns)
                                }
                            }) {
                                FilterOptionView(imageName: "leaf.fill", filterName: "Berries & Apricorns", color: categoryFilters.contains(.berriesAndApricorns) ? .blue : .secondary)
                            }
                            
                            
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            
                            Button(action: {
                                if categoryFilters.isEmpty {
                                    categoryFilters.append(.medicine)
                                } else if categoryFilters[0] == .medicine {
                                    categoryFilters.removeAll()
                                } else {
                                    categoryFilters.removeAll()
                                    categoryFilters.append(.medicine)
                                }
                            }) {
                                FilterOptionView(imageName: "bandage.fill", filterName: "Medicine", color: categoryFilters.contains(.medicine) ? .blue : .secondary)
                            }
                            
                            Button(action: {
                                if categoryFilters.isEmpty {
                                    categoryFilters.append(.fossils)
                                } else if categoryFilters[0] == .fossils {
                                    categoryFilters.removeAll()
                                } else {
                                    categoryFilters.removeAll()
                                    categoryFilters.append(.fossils)
                                }
                            }) {
                                FilterOptionView(imageName: "ant.circle.fill", filterName: "Fossils", color: categoryFilters.contains(.fossils) ? .blue : .secondary)
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            
                            Button(action: {
                                if categoryFilters.isEmpty {
                                    categoryFilters.append(.treasures)
                                } else if categoryFilters[0] == .treasures {
                                    categoryFilters.removeAll()
                                } else {
                                    categoryFilters.removeAll()
                                    categoryFilters.append(.treasures)
                                }
                            }) {
                                FilterOptionView(imageName: "sparkles", filterName: "Treasures", color: categoryFilters.contains(.treasures) ? .blue : .secondary)
                            }
                            
                            Button(action: {
                                if categoryFilters.isEmpty {
                                    categoryFilters.append(.ingredients)
                                } else if categoryFilters[0] == .ingredients {
                                    categoryFilters.removeAll()
                                } else {
                                    categoryFilters.removeAll()
                                    categoryFilters.append(.ingredients)
                                }
                            }) {
                                FilterOptionView(imageName: "fork.knife", filterName: "Ingredients", color: categoryFilters.contains(.ingredients) ? .blue : .secondary)
                            }
                            
                        }
                        .padding(.horizontal)
                        
                    }
                    
                    HStack {
                        
                        Button(action: {
                            if categoryFilters.isEmpty {
                                categoryFilters.append(.pokeBalls)
                            } else if categoryFilters[0] == .pokeBalls {
                                categoryFilters.removeAll()
                            } else {
                                categoryFilters.removeAll()
                                categoryFilters.append(.pokeBalls)
                            }
                        }) {
                            FilterOptionView(imageName: "circle.dashed.inset.fill", filterName: "Poké Balls", color: categoryFilters.contains(.pokeBalls) ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            if categoryFilters.isEmpty {
                                categoryFilters.append(.machines)
                            } else if categoryFilters[0] == .machines {
                                categoryFilters.removeAll()
                            } else {
                                categoryFilters.removeAll()
                                categoryFilters.append(.machines)
                            }
                        }) {
                            FilterOptionView(imageName: "opticaldisc", filterName: "Move Machines", color: categoryFilters.contains(.machines) ? .blue : .secondary)
                        }
                        
                    }
                    .padding(.horizontal)

                    HeadingText(text: "Causes Evolution For:")
                        .padding(.top)
                    
                    Button(action: {
                        self.showingPokemonFilterPicker.toggle()
                    }) {
                        FilterOptionView(imageName: "plus", filterName: "Add Pokémon Filter", color: .secondary)
                    }
                    .sheet(isPresented: $showingPokemonFilterPicker) {
                        NavigationView {
                            MoveDexFilterPokedexView(pokemonFilters: $pokemonFilters).environmentObject(sessionData)
                        }
                    }
                    .padding(.horizontal)
                    
                    ForEach(pokemonFilters) { pokemon in
                        
                        ZStack {
                            
                            AbilityDexFilterOptionView(imageName: "", filterName: pokemon.name, color: .blue)
                                .padding(.leading)
                            
                            HStack {
                                
                                Button(action: {
                                    pokemonFilters = pokemonFilters.filter({
                                        $0.name != pokemon.name
                                    })
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .padding(.leading)
                                        .imageScale(.large)
                                }
                                
                                Spacer()
                            }
                            .padding(.leading)

                        }
                        .padding(.trailing)
                        
                    }
                    
                }
                .padding(.bottom)

            }
            
            .navigationBarTitle(Text(filterCount != 1 ? "\(filterCount) Results" : "\(filterCount) Result"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                pokemonFilters.removeAll()
                categoryFilters.removeAll()
            }) {
                Text("Clear All")
                    .fontWeight(.regular)
            }.disabled(pokemonFilters.count == 0 && categoryFilters.isEmpty), trailing: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
            })
        }
        
    }
}

//struct ItemDexFilterView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDexFilterView()
//    }
//}
