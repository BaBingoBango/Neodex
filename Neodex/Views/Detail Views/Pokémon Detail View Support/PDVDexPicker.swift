//
//  PDVDexPicker.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/10/20.
//

import SwiftUI

struct PDVDexPicker: View {
    
    // Variables
    var entryList: [DexEntry]
    @Binding var entryIndex: Int
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        NavigationView {
            ScrollView {
                VStack {
                    
                    ForEach(self.entryList, id: \.source) { entry in
                        Button(action: {
                            entryIndex = entryList.firstIndex(where: { (item) -> Bool in
                                item.entry == entry.entry
                            })!
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            DexOption(source: entry.source, entry: entry.entry)
                        }
                    }
                    
                    Spacer()
                    
                }
                .padding(.top)
                .padding(.horizontal)
                .navigationTitle(Text("Pokédex Entries"))
                .navigationBarItems(trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Done").foregroundColor(Color.blue) })
            }
        }
        
    }
}

struct DexOption: View {
    
    // Variables
    var source: String
    var entry: String
    
    var body: some View {
        ZStack {
            
            Rectangle()
                .frame(height: 150)
                .foregroundColor(.secondary)
                .opacity(0.3)
                .cornerRadius(25)
            
            VStack(alignment: .leading) {
                
                Text("\(source)".uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding([.top, .leading, .trailing])
                
                Spacer()
                
                HStack {
                    
                    Text(entry)
                        .padding([.leading, .bottom, .trailing])
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .minimumScaleFactor(0.5)
                    
                    Spacer()
                    
                }
                
                Spacer()
                
            }
            
        }
    }
}

struct PDVDexPicker_Previews: PreviewProvider {
    static var previews: some View {
        PDVDexPicker(entryList: [DexEntry(source: "Pokemon Sword", entry: "There is a plant seed on its back right from the day this Pokémon is born. The seed slowly grows larger. Ok but sometimes this just gets "), DexEntry(source: "Pokemon Sword", entry: "Smaller test entry."), DexEntry(source: "Pokemon Sword", entry: "There is a plant seed on its back right from the day this Pokémon is born. The seed slowly grows larger."), DexEntry(source: "Pokemon Sword", entry: "There is a plant seed on its back right from the day this Pokémon is born. The seed slowly grows larger."), DexEntry(source: "Pokemon Sword", entry: "There is a plant seed on its back right from the day this Pokémon is born. The seed slowly grows larger."), DexEntry(source: "Pokemon Sword", entry: "There is a plant seed on its back right from the day this Pokémon is born. The seed slowly grows larger."), DexEntry(source: "Pokemon Sword", entry: "There is a plant seed on its back right from the day this Pokémon is born. The seed slowly grows larger."), DexEntry(source: "Pokemon Sword", entry: "There is a plant seed on its back right from the day this Pokémon is born. The seed slowly grows larger.")], entryIndex: .constant(0))
    }
}
