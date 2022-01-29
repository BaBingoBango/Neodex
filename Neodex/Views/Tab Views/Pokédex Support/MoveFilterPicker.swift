//
//  MoveFilterPicker.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/2/21.
//

import SwiftUI

struct MoveFilterPicker: View {
    
    // Variables
    @State private var searchText : String = ""
    @Environment(\.presentationMode) var presentationMode
    @Binding var moveFilters: [String]
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                
                LazyVStack {
                    
                    SearchBar(text: $searchText)
                        .padding(.top)
                    
                    ForEach(moveDataList.filter {
                        self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                    }, id: \.name) { move in
                        Button(action: {
                            moveFilters.append(move.name)
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            MoveOption(move: move)
                        }
                    }
                    
                }
            }
            
            .navigationBarItems(leading: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel") })
            .navigationBarTitle("Add Move Filter", displayMode: .inline)
        }
        
    }
}

//struct MoveFilterPicker_Previews: PreviewProvider {
//    static var previews: some View {
//        MoveFilterPicker()
//    }
//}
