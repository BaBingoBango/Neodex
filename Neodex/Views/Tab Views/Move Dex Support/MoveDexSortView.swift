//
//  MoveDexSortView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/8/21.
//

import SwiftUI

struct MoveDexSortView: View {
    
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
                        
                        HStack {
                            
                            PokedexSortButton(sortCondition: $sortCondition, sortName: "Alphabetical", imageName: "a.circle.fill")
                            
                            PokedexSortButton(sortCondition: $sortCondition, sortName: "Power", imageName: "bolt.fill")
                            
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            
                            PokedexSortButton(sortCondition: $sortCondition, sortName: "Accuracy", imageName: "scope")
                            
                            PokedexSortButton(sortCondition: $sortCondition, sortName: "PP", imageName: "flame.fill")
                            
                        }
                        .padding([.top, .leading, .trailing])
                        
                        HStack {
                            
                            PokedexSortButton(sortCondition: $sortCondition, sortName: "Priority", imageName: "goforward.plus")
                            
                            PokedexSortButton(sortCondition: $sortCondition, sortName: "Compatible Pokémon", imageName: "person.fill")
                            
                        }
                        .padding([.top, .leading, .trailing])
                        
                    }
                }
                
            }
            
            
            .navigationBarTitle(Text("Sort Moves"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: { sortCondition = "Alphabetical"; sortDirection = 0 }) { Text("Reset").fontWeight(.regular) }.disabled(sortDirection == 0 && sortCondition == "Alphabetical"), trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Done") })
        }
        
    }
}

//struct MoveDexSortView_Previews: PreviewProvider {
//    static var previews: some View {
//        MoveDexSortView()
//    }
//}
