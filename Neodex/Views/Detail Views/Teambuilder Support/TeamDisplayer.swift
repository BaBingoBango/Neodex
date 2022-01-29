//
//  TeamDisplayer.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/13/21.
//

import SwiftUI

struct TeamDisplayer: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    var tIndex: Int
    
    var body: some View {
        
        if sessionData.teams.count >= tIndex + 1 {
            VStack {
                
                if sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].getNumMembers() == 0 {
                    
                    Text("No Pokémon...yet!")
                        .foregroundColor(.secondary)
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(height: 160)
                        .padding(.horizontal)
                    
                } else {
                    
                    HStack(spacing: -35) {
                        
                        if sessionData.teams[tIndex].members[0] != nil {
                            GIFView(gifName: "\(sessionData.teams[tIndex].members[0]!.pokemon.name)-gif")
                        } else {
                            GIFView(gifName: "Bulbasaur-gif")
                                .hidden()
                        }
                        if sessionData.teams[tIndex].members[1] != nil {
                            GIFView(gifName: "\(sessionData.teams[tIndex].members[1]!.pokemon.name)-gif")
                        } else {
                            GIFView(gifName: "Bulbasaur-gif")
                                .hidden()
                        }
                        if sessionData.teams[tIndex].members[2] != nil {
                            GIFView(gifName: "\(sessionData.teams[tIndex].members[2]!.pokemon.name)-gif")
                        } else {
                            GIFView(gifName: "Bulbasaur-gif")
                                .hidden()
                        }
                        if sessionData.teams[tIndex].members[3] != nil {
                            GIFView(gifName: "\(sessionData.teams[tIndex].members[3]!.pokemon.name)-gif")
                        } else {
                            GIFView(gifName: "Bulbasaur-gif")
                                .hidden()
                        }
                        if sessionData.teams[tIndex].members[4] != nil {
                            GIFView(gifName: "\(sessionData.teams[tIndex].members[4]!.pokemon.name)-gif")
                        } else {
                            GIFView(gifName: "Bulbasaur-gif")
                                .hidden()
                        }
                        if sessionData.teams[tIndex].members[5] != nil {
                            GIFView(gifName: "\(sessionData.teams[tIndex].members[5]!.pokemon.name)-gif")
                        } else {
                            GIFView(gifName: "Bulbasaur-gif")
                                .hidden()
                        }
                        
                    }
                    .frame(height: 110)
                    .padding()
                    
                }
                
                Divider()
                    .padding([.leading, .bottom, .trailing])
                
                HStack {
                    
                    Spacer()
                    
                    VStack {
                        Text("Pokémon")
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("\(sessionData.teams[tIndex].getNumMembers())")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
    //                .scaleEffect(1.1)
                    
                    Spacer()
                    
                    VStack {
                        Text("Types Used")
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("\(sessionData.teams[tIndex].getTypesUsed())")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
    //                .scaleEffect(1.1)
                    
                    Spacer()
                    
                    VStack {
                        Text("Stat Total")
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("\(sessionData.teams[tIndex].getSumStatTotal())")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
    //                .scaleEffect(1.1)
                    
                    Spacer()
                    
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                VStack {
                    
                    TeambuilderStatStat(stat: "HP", num: sessionData.teams[tIndex].getSingleStatTotal(index: 0))
                    TeambuilderStatStat(stat: "Attack", num: sessionData.teams[tIndex].getSingleStatTotal(index: 1))
                    TeambuilderStatStat(stat: "Defense", num: sessionData.teams[tIndex].getSingleStatTotal(index: 2))
                    TeambuilderStatStat(stat: "Sp. Attack", num: sessionData.teams[tIndex].getSingleStatTotal(index: 3))
                    TeambuilderStatStat(stat: "Sp. Defense", num: sessionData.teams[tIndex].getSingleStatTotal(index: 4))
                    TeambuilderStatStat(stat: "Speed", num: sessionData.teams[tIndex].getSingleStatTotal(index: 5))
                    
                }
                .padding(.horizontal)
                
                VStack(spacing: 5) {
                    
                    HStack {
                        
                        PokemonDetailTypeView(types: ["Normal", ""])
                            .scaleEffect(0.8)
                            .hidden()
                        
                        Spacer()
                        
                        Text("9")
                            .font(.title)
                            .fontWeight(.bold)
                            .hidden()
                        
                        Spacer()
                        
                        ZStack {
                            Rectangle()
                                .foregroundColor(.green)
                                .opacity(0.3)
                                .cornerRadius(10)
                                .hidden()
                            Text("Resistant\nPokémon")
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(height: 50)
                                .lineLimit(2)
                                .minimumScaleFactor(0.5)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Rectangle()
                                .foregroundColor(.red)
                                .opacity(0.3)
                                .cornerRadius(10)
                                .hidden()
                            Text("Weak\nPokémon")
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(height: 50)
                                .lineLimit(2)
                                .minimumScaleFactor(0.5)
                        }
                        
                        Spacer()
                        
                    }
                    .padding(.horizontal)
                    
                    ForEach(Type.getTypeList(), id: \.name) { type in
                        
                        TeambuilderDefenseStatRow(type: type.name, tIndex: tIndex).environmentObject(sessionData)
                        
                    }
                    
                }
                
            }
            .padding(.bottom)
        }
        
    }
}

struct TeamDisplayer_Previews: PreviewProvider {
    static var previews: some View {
        TeamDisplayer(tIndex: 0).environmentObject(SessionData())
    }
}

struct TeambuilderStatStat: View {
    
    // Variables
    var stat: String
    var num: Int
    
    var body: some View {
        VStack {
            HStack {
                Text("Total \(stat)")
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(num)")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Divider()
            
        }
    }
}

struct TeambuilderDefenseStatRow: View {
    
    // Variables
    var type: String
    @EnvironmentObject var sessionData: SessionData
    var tIndex: Int
    
    var body: some View {
        
        if sessionData.teams.count >= tIndex + 1 {
            let res = sessionData.teams[tIndex].getResistantMembers(type: type)
            let weak = sessionData.teams[tIndex].getWeakMembers(type: type)
            
            HStack {
                
                NavigationLink(destination: TypeDetailViewN(type: Type.typeLookup(name: type) ?? Type.getTypeList()[0]).navigationBarTitle(Text(""), displayMode: .inline)) {
                    PokemonDetailTypeView(types: [type, ""])
                }
                    .scaleEffect(0.9)
                
                Spacer()
                
                Text("9")
                    .font(.title)
                    .fontWeight(.bold)
                    .hidden()
                
                Spacer()
                
                ZStack {
                    Rectangle()
                        .foregroundColor(res == 0 ? .secondary : .green)
                        .opacity(res == 0 ? 0.0 : 0.2)
                        .frame(height: 30)
    //                    .cornerRadius(10)
                    Text("\(res)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(res == 0 ? .secondary : .green)
                }
                
                Spacer()
                
                ZStack {
                    Rectangle()
                        .foregroundColor(weak == 0 ? .secondary : .red)
                        .opacity(weak == 0 ? 0.0 : 0.2)
                        .frame(height: 30)
    //                    .cornerRadius(10)
                    Text("\(weak)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(weak == 0 ? .secondary : .red)
                }
                
                Spacer()
                
            }
            .padding(.horizontal)
        }
    }
}
