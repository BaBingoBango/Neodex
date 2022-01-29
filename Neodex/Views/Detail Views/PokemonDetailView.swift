//
//  PokemonDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/7/20.
//

import SwiftUI
import AVFoundation

struct PokemonDetailView: View {
    
    // Variables
    var pokemon: Pokemon
    @State var showingTypeView = false
    @State var showingFaceOff = false
    @Environment(\.presentationMode) var presentationMode
    var buttonText: String = ""
    @EnvironmentObject var sessionData: SessionData
    let synthesizer = AVSpeechSynthesizer()
    @State var currentDexEntryIndex = 0
    
    var body: some View {
        ScrollView {
            
            ZStack {
                
                VStack {
                    
                    ZStack {
                        HStack(alignment: .bottom) {
                            
                            ZStack {
                                
                                Rectangle()
                                    .rotation(.init(degrees: -10))
                                    .frame(width: 1000, height: 1000, alignment: .center)
                                    .frame(width: 50, height: 50)
                                    .offset(y: -470)
                                    .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                
                                Image("\(pokemon.name)-art")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150)
                                    .hidden()
                                    .padding(.bottom)
                                
                            }
                            
                            HStack {
                                
                                Spacer()
                                
                                Text(pokemon.name)
                                    .font(.system(size: 40))
                                    .fontWeight(.heavy)
                                    .padding(.trailing, 10)
                                    .foregroundColor(.primary)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                
                            }
                            .frame(width: 3.5 * (UIScreen.main.bounds.width) / 6)
                            .padding(.trailing, 7)
                            
                        }
                        
                    }
                    
                    HStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            if pokemon.type2 != "" {
                                
                                Button(action: {
                                    self.showingTypeView.toggle()
                                }) {
                                    WidthlessPokemonDetailTypeView(types: [pokemon.type1, pokemon.type2])
                                    Image(systemName: "chevron.right")
                                        .imageScale(.large)
                                        .foregroundColor(.primary)
                                }.sheet(isPresented: $showingTypeView) {
                                    TypeDetailView(type: Type.typeLookup(name: pokemon.type1)!, type2: Type.typeLookup(name: pokemon.type2))
                                }
                                
                            } else {
                                
                                Button(action: {
                                    self.showingTypeView.toggle()
                                }) {
                                    HStack(spacing: 0) {
                                        WidthlessPokemonDetailTypeView(types: [pokemon.type1, pokemon.type2])
                                            .hidden()
                                        WidthlessPokemonDetailTypeView(types: [pokemon.type1, pokemon.type2])
                                    }
                                    Image(systemName: "chevron.right")
                                        .imageScale(.large)
                                        .foregroundColor(.primary)
                                }.sheet(isPresented: $showingTypeView) {
                                    TypeDetailView(type: Type.typeLookup(name: pokemon.type1)!, type2: Type.typeLookup(name: pokemon.type2))
                                }
                                
                            }
                            
//                            Button(action: {
//                                self.showingTypeView.toggle()
//                            }) {
//                                if pokemon.type2 != "" {
//                                    WidthlessPokemonDetailTypeView(types: [pokemon.type1, pokemon.type2])
//                                } else {
//                                    HStack(spacing: 0) {
//                                        WidthlessPokemonDetailTypeView(types: [pokemon.type1, pokemon.type2])
//                                            .hidden()
//                                        WidthlessPokemonDetailTypeView(types: [pokemon.type1, pokemon.type2])
//                                    }
//                                }
//
//                                Image(systemName: "chevron.right")
//                                    .imageScale(.large)
//                                    .foregroundColor(.primary)
//                            }.sheet(isPresented: $showingTypeView) {
//                                TypeDetailView(type: Type.typeLookup(name: pokemon.type1)!, type2: Type.typeLookup(name: pokemon.type2))
//                            }
                            
                        }
                        .frame(width: UIScreen.screenWidth / 1.5)
                        .padding(.trailing, 17)
                    .offset(y: -25)
                    }
                    
                    Text("—  \(pokemon.speciesName) Pokémon  —")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.top)
                        .offset(y: -25)
                    
                    VStack {
                        PDVDexEntryView(pokemon: pokemon, currentDexEntryIndex: $currentDexEntryIndex)
                            .frame(height: 150)
                            .padding(.horizontal)
                            .frame(width: UIScreen.screenWidth)

                        PDVAbilityAreaView(pokemon: pokemon).environmentObject(sessionData)
                            .padding([.top, .leading, .trailing])
                            .frame(width: UIScreen.screenWidth)

                        HeadingText(text: "Base Stats")
                        .padding(.top)

                        PDVStatsAreaView(pokemon: pokemon)
                    }
                    .frame(width: UIScreen.screenWidth)
                    
                    VStack {
                        
                        HeadingText(text: "Evolutions")
                            .padding(.top, 225)
                        
                        PDVEvolutionAreaView(pokemon: pokemon).environmentObject(sessionData)
                            .padding(.horizontal)
                        
                        HStack {
                            Text("Characteristics")
                                .font(.title)
                                .fontWeight(.bold)
                                .padding(.leading)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.top, 30)
                        
                        PDVInfoAreaView(pokemon: pokemon)
                        
                        HStack {
                            Text("Galar Locations")
                                .font(.title)
                                .fontWeight(.bold)
                                .padding(.leading)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.top, 30)
                        
                        PDVLocationsArea(pokemon: pokemon)
                            .padding(.horizontal)
                        
                        HStack {
                            Text("Moves")
                                .font(.title)
                                .fontWeight(.bold)
                                .padding(.leading)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.top, 30)
                    }
                    .frame(width: UIScreen.screenWidth)
                    
                    PDVMovesAreaView(pokemon: pokemon).padding(.horizontal, 5).environmentObject(sessionData)
                    
                    Spacer()
                    
                }
                .padding(.top, 100)
                
                VStack {
                    
                    HStack(alignment: .top) {
                        
                        Text(pokemon.nationalDexNum)
                            .font(.system(size: 150))
                            .foregroundColor(Color.white)
                            .padding(.leading, 5)
                            .shadow(radius: 10)
                            .shadow(radius: 10)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer()
                        
                        VStack {
                            
                            DetailViewAudioButton(pokemon: pokemon, synthesizer: synthesizer, currentDexEntryIndex: $currentDexEntryIndex)
                                .padding([.trailing, .bottom])
                                .padding(.top, 30)
                                .frame(width: 50, height: 50)
                            
                            DetailViewFaceOffButton(showingFaceOff: $showingFaceOff, pokemon: pokemon).environmentObject(sessionData)
                                .padding([.top, .trailing])
                                .frame(width: 50, height: 50)
                            
                        }
                        
                        
                    }
                    
                    Spacer()
                    
                }
                .frame(width: UIScreen.screenWidth)
                
                VStack {
                    
                    HStack {
                        
                        Image("\(pokemon.name)-art")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150)
                        
                        Spacer()
                        
                        VStack {
                            
                            Text(pokemon.name)
                                .font(.system(size: 40))
                                .fontWeight(.heavy)
                                .foregroundColor(.primary)
                                .hidden()
                            
                            HStack {

                                Text(pokemon.type1)
                                    .hidden()

                                Text(pokemon.type2)
                                    .hidden()

                            }
                            
                        }
                        
                    }
                    .padding(.leading, 30)
                    
                    
                    Spacer()
                    
                }
                .padding(.top, 100)
                
            }
            .frame(width: UIScreen.screenWidth)
            
            
            .navigationBarTitle(Text(pokemon.name), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text(buttonText)
            })
//            .navigationBarItems(trailing: FaceOffNavButton(showingFaceOff: $showingFaceOff, pokemon: pokemon))
        }
        
        .onAppear {
            
            // Add this to the user's history
//            sessionData.userRecords.pokemonHistory.append(pokemon)
            
        }
        .onDisappear {
            
            synthesizer.stopSpeaking(at: .immediate)
            
        }
        
    }
}

struct PokemonDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PokemonDetailView(pokemon: Pokemon.findPokemon(name: "Marowak-Alola")).environmentObject(SessionData())
//            PokemonDetailView(pokemon: pokemonDataList[600]).environmentObject(SessionData())
        }
    }
}

struct DetailViewFaceOffButton: View {
    
    // Variables
    @Binding var showingFaceOff: Bool
    var pokemon: Pokemon
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        Button(action: {
            showingFaceOff.toggle()
        }) {
            HStack {
                Spacer()
                VStack {
                                    
                    Image(systemName: "bolt.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                }
                .padding([.top, .trailing])
            }
        }
        .sheet(isPresented: $showingFaceOff) {
            NavigationView {
                FaceOffView(pokemon1: pokemon, buttonText: "Done").environmentObject(sessionData)
            }
        }
        
    }
    
}

struct DetailViewAudioButton: View {
    
    // Variables
    var pokemon: Pokemon
    let synthesizer: AVSpeechSynthesizer
    @Binding var currentDexEntryIndex: Int
    
    var body: some View {
        
        Button(action: {
            
            // Play text-to-speech readout
            
            let utterance: AVSpeechUtterance
            
            if pokemon.type2 == "" {
                utterance = AVSpeechUtterance(string: "\(pokemon.name). The \(pokemon.speciesName) Pokémon. A \(pokemon.type1) type. \(pokemon.dexEntries[currentDexEntryIndex].entry)")

            } else {
                utterance = AVSpeechUtterance(string: "\(pokemon.name). The \(pokemon.speciesName) Pokémon. A \(pokemon.type1) and \(pokemon.type2) type. \(pokemon.dexEntries[currentDexEntryIndex].entry)")
            }
            
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            
            synthesizer.speak(utterance)
            
        }) {
            HStack {
                Spacer()
                VStack {
                                    
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                }
                .padding([.top, .trailing])
            }
        }
        
    }
    
}
