//
//  PokemonListOption.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/5/20.
//

// This is the view in which Pokemon will appear in the Pokedex lists - users will tap on this view to be taken to the Pokemon detail page.

import SwiftUI

struct PokemonListOption: View {
    
    // Variables
    var pokemon: Pokemon
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .cornerRadius(10)
                .padding(.horizontal)
                .frame(height: 75, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                .shadow(color: .secondary, radius: 15)
            
            HStack {
                
                Image(uiImage: UIImage(named: "\(pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60, alignment: .center)
                
                VStack(alignment: .leading) {
                    Text(pokemon.name)
                        .foregroundColor(.primary)
                        .font(.system(size: pokemon.name.count >= 9 && UIDevice.modelName.contains("iPod") ? 20 : 23))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("#\(pokemon.nationalDexNum)")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Rectangle()
                    .frame(width: 4, height: 75)
                    .hidden()
                
                VStack {
                    
                    if pokemon.type2 == "" {
                        
                        RectangleIndicatorStack(color1: typeColorDelegator(type: pokemon.type1), text1: pokemon.type1)
                        
                    } else {
            
                        RectangleIndicatorStack(color1: typeColorDelegator(type: pokemon.type1), text1: pokemon.type1, color2: typeColorDelegator(type: pokemon.type2), text2: pokemon.type2)
                        
                    }
                    
                }
                
            }
            .padding(.leading, 30)
            
        }
        
    }
}

struct PokemonListOption_Previews: PreviewProvider {
    static var previews: some View {
        PokemonListOption(pokemon: pokemonDataList[3])
            .preferredColorScheme(.light)
    }
}
