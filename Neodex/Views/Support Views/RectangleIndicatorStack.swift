//
//  RectangleIndicatorStack.swift
//  Neodex
//
//  Created by Ethan Marshall on 10/3/21.
//

import SwiftUI

/// The visual representation of either one or two pieces of text and color. In either case, the result is a rectangle, rounded on the right-hand corners, whch fits perfectly into the various option views.
struct RectangleIndicatorStack: View {
    
    // View parameters
    var color1: Color
    var text1: String
    var color2: Color?
    var text2: String?
    var roundedLeftSide = false
    var height: CGFloat = 75.0
    
    var body: some View {
        
        if color2 == nil && text2 == nil {
            
            // The view if there is one piece of data.
            
            ZStack {
                
                Rectangle()
                    .foregroundColor(color1)
                    .cornerRadius(10, corners: !roundedLeftSide ? [.topRight, .bottomRight] : [.topLeft, .bottomLeft])
                
                Text(text1.uppercased())
                    .foregroundColor(.white)
                    .font(Font.custom("Andale Mono", size: 20.0))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
                
            }
            .frame(width: 77, height: height)
            .offset(x: !roundedLeftSide ? -16 : 0)
            
        } else {
            
            // The view if there are two pieces of data.
            
            VStack(spacing: 0) {
                
                ZStack {
                    
                    Rectangle()
                        .foregroundColor(color1)
                        .cornerRadius(10, corners: !roundedLeftSide ? [.topRight] : [.topLeft])
                    
                    Text(text1.uppercased())
                        .foregroundColor(.white)
                        .font(Font.custom("Andale Mono", size: 20.0))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 2)
                    
                }
                .frame(width: 77, height: height / 2)
                
                ZStack {
                    
                    Rectangle()
                        .foregroundColor(color2!)
                        .cornerRadius(10, corners: !roundedLeftSide ? [.bottomRight] : [.bottomLeft])
                    
                    Text(text2!.uppercased())
                        .foregroundColor(.white)
                        .font(Font.custom("Andale Mono", size: 20.0))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 2)
                    
                }
                .frame(width: 77, height: height / 2)
                
            }
            .offset(x: !roundedLeftSide ? -16 : 0)
            
        }
        
    }
}

struct RectangleIndicatorStack_Previews: PreviewProvider {
    static var previews: some View {
        RectangleIndicatorStack(color1: .red, text1: "FIGHTING", color2: .blue, text2: "PHYSICAL")
    }
}
