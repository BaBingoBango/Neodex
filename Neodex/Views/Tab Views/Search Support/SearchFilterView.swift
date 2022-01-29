//
//  SearchFilterView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/12/21.
//

import SwiftUI

struct SearchFilterView: View {
    
    // Variables
    @Environment(\.presentationMode) var presentationMode
    @Binding var searchResults: Int
    
    // Filter variables
    @Binding var showingPokemon: Bool
    @Binding var showingMoves: Bool
    @Binding var showingItems: Bool
    @Binding var showingAbilities: Bool
    @Binding var showingTypes: Bool
    @Binding var showingNatures: Bool
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    
                    HeadingText(text: "Show Results For:")
                    
                    HStack {
                        
                        Button(action: {
                            showingPokemon.toggle()
                        }) {
                            FilterOptionView(imageName: "person.fill", filterName: "Pokémon", color: showingPokemon ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            showingMoves.toggle()
                        }) {
                            FilterOptionView(imageName: "burst.fill", filterName: "Moves", color: showingMoves ? .blue : .secondary)
                        }
                        
                    }
                    .padding([.leading, .bottom, .trailing])
                    
                    HStack {
                        
                        Button(action: {
                            showingItems.toggle()
                        }) {
                            FilterOptionView(imageName: "cube.fill", filterName: "Items", color: showingItems ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            showingAbilities.toggle()
                        }) {
                            FilterOptionView(imageName: "sparkles", filterName: "Abilities", color: showingAbilities ? .blue : .secondary)
                        }
                        
                    }
                    .padding([.leading, .bottom, .trailing])
                    
                    HStack {
                        
                        Button(action: {
                            showingTypes.toggle()
                        }) {
                            FilterOptionView(imageName: "circle.grid.cross.fill", filterName: "Types", color: showingTypes ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            showingNatures.toggle()
                        }) {
                            FilterOptionView(imageName: "leaf.fill", filterName: "Natures", color: showingNatures ? .blue : .secondary)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                }
                .padding(.top)
                
                
            }
            
            .navigationBarTitle(Text(searchResults != 1 ? "\(searchResults) Results" : "\(searchResults) Result"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                showingPokemon = true
                showingMoves = true
                showingItems = true
                showingAbilities = true
                showingTypes = true
                showingNatures = true
            }) {
                Text("Reset")
                    .fontWeight(.regular)
            }.disabled(!(showingPokemon == false || showingMoves == false || showingItems == false || showingAbilities == false || showingTypes == false || showingNatures == false)), trailing: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
            })
        }
        
    }
}

//struct SearchFilterView_Previews: PreviewProvider {
//    static var previews: some View {
//        SearchFilterView()
//    }
//}
