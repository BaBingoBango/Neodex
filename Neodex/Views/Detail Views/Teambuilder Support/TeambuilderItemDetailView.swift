//
//  TeambuilderItemDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/4/21.
//

import SwiftUI

struct TeambuilderItemDetailView: View {
    
    // Variables
    var tIndex: Int
    var pIndex: Int
    var item: Item
    var buttonText: String
    var prez: Binding<PresentationMode>
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
                
                // Set item button for teambuilder
                Button(action: {
                    
                    sessionData.teams[tIndex].members[pIndex]!.item = item.name
                    prez.wrappedValue.dismiss()
                    
                }) {
                    Text("Set Item")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color.white)
                        .padding()
                        .padding(.horizontal, 80.0)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.top)
                
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

//struct TeambuilderItemDetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        TeambuilderItemDetailView(item: Item.itemList[Item.itemList.firstIndex(where: { $0.name == "Chipped Pot" })!], buttonText: "").environmentObject(SessionData())
//    }
//}
