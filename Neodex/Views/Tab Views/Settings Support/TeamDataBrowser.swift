//
//  TeamDataBrowser.swift
//  Neodex
//
//  Created by Ethan Marshall on 6/9/21.
//

import SwiftUI

struct TeamDataBrowser: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        Form {
            ForEach(sessionData.teams, id: \.name) { team in
                VStack(alignment: .leading) {
                    Text(team.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    ForEach(team.members, id: \.?.name) { member in
                        if member != nil {
                            Text(member!.nickname)
                                .fontWeight(.regular)
                        }
                    }
                }
            }
        }
        
    }
}

struct TeamDataBrowser_Previews: PreviewProvider {
    static var previews: some View {
        TeamDataBrowser().environmentObject(SessionData())
    }
}
