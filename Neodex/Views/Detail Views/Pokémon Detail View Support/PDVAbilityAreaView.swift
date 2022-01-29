//
//  PDVAbilityAreaView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/11/20.
//

import SwiftUI

struct PDVAbilityAreaView: View {
    
    // Variables
    var pokemon: Pokemon
    @State var showingAbilityDetail1 = false
    @State var showingAbilityDetail2 = false
    @State var showingAbilityDetail3 = false
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        VStack {
            
            Button(action: {
                self.showingAbilityDetail1.toggle()
            }) {
                AbilityView(abilityName: pokemon.ability1, abilityNumber: 1)
            }
            .sheet(isPresented: $showingAbilityDetail1) {
                NavigationView {
                    AbilityDetailView(name: pokemon.ability1, detail: Ability.getDetail(ability: pokemon.ability1)).environmentObject(sessionData)
                }
            }
            
            if pokemon.ability2 != "" {
                Button(action: {
                    self.showingAbilityDetail2.toggle()
                }) {
                    AbilityView(abilityName: pokemon.ability2, abilityNumber: 2)
                }
                .sheet(isPresented: $showingAbilityDetail2) {
                    NavigationView {
                        AbilityDetailView(name: pokemon.ability2, detail: Ability.getDetail(ability: pokemon.ability2)).environmentObject(sessionData)
                    }
                }
            }
            
            if pokemon.hiddenAbility != "" {
                Button(action: {
                    self.showingAbilityDetail3.toggle()
                }) {
                    AbilityView(abilityName: pokemon.hiddenAbility, abilityNumber: 0)
                }
                .sheet(isPresented: $showingAbilityDetail3) {
                    NavigationView {
                        AbilityDetailView(name: pokemon.hiddenAbility, detail: Ability.getDetail(ability: pokemon.hiddenAbility)).environmentObject(sessionData)
                    }
                }
            }
            
        }
        
    }
}

//struct PDVAbilityAreaView_Previews: PreviewProvider {
//    static var previews: some View {
//        PDVAbilityAreaView(pokemon: Pokemon(name: "Bulbasaur", nationalDexNum: "001", type1: "Grass", type2: "Poison", speciesName: "Seed", height: 0.7, weight: 6.9, ability1: "Overgrow", ability2: "2", hiddenAbility: "Chlorophyll", EVYield: "1 Special Attack", catchRate: 45, baseFriendship: 70, baseEXP: 64, growthRate: "Medium Slow", eggGroups: ["Grass", "Monster"], maleRate: 87.5, eggCycles: 20, baseStats: [45, 49, 49, 65, 65, 45], evolutions: [], dexEntries: [DexEntry(source: "Pokemon Shield", entry: "While it is young, it uses the nutrients that are stored in the seed on its back in order to grow.")], locations: []))
//    }
//}

struct AbilityView: View {
    
    // Variables
    var abilityName: String
    var abilityNumber: Int
    var color: Color = .secondary
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(height: 60)
                .foregroundColor(color)
                .cornerRadius(100)
                .opacity(0.4)
            
            VStack {
                
                Text(abilityNumber == 0 ? "HIDDEN ABILITY" : "ABILITY \(abilityNumber)")
                    .font(.system(size: 15))
                    .fontWeight(.heavy)
                    .foregroundColor(abilityNumber == 0 ? .gold : .blue)
                
                Text(abilityName)
                    .foregroundColor(.primary)
                    .font(.system(size: 20))
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
            }
            
        }
    }
    
}
