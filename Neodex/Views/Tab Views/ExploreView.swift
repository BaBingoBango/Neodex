//
//  ExploreView.swift
//  Neodex
//
//  Created by Ethan Marshall on 6/9/21.
//

import SwiftUI
import UIKit

struct ExploreView: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @State var pokemonRecs: [Pokemon] = []
    @State var abilityRecs: [Ability] = []
    @State var itemRecs: [Item] = []
    @State var moveRecs: [Move] = []
    @State var hasReccomended = false

    var body: some View {
        
        let pokemonUsage = sessionData.userRecords.reportPokemonUsage()
        let abilityUsage = sessionData.userRecords.reportAbilityUsage()
        let itemUsage = sessionData.userRecords.reportItemUsage()
        
        ScrollView {
            VStack {
                
                HStack {
                    Text("Pokémon For You")
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .font(.title2)
                        .padding(.leading)
                        .offset(y: 9)
                    Spacer()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        
                        ForEach(pokemonRecs, id: \.name) { pokemon in
                            NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData)) {
                                ReccomendedOption(pokemon: pokemon)
                            }
                        }
                        
                    }
                    .padding(.leading)
                }
                .padding(.top)
                
                HStack {
                    Text("Recently Viewed")
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .font(.title2)
                        .padding(.leading)
                        .offset(y: 9)
                    Spacer()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        
                        ForEach(sessionData.userRecords.pokemonHistory.reversed().prefix(20), id: \.name) { pokemon in
                            NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData)) {
                                TextOnlyReccomendedOption(pokemon: pokemon)
                            }
                        }
                        
                    }
                    .padding(.leading)
                }
                .padding(.top)
                
                HStack {
                    Text("Popular Worldwide")
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .font(.title2)
                        .padding(.leading)
                        .offset(y: 9)
                    Spacer()
                }
                
                // Try to get the worldwide rankings
                let rankings = GlobalStats().getRankingsData()
                
                if rankings == nil {
                    ZStack {
                        Rectangle()
                            .frame(height: 125)
                            .cornerRadius(15)
                            .opacity(0.2)
                        VStack {
                            Image(systemName: "wifi.slash")
                                .resizable()
                                .frame(width: 40, height: 35)
                            Text("Nework Error")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 5)
                        }
                    }
                    .padding([.top, .leading, .trailing])
                } else {
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            
                            ForEach(rankings!.prefix(10), id: \.name) { rankingsStat in
                                NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: rankingsStat.name)).environmentObject(sessionData)) {
                                    ReccomendedOption(pokemon: Pokemon.findPokemon(name: rankingsStat.name))
                                }
                            }
                            
                        }
                        .padding(.leading)
                    }
                    .padding(.top)
                    
                }
                
                HStack {
                    Text("Popular With You")
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .font(.title2)
                        .padding(.leading)
                        .offset(y: 9)
                    Spacer()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(pokemonUsage.prefix(10), id: \.0.name) { usage in
                            NavigationLink(destination: PokemonDetailView(pokemon: usage.0).environmentObject(sessionData)) {
                                PopularWithYouOption(pokemon: usage.0, numViews: usage.1, rank: pokemonUsage.prefix(10).firstIndex(where: { $0.0.name == usage.0.name })! + 1)
                            }
                        }
                        
                    }
                    .padding(.leading)
                }
                .padding(.top)
                
                HStack {
                    Text("Feeling Lucky?")
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .font(.title2)
                        .padding(.leading)
                        .offset(y: 9)
                    Spacer()
                }
                
                VStack {
                    HStack {
                        NavigationLink(destination: PokemonDetailView(pokemon: pokemonDataList.randomElement()!)) {
                            RandomOption(text: "Pokémon!")
                        }
                        let randAbility = Ability.abilityList.randomElement()!
                        NavigationLink(destination: AbilityDetailView(name: randAbility.name, detail: randAbility.detail, buttonText: "")) {
                            RandomOption(text: "Ability!")
                        }
                    }
                    .padding(.top)
                    HStack {
                        NavigationLink(destination: MoveDetailView(move: moveDataList.randomElement()!)) {
                            RandomOption(text: "Move!")
                        }
                        NavigationLink(destination: ItemDetailView(item: Item.itemList.randomElement()!, buttonText: "")) {
                            RandomOption(text: "Item!")
                        }
                    }
                }
                .padding(.horizontal)
                
            }
            
            HStack {
                Text("Items For You")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .font(.title2)
                    .padding(.leading)
                    .offset(y: 9)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    
                    ForEach(itemRecs, id: \.name) { item in
                        NavigationLink(destination: ItemDetailView(item: item, buttonText: "").environmentObject(sessionData)) {
                            ItemReccomendedOption(item: item)
                        }
                    }
                    
                }
                .padding(.leading)
            }
            .padding(.top)
            
            HStack {
                Text("Abilities For You")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .font(.title2)
                    .padding(.leading)
                    .offset(y: 9)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(abilityRecs, id: \.name) { ability in
                        NavigationLink(destination: AbilityDetailView(name: ability.name, detail: ability.detail, buttonText: "").environmentObject(sessionData)) {
                            AbilityReccomendedOption(ability: ability)
                        }
                    }
                    
                }
                .padding(.leading)
            }
            .padding(.vertical)
            
            HStack {
                Text("Moves For You")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .font(.title2)
                    .padding(.leading)
                    .offset(y: 9)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(moveRecs, id: \.name) { move in
                        NavigationLink(destination: MoveDetailView(move: move).environmentObject(sessionData)) {
                            Text("\(move.name)")
                        }
                    }

                }
                .padding(.leading)
            }
            .padding(.top)
            
            // Nav view settings
            .navigationBarTitle(Text("Explore"))
        }
        .onAppear {
            if !hasReccomended {
                pokemonRecs = sessionData.userRecords.reccomend5Pokemon(usage: pokemonUsage)
                abilityRecs = sessionData.userRecords.reccomend5Abilities(usage: abilityUsage)
                itemRecs = sessionData.userRecords.reccomend5Items(usage: itemUsage)
                hasReccomended = true
            }
        }
        
    }
    
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView().environmentObject(SessionData())
    }
}

struct ReccomendedOption: View {
    
    // Variables
    var pokemon: Pokemon
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(width: 200, height: 200)
                .foregroundColor(.clear)
                .background(pokemon.type2 != "" ? LinearGradient(gradient: Gradient(colors: [typeColorDelegator(type: pokemon.type1), typeColorDelegator(type: pokemon.type2)]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [typeColorDelegator(type: pokemon.type1), typeColorDelegator(type: pokemon.type1).opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(15)
                .padding(.trailing, 5)
            
            Image("\(pokemon.name)-art")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
//                .aspectRatio(contentMode: .fit)
                .offset(y: -17)
            
            VStack {
                Spacer()
                
                ZStack {
                    RoundedCorners(color: .black, tl: 0, tr: 0, bl: 15, br: 15)
                        .frame(width: 200, height: 40)
                        .opacity(0.3)
                    Text(pokemon.name)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .offset(x: -2.6)
            
        }
        
    }
    
}

struct TextOnlyReccomendedOption: View {
    
    // Variables
    var pokemon: Pokemon
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(width: 200, height: 40)
                .foregroundColor(.clear)
                .background(pokemon.type2 != "" ? LinearGradient(gradient: Gradient(colors: [typeColorDelegator(type: pokemon.type1), typeColorDelegator(type: pokemon.type2)]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [typeColorDelegator(type: pokemon.type1), typeColorDelegator(type: pokemon.type1).opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(15)
                .padding(.trailing, 5)
            
            Text(pokemon.name)
                .fontWeight(.bold)
                .foregroundColor(.white)
            .offset(x: -2.6)
            
        }
        
    }
    
}

struct PopularWithYouOption: View {
    
    // Variables
    var pokemon: Pokemon
    var numViews: Int
    var rank: Int
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(width: 250, height: 70)
                .foregroundColor(.clear)
                .background(pokemon.type2 != "" ? LinearGradient(gradient: Gradient(colors: [typeColorDelegator(type: pokemon.type1), typeColorDelegator(type: pokemon.type2)]), startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(gradient: Gradient(colors: [typeColorDelegator(type: pokemon.type1), typeColorDelegator(type: pokemon.type1).opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(15)
                .padding(.trailing, 5)
            
            HStack {
                ZStack {
                    RoundedCorners(color: rankColorDelegator(rank: rank), tl: 15, tr: 0, bl: 15, br: 0)
                        .frame(width: 60, height: 70)
                        .offset(x: -2.6)
                    Text("\(rank)")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .font(.system(size: 30))
                }
                
                Spacer()
                
                VStack {
                    Text(pokemon.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.trailing)
                    
                    Text(numViews != 1 ? "\(numViews) views" : "\(numViews) view")
                        .fontWeight(.regular)
                        .foregroundColor(.white)
                        .padding(.trailing)
                }
                
                Spacer()
            }
            .frame(width: 250, height: 60)
            
        }
        
    }
    
}

struct RandomOption: View {
    
    // Variables
    var text: String
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.gray)
                .frame(height: 70)
                .cornerRadius(15)
            Text("Random\n\(text)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
    }
}

struct AbilityReccomendedOption: View {
    
    // Variables
    var ability: Ability
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(width: 250, height: 70)
                .foregroundColor(.clear)
                .background(LinearGradient(gradient: Gradient(colors: [.blue, .flying]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(15)
                .padding(.trailing, 5)
            
            Text(ability.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            .frame(width: 250, height: 60)
            
        }
        
    }
    
}

struct ItemReccomendedOption: View {
    
    // Variables
    var item: Item
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(width: 200, height: 200)
                .foregroundColor(.clear)
                .background(LinearGradient(gradient: Gradient(colors: [Color((UIImage(named: item.name)!.trimmingTransparentPixels()?.averageColor!)!), .white]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(15)
                .padding(.trailing, 5)
            
            Image(UIImage(named: item.name) != nil ? item.name : "Question Mark")
                .resizable()
                .frame(width: 125, height: 125)
                .aspectRatio(contentMode: .fit)
                .offset(y: -17)
            
            VStack {
                Spacer()
                
                ZStack {
                    RoundedCorners(color: .black, tl: 0, tr: 0, bl: 15, br: 15)
                        .frame(width: 200, height: 40)
                        .opacity(0.3)
                    Text(item.name)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .offset(x: -2.6)
            
        }
        .onAppear {
            print(Color(UIImage(named: item.name)!.averageColor!))
        }
        
    }
    
}
