//
//  PDVMovesAreaView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/12/20.
//

import SwiftUI

struct PDVMovesAreaView: View {
    
    // Variables
    var pokemon: Pokemon
    @State var pickerChoice = 0
    var methods = ["Level Up", "TM / TR", "Egg Moves", "Move Tutor"]
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        VStack {
            
            Picker(selection: $pickerChoice, label: Text("")) {
                ForEach(0..<methods.count) {
                    Text(self.methods[$0])
                }
            }
            .padding(.horizontal)
            .pickerStyle(SegmentedPickerStyle())
            
            if pickerChoice == 0 {
                ForEach(filterMoves(name: pokemon.name, method: "Level Up"), id: \.name) { move in
                    
                    NavigationLink(destination: MoveDetailView(move: move, method: "at level \(move.viaLevel[move.viaLevel.firstIndex(where: { $0.name == pokemon.name })!].methodText)").environmentObject(sessionData)) {
                        MoveListOption(move: move, pickerMode: pickerChoice, pokemon: pokemon)
                    }
                    
                }
            } else if pickerChoice == 1 {
                ForEach(filterMoves(name: pokemon.name, method: "TM / TR"), id: \.name) { move in
                    
                    NavigationLink(destination: MoveDetailView(move: move, method: "using \(move.discID)").environmentObject(sessionData)) {
                        MoveListOption(move: move, pickerMode: pickerChoice, pokemon: pokemon)
                    }
                    
                }
            } else if pickerChoice == 2 {
                ForEach(filterMoves(name: pokemon.name, method: "Egg Moves"), id: \.name) { move in
                    
                    NavigationLink(destination: MoveDetailView(move: move, method: "as an egg move").environmentObject(sessionData)) {
                        MoveListOption(move: move, pickerMode: pickerChoice, pokemon: pokemon)
                    }
                    
                }
            } else if pickerChoice == 3 {
                ForEach(filterMoves(name: pokemon.name, method: "Move Tutor"), id: \.name) { move in
                    
                    NavigationLink(destination: MoveDetailView(move: move, method: "from a move tutor").environmentObject(sessionData)) {
                        MoveListOption(move: move, pickerMode: pickerChoice, pokemon: pokemon)
                    }
                    
                }
            }
            
        }
        
    }
}

//struct PDVMovesAreaView_Previews: PreviewProvider {
//    static var previews: some View {
//        PDVMovesAreaView(pokemon: Pokemon.theTestList()[0])
//    }
//}

func filterMoves(name: String, method: String) -> [Move] {
    var answer: [Move] = []
    for eachMove in moveDataList {
        
        if method == "Level Up" {
            for eachPokemon in eachMove.viaLevel {
                if name == eachPokemon.name {
                    answer.append(eachMove)
                }
            }
            
        } else if method == "TM / TR" {
            for eachPokemon in eachMove.viaTM {
                if name == eachPokemon.name {
                    answer.append(eachMove)
                }
            }
            
        } else if method == "Egg Moves" {
            
            for eachPokemon in eachMove.viaEgg {
                if name == eachPokemon.name {
                    answer.append(eachMove)
                }
            }
            
        } else if method == "Move Tutor" {
            
            for eachPokemon in eachMove.viaTutor {
                if name == eachPokemon.name {
                    answer.append(eachMove)
                }
            }
            
        }
    }
    return answer
}

struct MoveListOption: View {
    
    // Variables
    var move: Move
    @Environment(\.colorScheme) var colorScheme
    var pickerMode: Int
    var pokemon: Pokemon
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .cornerRadius(10)
                .frame(height: 80)
                .shadow(color: .secondary, radius: 15)
            
            HStack {
                VStack {
                    ZStack {
                        Rectangle()
                            .frame(width: 80, height: 80)
                            .foregroundColor(typeColorDelegator(type: move.type))
                            .cornerRadius(10)
                        Rectangle()
                            .frame(width: 80, height: 80)
                            .foregroundColor(typeColorDelegator(type: move.type))
                            .offset(x: 10)
                        
                        Text(move.type.uppercased())
                            .font(.custom("Andale Mono", size: 18))
                            .foregroundColor(.white)
                            .offset(x: 5)
                            .offset(y: -20)
                        
                        Rectangle()
                            .frame(width: 80, height: 40)
                            .foregroundColor(categoryColorDelegator(category: move.category))
                            .cornerRadius(10)
                            .offset(y: 20)
                        Rectangle()
                            .frame(width: 80, height: 40)
                            .foregroundColor(categoryColorDelegator(category: move.category))
                            .offset(x: 10)
                            .offset(y: 20)
                        Rectangle()
                            .frame(width: 80, height: 20)
                            .foregroundColor(categoryColorDelegator(category: move.category))
                            .offset(y: 10)
                        
                        Text(move.category.uppercased())
                            .font(.custom("Andale Mono", size: 15))
                            .foregroundColor(.white)
                            .offset(x: 5)
                            .offset(y: 20)
                    }
                }
                
                VStack(alignment: .leading) {
                    
                    Text(move.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.5)
                    
                    if pickerMode == 0 {
                        Text("Level \(move.viaLevel[move.viaLevel.firstIndex(where: { $0.name == pokemon.name })!].methodText)")
                            .foregroundColor(.primary)
                    } else if pickerMode == 1 {
                        Text("\(move.discID)")
                            .foregroundColor(.primary)
                    }
//                    else if pickerMode == 3 {
//                        Text("\(move.viaTutor[move.viaTutor.firstIndex(where: { $0.name == pokemon.name })!].methodText)")
//                            .foregroundColor(.primary)
//                    }
                    
                }
                .padding(.leading)
                
                Spacer()
                
                HStack {
                    ZStack {
                        Rectangle()
                            .frame(width: 35, height: 80)
                            .foregroundColor(.red)
                        VStack {
                            Image(systemName: "bolt.fill")
                                .font(Font.body.weight(.bold))
                                .foregroundColor(.white)
                            Text(move.power != -1 ? String(move.power) : "--")
                                .fontWeight(.bold)
                                .foregroundColor(Color.white)
                                .offset(y: 2)
                        }
                    }
                    
                    ZStack {
                        Rectangle()
                            .frame(width: 35, height: 80)
                            .foregroundColor(.blue)
                        VStack {
                            Image(systemName: "scope")
                                .font(Font.body.weight(.bold))
                                .foregroundColor(.white)
                            Text(getAcc(move: move))
                                .fontWeight(.bold)
                                .foregroundColor(Color.white)
                                .offset(y: 2)
                        }
                    }
                }
                .padding(.trailing, 20)
                
            }
            
        }
        .padding([.top, .leading, .trailing])
    }

}

func getAcc(move: Move) -> String {
    if move.accuracy != -1 && move.accuracy != -2 {
        return String(move.accuracy)
    } else if move.accuracy == -2 {
        return "∞"
    } else {
        return "--"
    }
}

