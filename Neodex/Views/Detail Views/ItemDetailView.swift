//
//  ItemDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/3/21.
//

import SwiftUI

struct ItemDetailView: View {
    
    // Variables
    var item: Item
    var buttonText: String
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        ScrollView {
            
            VStack {
                
                ZStack {
                    
                    Circle()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                    
                    if UIImage(named: item.name) != nil {
                        
                        Image(item.name)
                            .resizable()
                            .frame(width: 100, height: 100)
                        
                    } else {
                        
                        Image("Question Mark")
                            .resizable()
                            .frame(width: 100, height: 100)
                        
                    }
                    
                }
                .padding(.top)
                
                Text(item.desc)
                    .padding([.top, .leading, .trailing])
                
                if item.evoEffects.count >= 1 {
                    HeadingText(text: "Causes Evolution For:")
                        .padding(.top)
                }
                
                ForEach(lookupPokemonArray(names: item.evoEffects), id: \.name) { pokemon in
                    
                    AbilityDetailPokemonOption(pokemon: pokemon).environmentObject(sessionData)
                    .padding(.bottom, 5)
                    
                }
                
            }
            
            .navigationBarTitle(Text(item.name), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text(buttonText)
            })
        }
        .onAppear {
            // Add this to the user's history
//            sessionData.userRecords.itemHistory.append(item)
        }
        
    }
    
    // Functions
    func lookupPokemonArray(names: [String]) -> [Pokemon] {
        var answer: [Pokemon] = []
        
        for eachName in names {
            answer.append(pokemonLookup(name: eachName))
        }
        
        return answer
    }
    
    func pokemonLookup(name: String) -> Pokemon {
        for eachPokemon in pokemonDataList {
            if eachPokemon.name == name {
                return eachPokemon
            }
        }
        return pokemonDataList[0]
    }
    
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ItemDetailView(item: Item.itemList[0], buttonText: "Done").environmentObject(SessionData())
    }
}

struct AbilityDetailPokemonOption: View {
    
    // Variables
    @State var showingPokemon = false
    var pokemon: Pokemon
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        Button(action: {
            showingPokemon.toggle()
        }) {
            PokemonListOption(pokemon: pokemon)
        }
        .sheet(isPresented: $showingPokemon) {
            NavigationView {
                PokemonDetailView(pokemon: pokemon, buttonText: "Done").environmentObject(sessionData)
            }
        }
        
    }
    
}
