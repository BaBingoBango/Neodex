//
//  TeambuilderMoveDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/5/21.
//

import SwiftUI

struct TeambuilderMoveDetailView: View {
    
    // Variables
    var tIndex: Int
    var pIndex: Int
    var index: Int
    var prez: Binding<PresentationMode>
    var move: Move
    var pokemon: Pokemon? // This is only if the view originates from a Pokémon detail view
    var method: String?
    @State var segmentChoice = 0
    var methods = ["Level Up", "TM / TR", "Egg Moves", "Move Tutor"]
    @EnvironmentObject var sessionData: SessionData
    @State var showingTypeDetail = false
    
    // This view shows detailed information about a particular view - it will appear in Pokémon detail views and in other lists of moves when move list option views are tapped on.
    
    var body: some View {
        
        ScrollView {
            
            VStack {
                
                ZStack {
                    Rectangle()
                        .foregroundColor(typeColorDelegator(type: move.type))
                        .frame(height: 200)
                        .opacity(0.6)

                    VStack(spacing: 10) {
                        Text(move.name)
                            .font(.system(size: 40))
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                            .offset(y: 0)
                        
                        HStack {
                            Button(action: {
                                showingTypeDetail.toggle()
                            }) {
                                ZStack {

                                    Rectangle()
                                        .cornerRadius(7)
                                        .foregroundColor(typeColorDelegator(type: move.type))
                                        .frame(width: 105, height: 35, alignment: .center)

                                    Text(move.type.uppercased())
                                        .font(Font.custom("Andale Mono", size: 20))
                                        .foregroundColor(Color.white)

                                }
                            }
                            .offset(y: 0)
                            .sheet(isPresented: $showingTypeDetail) {
                                TypeDetailView(type: Type.toType(list: [move.type])[0]).environmentObject(sessionData)
                            }
                            ZStack {

                                Rectangle()
                                    .cornerRadius(7)
                                    .foregroundColor(categoryColorDelegator(category: move.category))
                                    .frame(width: 105, height: 35, alignment: .center)

                                Text(move.category.uppercased())
                                    .font(Font.custom("Andale Mono", size: 20))
                                    .foregroundColor(Color.white)

                            }
                            .offset(y: 0)

                        }
                    }
                    .offset(y: 0)
                }

                // MARK: Set item button for teambuilder
                Button(action: {
                    
                    sessionData.teams[tIndex].members[pIndex]!.moves[index] = move
                    prez.wrappedValue.dismiss()
                    
                }) {
                    Text("Set Move")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color.white)
                        .padding()
                        .padding(.horizontal, 80.0)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                HStack {
                    Text(move.description)
                        .fontWeight(.bold)
                        .frame(height: 100)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding([.top, .leading])
                
                HStack(spacing: 20) {
                    
                    VStack {
                        GeometryReader { geo in
                            VStack {
                                ProgressBar(progress: (Float(move.power) / 100.0), max: 1.0, color: .red, priority: move.priority, accuracy: move.accuracy, isAcc: false, isPower: true, power: move.power)
                                    .frame(height: geo.size.width)
                                Text("Power")
                                    .fontWeight(.bold)
                                    .padding(.top, 7)
                                    .frame(width: UIScreen.screenWidth / 4)
                            }
                        }
                    }
                    VStack {
                        GeometryReader { geo in
                            VStack {
                                ProgressBar(progress: (Float(move.accuracy) / 100.0), max: 1.0, color: .blue, priority: move.priority, accuracy: move.accuracy, isAcc: true, isPower: false, power: move.power)
                                    .frame(height: geo.size.width)
                                Text("Acc.")
                                    .fontWeight(.bold)
                                    .padding(.top, 7)
                                    .frame(width: UIScreen.screenWidth / 4)
                            }
                        }
                    }
                    VStack {
                        GeometryReader { geo in
                            VStack {
                                ProgressBar(progress: (Float(move.PP) / 100.0), max: 0.4, color: .purple, priority: move.priority, accuracy: move.accuracy, isAcc: false, isPower: false, power: move.power)
                                    .frame(height: geo.size.width)
                                Text("PP")
                                    .fontWeight(.bold)
                                    .padding(.top, 7)
                                    .frame(width: UIScreen.screenWidth / 4)
                            }
                        }
                    }
                    VStack {
                        GeometryReader { geo in
                            VStack {
                                ProgressBar(progress: (Float(move.priority) / 100.0), max: 0.0, color: .green, priority: move.priority, accuracy: move.accuracy, isAcc: false, isPower: false, power: move.power)
                                    .frame(height: geo.size.width)
                                Text("Priority")
                                    .fontWeight(.bold)
                                    .padding(.top, 7)
                                    .frame(width: UIScreen.screenWidth / 4)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.leading, 5)
                .padding(.bottom, 100)
                
//                HStack {
//
//                    VStack {
//                        ProgressBar(progress: (Float(move.power) / 100.0), max: 1.0, color: .red, priority: move.priority, accuracy: move.accuracy, isAcc: false, isPower: true, power: move.power)
//                            .frame(width: 68, height: 68, alignment: .center)
//                        Text("Power")
//                            .font(.headline)
//                            .fontWeight(.bold)
//                            .offset(y: 0)
//                            .foregroundColor(.primary)
//                    }
//                    .padding(.trailing)
//
//                    VStack {
//                        ProgressBar(progress: (Float(move.accuracy) / 100.0), max: 1.0, color: .blue, priority: move.priority, accuracy: move.accuracy, isAcc: true, isPower: false, power: move.power)
//                            .frame(width: 68, height: 68, alignment: .center)
//                        Text("Accuracy")
//                            .font(.headline)
//                            .fontWeight(.bold)
//                            .offset(y: 0)
//                            .foregroundColor(.primary)
//                    }
//                    .padding(.trailing)
//
//                    VStack {
//                        ProgressBar(progress: (Float(move.PP) / 100.0), max: 0.4, color: .purple, priority: move.priority, accuracy: move.accuracy, isAcc: false, isPower: false, power: move.power)
//                            .frame(width: 68, height: 68, alignment: .center)
//                        Text("PP")
//                            .font(.headline)
//                            .fontWeight(.bold)
//                            .offset(y: 0)
//                            .foregroundColor(.primary)
//                    }
//                    .padding(.trailing)
//
//                    VStack {
//                        ProgressBar(progress: (Float(move.priority) / 100.0), max: 0.0, color: .green, priority: move.priority, accuracy: move.accuracy, isAcc: false, isPower: false, power: move.power)
//                            .frame(width: 68, height: 68, alignment: .center)
//                        Text("Priority")
//                            .font(.headline)
//                            .fontWeight(.bold)
//                            .offset(y: 0)
//                            .foregroundColor(.primary)
//                    }
//
//                }
//                .padding(.bottom)
                
                if let unwrapped = pokemon {
                    
                    ZStack {
                        Rectangle()
                            .foregroundColor(typeColorDelegator(type: move.type))
                            .cornerRadius(25)
                            .padding(.horizontal)
                            .frame(height: 100)
                            .opacity(0.6)
                        
                        HStack {
                            
                            Image("\(unwrapped.name)-art")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .aspectRatio(contentMode: .fit)
                                .padding(.leading, 30)
                            
                            Spacer()
                            
                            Text("\(unwrapped.name) learns \(move.name) \(method ?? "")")
                                .fontWeight(.bold)
                                .foregroundColor(Color.white)
                                .padding(.trailing, 30)
                                .frame(height: 80)
                            
                            Spacer()
                            
                        }
                    }
                        .offset(y: 0)
                    
                }
                
                HStack {
                    Text("Compatible Pokémon")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.leading)
                .offset(y: 0)
                
                Picker(selection: $segmentChoice, label: Text("")) {
                    ForEach(0..<methods.count) {
                        Text(methods[$0])
                    }
                }
                .padding(.horizontal, 5)
                .padding(.bottom)
                .pickerStyle(SegmentedPickerStyle())
                .offset(y: 0)
                
                if segmentChoice == 0 {
                    
                    if move.viaLevel.count != 0 {
                        LazyVStack {
                            ForEach(pokemonDataList.filter {
                                for eachMethod in move.viaLevel {
                                    if eachMethod.name == $0.name {
                                        return true
                                    }
                                }
                                return false
                            }, id: \.name) { pokemon in
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData)) {
                                    PokemonListOption(pokemon: pokemon)
                                        .padding(.bottom, 5)
                                }
                            }
                        }
                        .offset(y: 0)
                        
                    } else {
                        Text("This move is not learned by level up.")
                            .fontWeight(.bold)
                            .offset(y: 0)
                            .foregroundColor(.primary)
                    }
                } else if segmentChoice == 1 {
                    if move.viaTM.count != 0 {
                        LazyVStack {
                            ForEach(pokemonDataList.filter {
                                for eachVia in move.viaTM {
                                    if eachVia.name == $0.name {
                                        return true
                                    }
                                }
                                return false
                            }, id: \.name) { pokemon in
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData)) {
                                    PokemonListOption(pokemon: pokemon)
                                }
                            }
                        }
                        .offset(y: 0)
                    } else {
                        Text("This move is not learned by TM or TR.")
                            .fontWeight(.bold)
                            .offset(y: 0)
                            .foregroundColor(.primary)
                    }
                } else if segmentChoice == 2 {
                    if move.viaEgg.count != 0 {
                        LazyVStack {
                            ForEach(pokemonDataList.filter {
                                for eachVia in move.viaEgg {
                                    if eachVia.name == $0.name {
                                        return true
                                    }
                                }
                                return false
                            }, id: \.name) { pokemon in
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData)) {
                                    PokemonListOption(pokemon: pokemon)
                                }
                            }
                        }
                        .offset(y: 0)
                    } else {
                        Text("This move is not learned through breeding.")
                            .fontWeight(.bold)
                            .offset(y: 0)
                            .foregroundColor(.primary)
                    }
                } else if segmentChoice == 3 {
                    if move.viaTutor.count != 0 {
                        LazyVStack {
                            ForEach(pokemonDataList.filter {
                                for eachVia in move.viaTutor {
                                    if eachVia.name == $0.name {
                                        return true
                                    }
                                }
                                return false
                            }, id: \.name) { pokemon in
                                NavigationLink(destination: PokemonDetailView(pokemon: pokemon).environmentObject(sessionData)) {
                                    PokemonListOption(pokemon: pokemon)
                                }
                            }
                        }
                        .offset(y: 0)
                    } else {
                        Text("This move is not learned through a move tutor.")
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .offset(y: 0)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
            }
            .offset(y: 0)
            
            
            .navigationBarTitle(Text(""), displayMode: .inline)
//            .navigationBarItems(trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text(buttonText) })
        }
//        .edgesIgnoringSafeArea(.top)
        .onAppear {
            // Add this to the user's history
//            sessionData.userRecords.moveHistory.append(move)
        }
        
        
    }
    
    // Functions
    func getMethodList(move: Move) -> [String] {
        var answer: [String] = []
        if move.viaLevel.count >= 1 {
            answer.append("Level Up")
        } else if move.viaTM.count >= 1 {
            answer.append("TM / TR")
        } else if move.viaEgg.count >= 1 {
            answer.append("Egg Moves")
        } else if move.viaTutor.count >= 1 {
            answer.append("Move Tutor")
        }
        return answer
    }
    
}
