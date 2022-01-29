//
//  GlobalStatsTeammatesDetail.swift
//  Neodex
//
//  Created by Ethan Marshall on 3/7/21.
//

import SwiftUI

struct GlobalStatsTeammatesDetail: View {
    
    // Variables
    var sortedTeammates: [String]
    var detail: RankingDetail
    
    var body: some View {
        
        VStack {
            
            HeadingText(text: "Top Teammates")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    
                    ForEach(sortedTeammates, id: \.self) { teammate in
                        
                        PokemonColorCircle(pokemon: Pokemon.findPokemon(name: teammate), usage: detail.teammates[teammate]!)
                            .padding(.trailing, 10)
                        
                    }
                    
                }
                .padding(.horizontal)
            }
            
        }
        
    }
}

//struct GlobalStatsTeammatesDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        GlobalStatsTeammatesDetail()
//    }
//}

struct PokemonColorCircle: View {
    
    // Variables
    var pokemon: Pokemon
    var usage: Double
    @State var showingDetail = false
    
    var body: some View {
        
        VStack {
            
            Button(action: {
                showingDetail.toggle()
            }) {
                ZStack {
                    
                    Circle()
                        .foregroundColor(typeColorDelegator(type: pokemon.type1))
                        .frame(width: 130, height: 130)
                    
                    Image("\(pokemon.name)-art")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90, height: 90)
                    
                }
            }
            .sheet(isPresented: $showingDetail) {
                NavigationView {
                    PokemonDetailView(pokemon: pokemon, buttonText: "Done")
                }
            }
            
            Text("\(String(usage.rounded(toPlaces: 2)))%")
                .fontWeight(.bold)
                .foregroundColor(typeColorDelegator(type: pokemon.type1))
                .font(.system(size: 22))
            
        }
        
    }
    
}
