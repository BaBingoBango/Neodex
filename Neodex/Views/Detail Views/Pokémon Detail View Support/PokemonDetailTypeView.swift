//
//  PokemonDetailTypeView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/7/20.
//

import SwiftUI

struct PokemonDetailTypeView: View {
    
    // Variables
    var types: [String]
    
    var body: some View {
        
        HStack {
            
            ZStack {
                
                Rectangle()
                    .cornerRadius(7)
                    .foregroundColor(getColor(type: types[0]))
                    .frame(width: 105, height: 35, alignment: .center)
                
                Text(types[0].uppercased())
                    .font(Font.custom("Andale Mono", size: 20))
                    .foregroundColor(Color.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
            }
            
            if types[1] != "" {
                ZStack {
                    
                    Rectangle()
                        .cornerRadius(7)
                        .foregroundColor(getColor(type: types[1]))
                        .frame(width: 105, height: 35, alignment: .center)
                    
                    Text(types[1].uppercased())
                        .font(Font.custom("Andale Mono", size: 20))
                        .foregroundColor(Color.white)
                    
                }
            }
            
        }
        
    }
    
    func getColor(type: String) -> Color {
        
        if type == "Normal" {
            return Color.normal
        } else if type == "Fire" {
            return Color.red
        } else if type == "Water" {
            return Color.blue
        } else if type == "Electric" {
            return Color.yellow
        } else if type == "Grass" {
            return Color.green
        } else if type == "Ice" {
            return Color.ice
        } else if type == "Fighting" {
            return Color.fighting
        } else if type == "Poison" {
            return Color.poison
        } else if type == "Ground" {
            return Color.ground
        } else if type == "Flying" {
            return Color.flying
        } else if type == "Psychic" {
            return Color.psychic
        } else if type == "Bug" {
            return Color.bug
        } else if type == "Rock" {
            return Color.rock
        } else if type == "Ghost" {
            return Color.ghost
        } else if type == "Dragon" {
            return Color.dragon
        } else if type == "Dark" {
            return Color.dark
        } else if type == "Steel" {
            return Color.steel
        } else if type == "Fairy" {
            return Color.fairy
        } else {
            return Color.gray
        }
    }
    
}

struct PokemonDetailTypeView_Previews: PreviewProvider {
    static var previews: some View {
        PokemonDetailTypeView(types: ["Fighting", "Fire"])
    }
}

struct BigPDTV: View {
    
    // Variables
    var types: [String]
    
    var body: some View {
        HStack {
            
            ZStack {
                
                Rectangle()
                    .cornerRadius(7)
                    .foregroundColor(getColor(type: types[0]))
                    .frame(height: 50, alignment: .center)
                
                Text(types[0].uppercased())
                    .font(Font.custom("Andale Mono", size: 30))
                    .foregroundColor(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
            }
            .padding(.horizontal, types[1] != "" ? 0 : UIScreen.screenWidth / 4)
            
            if types[1] != "" {
                ZStack {
                    
                    Rectangle()
                        .cornerRadius(7)
                        .foregroundColor(getColor(type: types[1]))
                        .frame(height: 50, alignment: .center)
                    
                    Text(types[1].uppercased())
                        .font(Font.custom("Andale Mono", size: 30))
                        .foregroundColor(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                }
            }
            
        }
        
    }
    
    func getColor(type: String) -> Color {
        
        if type == "Normal" {
            return Color.normal
        } else if type == "Fire" {
            return Color.red
        } else if type == "Water" {
            return Color.blue
        } else if type == "Electric" {
            return Color.yellow
        } else if type == "Grass" {
            return Color.green
        } else if type == "Ice" {
            return Color.ice
        } else if type == "Fighting" {
            return Color.fighting
        } else if type == "Poison" {
            return Color.poison
        } else if type == "Ground" {
            return Color.ground
        } else if type == "Flying" {
            return Color.flying
        } else if type == "Psychic" {
            return Color.psychic
        } else if type == "Bug" {
            return Color.bug
        } else if type == "Rock" {
            return Color.rock
        } else if type == "Ghost" {
            return Color.ghost
        } else if type == "Dragon" {
            return Color.dragon
        } else if type == "Dark" {
            return Color.dark
        } else if type == "Steel" {
            return Color.steel
        } else if type == "Fairy" {
            return Color.fairy
        } else {
            return Color.gray
        }
    }
    
}

struct WidthlessPokemonDetailTypeView: View {
    
    // Variables
    var types: [String]
    
    var body: some View {
        
        HStack {
            
            ZStack {
                
                Rectangle()
                    .cornerRadius(7)
                    .foregroundColor(getColor(type: types[0]))
                    .frame(height: 35, alignment: .center)
                
                Text(types[0].uppercased())
                    .font(Font.custom("Andale Mono", size: 20))
                    .foregroundColor(Color.white)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                
            }
            
            if types[1] != "" {
                ZStack {
                    
                    Rectangle()
                        .cornerRadius(7)
                        .foregroundColor(getColor(type: types[1]))
                        .frame(height: 35, alignment: .center)
                    
                    Text(types[1].uppercased())
                        .font(Font.custom("Andale Mono", size: 20))
                        .foregroundColor(Color.white)
                    
                }
            }
            
        }
        
    }
    
    func getColor(type: String) -> Color {
        
        if type == "Normal" {
            return Color.normal
        } else if type == "Fire" {
            return Color.red
        } else if type == "Water" {
            return Color.blue
        } else if type == "Electric" {
            return Color.yellow
        } else if type == "Grass" {
            return Color.green
        } else if type == "Ice" {
            return Color.ice
        } else if type == "Fighting" {
            return Color.fighting
        } else if type == "Poison" {
            return Color.poison
        } else if type == "Ground" {
            return Color.ground
        } else if type == "Flying" {
            return Color.flying
        } else if type == "Psychic" {
            return Color.psychic
        } else if type == "Bug" {
            return Color.bug
        } else if type == "Rock" {
            return Color.rock
        } else if type == "Ghost" {
            return Color.ghost
        } else if type == "Dragon" {
            return Color.dragon
        } else if type == "Dark" {
            return Color.dark
        } else if type == "Steel" {
            return Color.steel
        } else if type == "Fairy" {
            return Color.fairy
        } else {
            return Color.gray
        }
    }
    
}
