//
//  TeamMemberImportView.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/20/21.
//

import SwiftUI

struct TeamMemberImportView: View {
    
    // Variables
    @State var text = ""
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    var tIndex: Int
    var pIndex: Int
    var eStorage: TeamMember
    var prez: Binding<PresentationMode>? = nil
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    
                    Text("Paste Showdown Text:")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    TextEditor(text: $text)
                        .padding()
                        .frame(height: 300)
                        .border(Color.secondary, width: 4)
                        .cornerRadius(5)
                        .padding([.top, .leading, .trailing])
                    
                        .navigationBarTitle(Text("Import Pokémon"), displayMode: .inline)
                        .navigationBarItems(leading: Button(action: { sessionData.teams[tIndex].members[pIndex] = eStorage; presentationMode.wrappedValue.dismiss() }) { Text("Cancel").fontWeight(.regular) }, trailing: Button(action: {
                            
                            sessionData.teams[tIndex].members[pIndex] = TeamMember.importMember(input: text)
                            if prez == nil {
                                presentationMode.wrappedValue.dismiss()
                            } else {
                                presentationMode.wrappedValue.dismiss()
                                prez!.wrappedValue.dismiss()
                            }

                        }) { Text("Save") })
                    
                    VStack(alignment: .leading) {
                        
                        Text("Warning: If a Pokémon already exists in the selected team slot, its data will be overwritten by the imported Pokémon.")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.trailing)
                            .padding(.top, 5)
                        
                        Text("About Unidentifiable and Erroneous Data")
                            .foregroundColor(.secondary)
                            .font(.callout)
                            .fontWeight(.heavy)
                            .padding(.top, 5)
                        
                        Text("When importing a single Pokémon, if the data for more than one Pokémon is entered, only the first Pokémon listed will be imported.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.trailing)
                            .padding(.top, 1)
                        
                        Text("If unidentifiable or corrupt Pokémon data is detected in the Showdown text, it will be replaced with the attributes of a level 100 Bulbasaur.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.trailing)
                            .padding(.top, 5)
                        
                        Text("If an unknown item is entered, it will reflect in the teambuilder and will be editable.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.trailing)
                            .padding(.top, 5)
                        
                        Text("If an unknown move is entered, the move will be removed and will not appear in the teambuilder. Incompatible moves will not be removed.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.trailing)
                            .padding(.top, 5)
                        
                        Text("EVs over 255 will be reduced to 255, but an EV total over 508 will not be corrected. IVs over 31 will be reduced to 31.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.trailing)
                            .padding(.top, 5)
                        
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                }
                .padding(.bottom)
            }
            
        }
        
    }
}

struct TeamMemberImportView_Previews: PreviewProvider {
    static var previews: some View {
        TeamMemberImportView(tIndex: 0, pIndex: 0, eStorage: TeamMember(pokemon: pokemonDataList[0]))
    }
}
