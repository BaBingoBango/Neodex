//
//  FOComparisonView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/22/20.
//

import SwiftUI

struct FOComparisonView: View {
    
    // Variables
    var stat1: Int
    var color1: Color
    var stat2: Int
    var color2: Color
    var name: String
    var imageName: String
    
    var body: some View {
        
        ZStack {
            
            HStack {
                Image(systemName: imageName)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .opacity(0.6)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.leading)
            
            VStack {
                Text(name)
                    .foregroundColor(.primary)
                HStack {
                    ZStack {
                        Rectangle()
                            .frame(width: (CGFloat((CGFloat(stat1) / CGFloat(stat1 + stat2))) * UIScreen.screenWidth), height: 30)
                            .foregroundColor(color1)
                            .opacity(0.6)
                        Text(String(stat1))
                            .fontWeight(.bold)
                            .foregroundColor(Color.white)
                    }
                    
                    ZStack {
                        Rectangle()
                            .frame(width: (CGFloat((CGFloat(stat2) / CGFloat(stat1 + stat2))) * UIScreen.screenWidth), height: 30)
                            .foregroundColor(color2)
                            .opacity(0.6)
                        Text(String(stat2))
                            .fontWeight(.bold)
                            .foregroundColor(Color.white)
                    }
                }
            }
        }
        
    }
}

struct FOComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        FOComparisonView(stat1: 60, color1: .green, stat2: 80, color2: .orange, name: "Height", imageName: "scalemass.fill")
    }
}

extension UIScreen {
   static let screenWidth = UIScreen.main.bounds.size.width
   static let screenHeight = UIScreen.main.bounds.size.height
   static let screenSize = UIScreen.main.bounds.size
}


struct FOComparisonViewD: View {
    
    // Variables
    var stat1: Double
    var color1: Color
    var stat2: Double
    var color2: Color
    var name: String
    var imageName: String
    
    var body: some View {
        
        ZStack {
            
            HStack {
                Image(systemName: imageName)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .opacity(0.6)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.leading)
            
            VStack {
                Text(name)
                    .foregroundColor(.primary)
                HStack {
                    ZStack {
                        Rectangle()
                            .frame(width: (CGFloat((CGFloat(stat1) / CGFloat(stat1 + stat2))) * UIScreen.screenWidth), height: 30)
                            .foregroundColor(color1)
                            .opacity(0.6)
                        Text(String(stat1))
                            .fontWeight(.bold)
                            .foregroundColor(Color.white)
                    }
                    
                    ZStack {
                        Rectangle()
                            .frame(width: (CGFloat((CGFloat(stat2) / CGFloat(stat1 + stat2))) * UIScreen.screenWidth), height: 30)
                            .foregroundColor(color2)
                            .opacity(0.6)
                        Text(String(stat2))
                            .fontWeight(.bold)
                            .foregroundColor(Color.white)
                    }
                }
            }
        }
        
    }
}
