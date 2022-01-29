//
//  AbilityDexFilterView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/8/21.
//

import SwiftUI

struct AbilityDexFilterView: View {
    
    // Variables
    @State var showingPokemonFilterPicker = false
    @Environment(\.presentationMode) var presentationMode
    @Binding var filterCount: Int
    @EnvironmentObject var sessionData: SessionData
    
    // Filter variables
    @Binding var pokemonFilters: [Pokemon]
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {

                    HeadingText(text: "Compatability")
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

            }
            
            .navigationBarTitle(Text(filterCount != 1 ? "\(filterCount) Results" : "\(filterCount) Result"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                pokemonFilters.removeAll()
            }) {
                Text("Clear All")
                    .fontWeight(.regular)
            }.disabled(pokemonFilters.count == 0), trailing: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
            })
        }
        
    }
}

//struct AbilityDexFilterView_Previews: PreviewProvider {
//    static var previews: some View {
//        AbilityDexFilterView()
//    }
//}

struct AbilityDexFilterOptionView: View {
    
    // Variables
    var imageName: String
    var filterName: String
    var color: Color
    
    var body: some View {
        ZStack {
            Rectangle()
                .frame(height: 50)
                .foregroundColor(color)
                .cornerRadius(30)
            HStack {
                Image(systemName: imageName)
                    .padding(.leading)
                    .imageScale(.large)
                    .foregroundColor(.white)
                Text(filterName)
                    .font(.system(size: 15))
                    .fontWeight(.bold)
                    .foregroundColor(Color.white)
                    .padding(.leading, 25)
                Spacer()
            }
            .padding(.trailing)
        }
    }
}
