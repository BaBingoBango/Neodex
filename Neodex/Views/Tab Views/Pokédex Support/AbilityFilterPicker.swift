//
//  AbilityFilterPicker.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/30/20.
//

import SwiftUI

struct AbilityFilterPicker: View {
    
    // Variables
    @State private var searchText : String = ""
    let abilityList: [Ability] = Ability.abilityList
    @Binding var abilityFilters: [String]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                
                VStack {
                    
                    SearchBar(text: $searchText)
                        .padding(.vertical)
                    
                    ForEach(self.abilityList.filter {
                        self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                    }, id: \.name) { ability in
                        Button(action: {
                            abilityFilters.append(ability.name)
                        }) {
                            AbilityFilterListOption(ability: ability)
                                .padding(.bottom, 5)
                        }
                    }
                    
                }
            }
            
            .navigationBarTitle("Add Ability Filter", displayMode: .inline)
            .navigationBarItems(leading: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel") })
        }
        
    }
}

struct AbilityFilterListOption: View {
    
    // Variables
    var ability: Ability
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .cornerRadius(10)
                .padding(.horizontal)
                .frame(height: 50)
                .shadow(color: .secondary, radius: 15)
            
            HStack {
                
                VStack(alignment: .leading) {
                    Text(ability.name)
                        .foregroundColor(.primary)
                        .font(.system(size: 23))
                        .fontWeight(.bold)
                }
                
                Spacer()
                
            }
            .padding(.leading, 30)
            
        }
        
    }
}
