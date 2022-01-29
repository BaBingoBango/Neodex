//
//  AbilityListOption.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/29/20.
//

import SwiftUI

struct AbilityListOption: View {
    
    // Variables
    var ability: Ability
    @Environment(\.colorScheme) var colorScheme
    @State var showingDetail = false
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        Button(action: {
            self.showingDetail.toggle()
        }) {
            ZStack {
                
                Rectangle()
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .frame(height: 50, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
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
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                AbilityDetailView(name: ability.name, detail: ability.detail).environmentObject(sessionData)
            }
        }
        
    }
}

//struct AbilityListOption_Previews: PreviewProvider {
//    static var previews: some View {
//        AbilityListOption(ability: Ability.abilityList[0])
//    }
//}
