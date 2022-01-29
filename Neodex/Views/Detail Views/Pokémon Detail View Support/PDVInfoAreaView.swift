//
//  PDVInfoAreaView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/12/20.
//

import SwiftUI

struct PDVInfoAreaView: View {
    
    // Variables
    var pokemon: Pokemon
    @State var showingfeetAndInches = false
    @State var showingPounds = false
    
    var body: some View {
        
        VStack {
            
            HStack {
                if !showingfeetAndInches {
                    Button(action: {
                        self.showingfeetAndInches.toggle()
                    }) {
                        ZStack {
                            InfoView(name: "Height", value: String("\(pokemon.height) m"), iconName: "ruler", color: .blue)
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.left.arrow.right")
                                    .padding(.trailing)
                                    .imageScale(.large)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } else {
                    Button(action: {
                        self.showingfeetAndInches.toggle()
                    }) {
                        ZStack {
                            InfoView(name: "Height", value: String("\(metersToFeetAndInches(meters: pokemon.height))"), iconName: "ruler", color: .blue)
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.left.arrow.right")
                                    .padding(.trailing)
                                    .imageScale(.large)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                if pokemon.weight == -1 {
                    InfoView(name: "Weight", value: "--", iconName: "scalemass", color: .blue)
                } else {
                    if !showingPounds {
                        Button(action: {
                            self.showingPounds.toggle()
                        }) {
                            ZStack {
                                InfoView(name: "Weight", value: String("\(pokemon.weight) kg"), iconName: "scalemass", color: .blue)
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.left.arrow.right")
                                        .padding(.trailing)
                                        .imageScale(.large)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    } else {
                        Button(action: {
                            self.showingPounds.toggle()
                        }) {
                            ZStack {
                                InfoView(name: "Weight", value: String("\(kgtolbs(kg: pokemon.weight)) lbs"), iconName: "scalemass", color: .blue)
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.left.arrow.right")
                                        .padding(.trailing)
                                        .imageScale(.large)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            
            HStack {
                InfoView(name: "EV Yield", value: String("\(pokemon.EVYield)"), iconName: "star", color: .green)
                
                InfoView(name: "Catch Rate", value: String("\(pokemon.catchRate)"), iconName: "checkmark.seal", color: .green)
            }
            
            HStack {
                InfoView(name: "Friendship", value: String("\(pokemon.baseFriendship)"), iconName: "suit.heart", color: .pink)
                
                InfoView(name: "Base EXP.", value: String("\(pokemon.baseEXP)"), iconName: "sparkles", color: .pink)
            }
            
            HStack {
                if pokemon.eggGroups.count == 1 || pokemon.eggGroups[1] == "" {
                    InfoView(name: "Egg Groups", value: String("\(pokemon.eggGroups[0])"), iconName: "person", color: .yellow)
                } else {
                    InfoView(name: "Egg Groups", value: String("\(pokemon.eggGroups[0]) & \(pokemon.eggGroups[1])"), iconName: "person", color: .yellow)
                }
                
                InfoView(name: "Egg Cycles", value: String("\(pokemon.eggCycles)"), iconName: "arrow.clockwise", color: .yellow)
            }
            
            HStack {
                InfoView(name: "M/F Ratio", value: String("\(pokemon.maleRate) : \(100 - pokemon.maleRate)"), iconName: "stethoscope", color: .yellow)
                
                InfoView(name: "Growth Rate", value: String("\(pokemon.growthRate)"), iconName: "arrow.up.to.line.alt", color: .yellow)
            }

        }
        
    }
    
    // Functions
    func metersToFeetAndInches(meters: Double) -> String {
        let totalInches = Double(meters) * 39.37
        let feet = Int(totalInches / 12)
        let inchesLeftOver = totalInches.truncatingRemainder(dividingBy: 12)
        return "\(feet)'\(Int(inchesLeftOver.rounded()))\""
    }
    func kgtolbs(kg: Double) -> String {
        return "\((kg * 2.205).rounded(toPlaces: 1))"
    }
    
}

struct PDVInfoAreaView_Previews: PreviewProvider {
    static var previews: some View {
        PDVInfoAreaView(pokemon: Pokemon.theTestList()[2])
    }
}

struct InfoView: View {
    
    // Variables
    var name: String
    var value: String
    var iconName: String
    var color: Color
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .foregroundColor(color)
                .opacity(0.3)
                .frame(height: 60)
            
            HStack {
                
                Image(systemName: "\(iconName)")
                    .imageScale(.large)
                    .frame(width: 30)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading) {
                    
                    Text(name.uppercased())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text(value)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
//                    if name == "Base Friendship" {
//                        Text(name.uppercased())
//                            .foregroundColor(.secondary)
//                            .font(.system(size: 14))
//                    } else {
//                        Text(name.uppercased())
//                            .foregroundColor(.secondary)
//                    }
//
//                    if name == "Egg Groups" && value.contains("&") {
//                        Text(value)
//                            .fontWeight(.bold)
//                            .font(.system(size: 15))
//                            .foregroundColor(.primary)
//                    } else if name == "EV Yield" && value.contains(",") {
//                        Text(value)
//                            .fontWeight(.bold)
//                            .font(.system(size: 12))
//                            .foregroundColor(.primary)
//                    } else {
//                        Text(value)
//                            .fontWeight(.bold)
//                            .foregroundColor(.primary)
//                    }
                    
                }
                
                Spacer()
                
            }
            .padding(.leading)
            
        }
        
    }
    
}

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
