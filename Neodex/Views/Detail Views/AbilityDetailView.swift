//
//  AbilityDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/29/20.
//

import SwiftUI

struct AbilityDetailView: View {
    
    // Variables
    var name: String
    var detail: String
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    var buttonText: String = "Done"
    
    var body: some View {
//        NavigationView {
            ScrollView {
                VStack {
                    
                    Text(detail)
                        .padding(.top, 50)
                        .padding(.horizontal)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Compatible Pokémon")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.leading)
                    .padding(.top, 50)
                    
                    ForEach(filterPokemon(ability: name), id: \.name) { pokemon in
                        NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData)) {
                            PokemonListOption(pokemon: pokemon)
                                .padding(.bottom, 5)
                        }
                    }
                    
                    Spacer()
                    
                }
            }
            .onAppear {
                // Add this to the user's history
//                sessionData.userRecords.abilityHistory.append(Ability(name: name, detail: detail))
            }
            .navigationBarTitle(Text(name), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text(buttonText).foregroundColor(Color.blue) })
//        }
    }
    
    // Functions
    func filterPokemon(ability: String) -> [Pokemon] {
        var answer: [Pokemon] = []
        for eachPokemon in pokemonDataList {
            if eachPokemon.ability1 == ability || eachPokemon.ability2 == ability || eachPokemon.hiddenAbility == ability {
                answer.append(eachPokemon)
            }
        }
        return answer
    }
    
}

struct AbilityDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AbilityDetailView(name: Ability.abilityList[0].name, detail: Ability.abilityList[2].detail).environmentObject(SessionData())
    }
}
