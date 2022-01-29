//
//  PokemonHelpGuide.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/3/21.
//

import SwiftUI

struct PokemonHelpGuide: View {
    
    // Variables
    @Environment(\.presentationMode) var presentationMode
    var text: String
    
    var body: some View {
            
        Form {
            
            Section {
                
                NavigationLink(destination: ThePokedexHelpGuide()) {
                    Text("The Pokédex")
                        .padding(.bottom)
                }
                
                Text("Topic 2")
                    .padding(.bottom)
                
                Text("Topic 3")
                    .padding(.bottom)
                
                Text("Topic 4")
                    .padding(.bottom)
                
                Text("Topic 5")
                    .padding(.bottom)
                
            }
            .padding(.top)
            .textCase(nil)
            
        }
        
        .navigationBarTitle(Text("Pokémon Help Guide"), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            self.presentationMode.wrappedValue.dismiss()
         }) {
           Text(text)
         })
        
    }
}

struct PokemonHelpGuide_Previews: PreviewProvider {
    static var previews: some View {
        PokemonHelpGuide(text: "")
    }
}
