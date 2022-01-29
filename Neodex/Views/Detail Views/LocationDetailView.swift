//
//  LocationDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/31/21.
//

import SwiftUI

struct LocationDetailView: View {
    
    // Variables
    var location: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    
                    Image(systemName: "mappin.and.ellipse")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(.top)
                        .frame(width: 100)
                        .foregroundColor(.green)
                    
                    if location.contains("SWORD:") {
                        
                        let generalLocation = location.replacingOccurrences(of: "SWORD: ", with: "")
                        
                        HeadingText(text: "Pokémon Found Here")
                            .padding(.top, 30)
                        
                        ForEach(pokemonDataList.filter({ $0.locations.contains(generalLocation) }), id: \.name) { pokemon in
                            
                            NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                
                                PokemonListOption(pokemon: pokemon)
                                    .padding(.bottom, 5)
                                
                            }
                            
                        }
                        
                        HeadingText(text: "Found In Pokémon Sword")
                            .padding(.top, 30)
                        
                        ForEach(pokemonDataList.filter({ $0.locations.contains(location) }), id: \.name) { pokemon in
                            NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                PokemonListOption(pokemon: pokemon)
                                    .padding(.bottom, 5)
                            }
                        }
                        
                        let shieldLocation = location.replacingOccurrences(of: "SWORD: ", with: "SHIELD: ")
                        
                        if !(pokemonDataList.filter({ $0.locations.contains(shieldLocation) })).isEmpty {
                            
                            HeadingText(text: "Found In Pokémon Shield")
                                .padding(.top, 30)
                            
                            ForEach(pokemonDataList.filter({ $0.locations.contains(shieldLocation) }), id: \.name) { pokemon in
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                    PokemonListOption(pokemon: pokemon)
                                        .padding(.bottom, 5)
                                }
                            }
                            
                        }
                        
                    } else if location.contains("SHIELD:") {
                        
                        let generalLocation = location.replacingOccurrences(of: "SHIELD: ", with: "")
                        
                        HeadingText(text: "Pokémon Found Here")
                            .padding(.top, 30)
                        
                        ForEach(pokemonDataList.filter({ $0.locations.contains(generalLocation) }), id: \.name) { pokemon in
                            
                            NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                
                                PokemonListOption(pokemon: pokemon)
                                    .padding(.bottom, 5)
                                
                            }
                            
                        }
                        
                        HeadingText(text: "Found In Pokémon Shield")
                            .padding(.top, 30)
                        
                        ForEach(pokemonDataList.filter({ $0.locations.contains(location) }), id: \.name) { pokemon in
                            NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                PokemonListOption(pokemon: pokemon)
                                    .padding(.bottom, 5)
                            }
                        }
                        
                        let swordLocation = location.replacingOccurrences(of: "SHIELD: ", with: "SWORD: ")
                        
                        if !(pokemonDataList.filter({ $0.locations.contains(swordLocation) })).isEmpty {
                            
                            HeadingText(text: "Found In Pokémon Sword")
                                .padding(.top, 30)
                            
                            ForEach(pokemonDataList.filter({ $0.locations.contains(swordLocation) }), id: \.name) { pokemon in
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                    PokemonListOption(pokemon: pokemon)
                                        .padding(.bottom, 5)
                                }
                            }
                            
                        }
                        
                    } else {
                        
                        HeadingText(text: "Pokémon Found Here")
                            .padding(.top, 30)
                        
                        ForEach(pokemonDataList.filter({ $0.locations.contains(location) }), id: \.name) { pokemon in
                            
                            NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                
                                PokemonListOption(pokemon: pokemon)
                                    .padding(.bottom, 5)
                                
                            }
                            
                        }
                        
                        let swordLocation = "SWORD: " + location
                        let shieldLocation = "SHIELD: " + location
                        
                        if !(pokemonDataList.filter({ $0.locations.contains(swordLocation) })).isEmpty {
                            
                            HeadingText(text: "Found In Pokémon Sword")
                                .padding(.top, 30)
                            
                            ForEach(pokemonDataList.filter({ $0.locations.contains(swordLocation) }), id: \.name) { pokemon in
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                    PokemonListOption(pokemon: pokemon)
                                        .padding(.bottom, 5)
                                }
                            }
                            
                        }
                        
                        if !(pokemonDataList.filter({ $0.locations.contains(shieldLocation) })).isEmpty {
                            
                            HeadingText(text: "Found In Pokémon Shield")
                                .padding(.top, 30)
                            
                            ForEach(pokemonDataList.filter({ $0.locations.contains(shieldLocation) }), id: \.name) { pokemon in
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                    PokemonListOption(pokemon: pokemon)
                                        .padding(.bottom, 5)
                                }
                            }
                            
                        }
                        
                    }
                    
                }
                .padding(.vertical)
            }
            
            .navigationBarTitle(Text(location.replacingOccurrences(of: "SWORD: ", with: "").replacingOccurrences(of: "SHIELD: ", with: "")), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Done") })
            
        }
        
    }
}

struct LocationDetailView_Previews: PreviewProvider {
    static var previews: some View {
        LocationDetailView(location: "Route 4")
    }
}
