//
//  BrowsingHistoryView.swift
//  Neodex
//
//  Created by Ethan Marshall on 6/9/21.
//

import SwiftUI

struct BrowsingHistoryView: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    var dataType: Int
    
    var body: some View {
        
        Form {
            
            switch dataType {
            case 1:
                ForEach(sessionData.userRecords.pokemonHistory.reversed(), id: \.name) { pokemon in
                    Text(pokemon.name)
                        .fontWeight(.regular)
                }
            case 2:
                ForEach(sessionData.userRecords.abilityHistory.reversed(), id: \.name) { ability in
                    Text(ability.name)
                        .fontWeight(.regular)
                }
            case 3:
                ForEach(sessionData.userRecords.moveHistory.reversed(), id: \.name) { move in
                    Text(move.name)
                        .fontWeight(.regular)
                }
            case 4:
                ForEach(sessionData.userRecords.itemHistory.reversed(), id: \.name) { item in
                    Text(item.name)
                        .fontWeight(.regular)
                }
            default:
                Text("")
            }
            
        }
        
    }
}

struct BrowsingHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        BrowsingHistoryView(dataType: 1).environmentObject(SessionData())
    }
}
