//
//  AbilityHelpGuide.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/4/21.
//

import SwiftUI

struct AbilityHelpGuide: View {
    
    // Variables
    @Environment(\.presentationMode) var presentationMode
    var text: String
    
    var body: some View {
            
        Form {
            
            Section {
                
                NavigationLink(destination: Text("")) {
                    Text("Topic 1")
                        .padding(.bottom)
                }
                
                Text("Topic 2")
                    .padding(.bottom)
                
                Text("Topic 3")
                    .padding(.bottom)
                
                Text("Topic 4")
                    .padding(.bottom)
                
                Text("Topic 5")
                    .padding(.bottom)
                
            }
            .padding(.top)
            .textCase(nil)
            
        }
        
        .navigationBarTitle(Text("Abilities Help Guide"), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            self.presentationMode.wrappedValue.dismiss()
         }) {
           Text(text)
         })
        
    }
}

struct AbilityHelpGuide_Previews: PreviewProvider {
    static var previews: some View {
        AbilityHelpGuide(text: "")
    }
}
