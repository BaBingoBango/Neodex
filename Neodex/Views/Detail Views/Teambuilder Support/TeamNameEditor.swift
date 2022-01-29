//
//  TeamNameEditor].swift
//  Neodex
//
//  Created by Ethan Marshall on 2/12/21.
//

import SwiftUI
import Combine

struct TeamNameEditor: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    var tIndex: Int
    var pIndex: Int = 0
    @State var teamName: String
    @State var placeholder = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        NavigationView {
            
            VStack {
                
                ZStack {
                    
                    Rectangle()
                        .foregroundColor(.secondary)
                        .opacity(0.4)
                        .frame(height: 60)
                        .cornerRadius(10)
                    
                    TextField(placeholder, text: $teamName) {
                        
                        isEditing in
                        
                        placeholder = sessionData.teams[tIndex].name
                        
                        if sessionData.teams[tIndex].name == teamName && isEditing {
                            teamName = ""
                        } else if !isEditing {
                            if teamName == "" {
                                
                                teamName = sessionData.teams[tIndex].name
                                
                            }
                            
//                            sessionData.teams[tIndex].name = teamName
                        }
                        
                    } onCommit: {
                        
                        if teamName == "" {
                            
                            teamName = sessionData.teams[tIndex].name
                            
                        }
                        
//                        sessionData.teams[tIndex].name = teamName
                        
                    }
                    .onReceive(Just(teamName)) { _ in limitText(10) }
                    .font(.system(size: UIDevice.modelName.contains("iPod") ? 17 : 22, weight: .bold))
                    .frame(height: 200)
                    .multilineTextAlignment(.center)
                    
                }
                .padding(.horizontal)
                
                Spacer()
                
                // MARK: Nav view settings
                .navigationBarTitle(Text("Edit Team Name"), displayMode: .inline)
                    .navigationBarItems(leading: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel").fontWeight(.regular) }, trailing: Button(action: { sessionData.teams[tIndex].name = teamName; self.presentationMode.wrappedValue.dismiss() }) { Text("Save") })
            }
            
        }
            
        
    }
    
    // Functions
    func limitText(_ upper: Int) {
        if teamName.count > upper && !(teamName == sessionData.teams[tIndex].members[pIndex]!.name) {
                teamName = String(teamName.prefix(upper))
            }
        }
}

struct TeamNameEditor_Previews: PreviewProvider {
    static var previews: some View {
        TeamNameEditor(tIndex: 0, pIndex: 0, teamName: "New Team").environmentObject(SessionData())
    }
}
