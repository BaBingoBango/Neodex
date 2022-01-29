//
//  HeadingText.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/1/21.
//

import SwiftUI

struct HeadingText: View {
    
    // Variables
    var text: String
    
    var body: some View {
        
        HStack {
            Text(text)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.leading)
        
    }
}

struct HeadingText_Previews: PreviewProvider {
    static var previews: some View {
        HeadingText(text: "Heading")
    }
}
