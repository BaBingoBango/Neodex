//
//  TeamMemberAbilityPicker.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/4/21.
//

import SwiftUI

struct TeamMemberAbilityPicker: View {
    
    // Variables
    var tIndex: Int
    var pIndex: Int
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        NavigationView {
            
            VStack {
                
                Button(action: {
                    
                    sessionData.teams[tIndex].members[pIndex]!.ability = sessionData.teams[tIndex].members[pIndex]!.pokemon.ability1
                    
                }) {
                    AbilityView(abilityName: sessionData.teams[tIndex].members[pIndex]!.pokemon.ability1, abilityNumber: 1, color: sessionData.teams[tIndex].members[pIndex]!.ability == sessionData.teams[tIndex].members[pIndex]!.pokemon.ability1 ? .blue : .secondary)
                }
                
                if sessionData.teams[tIndex].members[pIndex]!.pokemon.ability2 != "" {
                    
                    Button(action: {
                        sessionData.teams[tIndex].members[pIndex]!.ability = sessionData.teams[tIndex].members[pIndex]!.pokemon.ability2
                    }) {
                        AbilityView(abilityName: sessionData.teams[tIndex].members[pIndex]!.pokemon.ability2, abilityNumber: 2, color: sessionData.teams[tIndex].members[pIndex]!.ability == sessionData.teams[tIndex].members[pIndex]!.pokemon.ability2 ? .blue : .secondary)
                    }
                    
                }
                
                if sessionData.teams[tIndex].members[pIndex]!.pokemon.hiddenAbility != "" {
                    
                    Button(action: {
                        sessionData.teams[tIndex].members[pIndex]!.ability = sessionData.teams[tIndex].members[pIndex]!.pokemon.hiddenAbility
                    }) {
                        AbilityView(abilityName: sessionData.teams[tIndex].members[pIndex]!.pokemon.hiddenAbility, abilityNumber: 0, color: sessionData.teams[tIndex].members[pIndex]!.ability == sessionData.teams[tIndex].members[pIndex]!.pokemon.hiddenAbility ? .gold : .secondary)
                    }
                    
                }
                
                ZStack {
                    
                    Rectangle()
                        .frame(height: 150)
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                        .cornerRadius(10)
                    
                    VStack {
                        
//                        Text(sessionData.teams[tIndex].members[pIndex]!.ability)
//                            .font(.title)
//                            .fontWeight(.bold)
//                            .padding(.bottom, 5)
                        
                        Text(Ability.getDetail(ability: sessionData.teams[tIndex].members[pIndex]!.ability))
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .lineLimit(6)
                            .minimumScaleFactor(0.5)
                        
                    }
                    
                }
                .padding(.top)
                
                Spacer()
                
            }
            .padding([.top, .leading, .trailing])
            
            
            // MARK: Nav bar settings
            .navigationBarTitle(Text("Choose Ability"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Done") })
            
        }
        
    }
}

//struct TeamMemberAbilityPicker_Previews: PreviewProvider {
//    static var previews: some View {
//        TeamMemberAbilityPicker(member: TeamMember(pokemon: pokemonDataList[20]))
//    }
//}
