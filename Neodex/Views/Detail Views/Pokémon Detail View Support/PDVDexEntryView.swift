//
//  PDVDexEntryView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/10/20.
//

import SwiftUI

struct PDVDexEntryView: View {
    
    // Variables
    var pokemon: Pokemon
    @State var showingDexPicker = false
    @Binding var currentDexEntryIndex: Int
    
    var body: some View {
        
        HStack {
            VStack(alignment: .leading) {
                
                Text("\(pokemon.dexEntries[currentDexEntryIndex].source)".uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 0.5)
                
                Text("\(pokemon.dexEntries[currentDexEntryIndex].entry)")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.5)
                
                Button(action: {
                    self.showingDexPicker.toggle()
                }) {
                    HStack(alignment: .center) {
                        
                        Text("Read More")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.blue)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.blue)
                        
                    }
                }
                .sheet(isPresented:$showingDexPicker) {
                    PDVDexPicker(entryList: pokemon.dexEntries, entryIndex: $currentDexEntryIndex)
                }
                .padding(.top, 3)
                
            }
            Spacer()
        }
        
    }
}

//struct PDVDexEntryView_Previews: PreviewProvider {
//    static var previews: some View {
//        PDVDexEntryView(pokemon: Pokemon(name: "Bulbasaur", nationalDexNum: "001", type1: "Grass", type2: "Poison", speciesName: "Seed", height: 0.7, weight: 6.9, ability1: "Overgrow", ability2: "", hiddenAbility: "Chlorophyll", EVYield: "1 Special Attack", catchRate: 45, baseFriendship: 70, baseEXP: 64, growthRate: "Medium Slow", eggGroups: ["Grass", "Monster"], maleRate: 87.5, eggCycles: 20, baseStats: [45, 49, 49, 65, 65, 45], evolutions: [], dexEntries: [DexEntry(source: "Pokémon Sword", entry: "While it is young, it uses the nutrients that are stored in the seed on its back in order to grow.")], locations: []))
//    }
//}
