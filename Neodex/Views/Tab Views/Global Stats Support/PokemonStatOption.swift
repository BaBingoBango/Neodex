//
//  PokemonStatOption.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/27/21.
//

import SwiftUI

struct PokemonStatOption: View {
    
    // Variables
    var stat: RankingsStat
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        let pokemon = Pokemon.findPokemon(name: stat.name)
        
        ZStack {
            
            ZStack {
                Rectangle()
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .frame(height: 75)
                    .shadow(color: .secondary, radius: 15)
                    .padding(.leading, 15)
            }
            
            HStack {
                
                if (pokemon.name != stat.name) && stat.name != "Bulbasaur" {
                    Image("Question Mark")
                        .resizable()
                        .frame(width: 60, height: 60, alignment: .center)
                        .hidden()
                } else {
                    Image(uiImage: UIImage(named: "\(pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60, alignment: .center)
                }
                
                VStack(alignment: .leading) {
                    Text(stat.name)
                        .foregroundColor(.primary)
                        .font(.system(size: stat.name.count >= 9 && UIDevice.modelName.contains("iPod") ? 20 : 23))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("\(stat.usage.rounded(toPlaces: 2).removeZerosFromEnd())% Usage")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                
                Spacer()
                
                Rectangle()
                    .frame(width: 4, height: 75)
                    .hidden()
                
                if !((pokemon.name != stat.name) && stat.name != "Bulbasaur") {
                    
                    VStack {
                        
                        if pokemon.type2 == "" {
                            
                            RectangleIndicatorStack(color1: typeColorDelegator(type: pokemon.type1), text1: pokemon.type1)
                            
                        } else {
                
                            RectangleIndicatorStack(color1: typeColorDelegator(type: pokemon.type1), text1: pokemon.type1, color2: typeColorDelegator(type: pokemon.type2), text2: pokemon.type2)
                            
                        }
                        
                    }
                }
                
            }
            .padding(.leading, 70)
            
            HStack {
                ZStack {
                    Circle()
                        .frame(width: 55, height: 55)
                        .foregroundColor(rankColorDelegator(rank: stat.rank))
                    Text(String(stat.rank))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .font(.system(size: 25))
                }
                Spacer()
            }
            .padding(.leading, 10)
            
        }
        
    }
    
}

struct PokemonStatOption_Previews: PreviewProvider {
    static var previews: some View {
        PokemonStatOption(stat: RankingsStat(rank: 2, name: "Charizard", usage: 67.5293472))
    }
}
