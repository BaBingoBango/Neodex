//
//  TeamImportView.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/16/21.
//

import SwiftUI

struct TeamImportView: View {
    
    // Variables
    @State var text = ""
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    
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
                    
                        .navigationBarTitle(Text("Import Team"), displayMode: .inline)
                        .navigationBarItems(leading: Button(action: { presentationMode.wrappedValue.dismiss() }) { Text("Cancel").fontWeight(.regular) }, trailing: Button(action: { sessionData.teams.insert(Team.importTeam(input: text), at: 0); presentationMode.wrappedValue.dismiss() }) { Text("Save") })
                    
                    VStack(alignment: .leading) {
                        
                        Text("About Unidentifiable and Erroneous Data")
                            .foregroundColor(.secondary)
                            .font(.callout)
                            .fontWeight(.heavy)
                            .padding(.top, 5)
                        
                        Text("If unidentifiable or corrupt Pokémon data is detected in the Showdown text, it will be replaced with the attributes of a level 100 Bulbasaur.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.trailing)
                            .padding(.top, 1)
                        
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
            }
            
        }
        
    }
}

struct TeamImportView_Previews: PreviewProvider {
    static var previews: some View {
        TeamImportView().environmentObject(SessionData())
    }
}
