//
//  NatureBerryFilterPicker.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/28/21.
//

import SwiftUI

struct NatureBerryFilterPicker: View {
    
    // Variables
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @Binding var confusingBerryFilters: [String]
    
    var body: some View {
        
        NavigationView {
            ScrollView {
                VStack {
                    ForEach(Item.itemList.filter {
                        $0.name == "Aguav Berry" || $0.name == "Figy Berry" || $0.name == "Iapapa Berry" || $0.name == "Mago Berry" || $0.name == "Wiki Berry"
                    }, id: \.name) { item in
                        
                        Button(action: {
                            confusingBerryFilters.append(item.name)
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            ZStack {
                                
                                Rectangle()
                                    .frame(height: 75)
                                    .foregroundColor(colorScheme == .dark ? .secondary : .white)
                                    .opacity(colorScheme == .dark ? 0.4 : 1.0)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                    .shadow(color: .secondary, radius: colorScheme == .dark ? 0 : 15)
                                
                                HStack {
                                    
                                    Image(item.name)
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                    
                                    VStack(alignment: .leading) {
                                        
                                        Text(item.name)
                                            .foregroundColor(.primary)
                                            .font(.system(size: 23))
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)

                                    }
                                    
                                    Spacer()
                                    
                                }
                                .padding(.leading, 30)
                                
                            }
                        }
                        .padding(.bottom, 5)
                        
                    }
                }
                .padding(.top)
                
                .navigationBarTitle(Text("Add Berry Filter"), displayMode: .inline)
                .navigationBarItems(leading: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel") })
                
            }
        }
        
    }
}

//struct NatureBerryFilterPicker_Previews: PreviewProvider {
//    static var previews: some View {
//        NatureBerryFilterPicker().environmentObject(SessionData())
//    }
//}
