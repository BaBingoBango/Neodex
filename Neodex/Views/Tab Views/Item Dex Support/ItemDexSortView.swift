//
//  ItemDexSortView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/8/21.
//

import SwiftUI

struct ItemDexSortView: View {
    
    // Variables
    @Environment(\.presentationMode) var presentationMode
    var directions = ["Ascending", "Descending"]
    
    // Sort variables
    @Binding var sortCondition: String
    @Binding var sortDirection: Int
    
    var body: some View {
        
        NavigationView {
            
            VStack {
                
                Picker(selection: $sortDirection, label: Text("")) {
                    ForEach(0 ..< directions.count) {
                       Text(self.directions[$0])
                    }
                }
                .padding(.all)
                .pickerStyle(SegmentedPickerStyle())
                
                ScrollView {
                    VStack {
                        
                        PokedexSortButton(sortCondition: $sortCondition, sortName: "Alphabetical", imageName: "a.circle.fill")
                        
                        PokedexSortButton(sortCondition: $sortCondition, sortName: "No. of Evolving Pokémon", imageName: "person.fill")
                        
                    }
                    .padding(.horizontal)
                }
                
            }
            
            
            .navigationBarTitle(Text("Sort Items"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: { sortCondition = "Alphabetical"; sortDirection = 0 }) { Text("Reset").fontWeight(.regular) }.disabled(sortDirection == 0 && sortCondition == "Alphabetical"), trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Done") })
        }
        
    }

}

//struct ItemDexSortView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDexSortView()
//    }
//}
