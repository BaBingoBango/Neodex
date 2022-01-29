//
//  FaceOffView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/22/20.
//

import SwiftUI

/// This is the view for Face-Off! It takes in two Pokemon objects, then returns a fantastic UI comparing the two! Wow! It needs one support view, FOComparisonView! That's those colorful bars that compare stats!
struct FaceOffView: View {
    
    // Variables
    @State var pokemon1: Pokemon?
    @State var pokemon2: Pokemon?
    @State var showingPicker1 = false
    @State var showingPicker2 = false
    @State var showingDetail1 = false
    @State var showingDetail2 = false
    @Environment(\.presentationMode) var presentationMode
    var buttonText: String = ""
    @State var showingSettings = false
    @State var showingHelp = false
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        ScrollView {
            VStack {
                
                ZStack {
                    
                    HStack {

                        if pokemon1 != nil {
                            ZStack {
                                Rectangle()
                                    .frame(height: 200)
                                    .foregroundColor(typeColorDelegator(type: pokemon1!.type1))
                                
                                VStack {
                                    Button(action: {
                                        pokemon1 = nil
                                    }) {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "xmark.circle.fill")
                                                .resizable()
                                                .frame(width: 30, height: 30)
                                                .foregroundColor(.black)
                                        }
                                        .padding([.top, .trailing])
                                    }
                                    
                                    Button(action: {
                                        self.showingDetail1.toggle()
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Spacer()
                                                PictureGIFView(pokemon: pokemon1!)
                                                    .frame(width: 80, height: 80)
                                                Text(pokemon1!.name)
                                                    .font(.title)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(Color.white)
                                                    .minimumScaleFactor(0.5)
                                                    .lineLimit(1)
                                            }
                                            .padding([.leading, .bottom])
                                            Spacer()
                                        }
                                    }
                                    .sheet(isPresented: $showingDetail1) {
                                        NavigationView {
                                            PokemonDetailView(pokemon: pokemon1!, buttonText: "Done").environmentObject(sessionData)
                                        }
                                    }
                                }
                            }

                        } else {
                            Button(action: {
                                self.showingPicker1.toggle()
                            }) {
                                ZStack {
                                    Rectangle()
                                        .frame(height: 200)
                                        .foregroundColor(.gray)
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .resizable()
                                                .padding(.all)
                                                .frame(width: 80, height: 80)
                                                .foregroundColor(.black)
                                            Text("Pokémon")
                                                .font(.title)
                                                .fontWeight(.bold)
                                                .foregroundColor(Color.white)
                                        }
                                        .padding([.bottom, .leading])
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .sheet(isPresented: $showingPicker1) {
                                NavigationView {
                                    PokedexView(pokemon: $pokemon1, isInFaceOff: true)
                                }
                            }
                        }
                        
                        if pokemon2 != nil {
                            ZStack {
                                Rectangle()
                                    .frame(height: 200)
                                    .foregroundColor(typeColorDelegator(type: pokemon2!.type1))
                                
                                VStack {
                                    Button(action: {
                                        pokemon2 = nil
                                    }) {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "xmark.circle.fill")
                                                .resizable()
                                                .frame(width: 30, height: 30)
                                                .foregroundColor(.black)
                                        }
                                        .padding([.top, .trailing])
                                    }
                                    
                                    Button(action: {
                                        self.showingDetail2.toggle()
                                    }) {
                                        HStack {
                                            Spacer()
                                            VStack(alignment: .trailing) {
                                                Spacer()
                                                PictureGIFView(pokemon: pokemon2!)
                                                    .frame(width: 80, height: 80)
                                                Text(pokemon2!.name)
                                                    .font(.title)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(Color.white)
                                                    .minimumScaleFactor(0.5)
                                                    .lineLimit(1)
                                            }
                                            .padding([.bottom, .trailing])
                                        }
                                    }
                                    .sheet(isPresented: $showingDetail2) {
                                        NavigationView {
                                            PokemonDetailView(pokemon: pokemon2!, buttonText: "Done").environmentObject(sessionData)
                                        }
                                    }
                                }
                                
                            }
                        } else {
                            Button(action: {
                                self.showingPicker2.toggle()
                            }) {
                                ZStack {
                                    Rectangle()
                                        .frame(height: 200)
                                        .foregroundColor(.gray)
                                    HStack {
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .resizable()
                                                .padding(.all)
                                                .frame(width: 80, height: 80)
                                                .foregroundColor(.black)
                                            Text("Pokémon")
                                                .font(.title)
                                                .fontWeight(.bold)
                                                .foregroundColor(Color.white)
                                        }
                                        .padding([.bottom, .trailing])
                                    }
                                }
                            }
                            .sheet(isPresented: $showingPicker2) {
                                NavigationView {
                                    PokedexView(pokemon: $pokemon2, isInFaceOff: true)
                                }
                            }
                        }

                    }
                    
                    Text("VS")
                        .font(.system(size: 60))
                        .fontWeight(.heavy)
                        .foregroundColor(Color.white)
                        .shadow(radius: 10)
                    
                }
                
                if pokemon1 != nil && pokemon2 != nil {
                    HStack {
                        Text("Base Stats")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding([.top, .leading])
                    
                    // Base stats area
                    VStack {
                        FOComparisonView(stat1: pokemon1!.baseStats[0], color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.baseStats[0], color2: typeColorDelegator(type: pokemon2!.type1), name: "HP", imageName: "heart.circle.fill")
                        
                        FOComparisonView(stat1: pokemon1!.baseStats[1], color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.baseStats[1], color2: typeColorDelegator(type: pokemon2!.type1), name: "Attack", imageName: "burst.fill")
                        
                        FOComparisonView(stat1: pokemon1!.baseStats[2], color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.baseStats[2], color2: typeColorDelegator(type: pokemon2!.type1), name: "Defense", imageName: "shield.fill")
                        
                        FOComparisonView(stat1: pokemon1!.baseStats[3], color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.baseStats[3], color2: typeColorDelegator(type: pokemon2!.type1), name: "Special Attack", imageName: "bolt.circle.fill")
                        
                        FOComparisonView(stat1: pokemon1!.baseStats[4], color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.baseStats[4], color2: typeColorDelegator(type: pokemon2!.type1), name: "Special Defense", imageName: "shield.checkerboard")
                        
                        FOComparisonView(stat1: pokemon1!.baseStats[5], color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.baseStats[5], color2: typeColorDelegator(type: pokemon2!.type1), name: "Speed", imageName: "hare.fill")
                        
                        FOComparisonView(stat1: getBST(pokemon: pokemon1!), color1: typeColorDelegator(type: pokemon1!.type1), stat2: getBST(pokemon: pokemon2!), color2: typeColorDelegator(type: pokemon2!.type1), name: "Base Stat Total", imageName: "star.fill")
                    }
                    
                    // Abilities area
                    HStack {
                        Text("Abilities")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding([.top, .leading])
                    
                    HStack {
                        PDVAbilityAreaView(pokemon: pokemon1!).environmentObject(sessionData)
                        PDVAbilityAreaView(pokemon: pokemon2!).environmentObject(sessionData)
                    }
                    .padding(.horizontal)
                    
                    // Characteristics area
                    HStack {
                        Text("Characteristics")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding([.top, .leading])
                    
                    VStack {
                        FOComparisonViewD(stat1: pokemon1!.height, color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.height, color2: typeColorDelegator(type: pokemon2!.type1), name: "Height", imageName: "arrow.up")
                        
                        if !(pokemon1!.weight == -1 || pokemon2!.weight == -1) {
                            FOComparisonViewD(stat1: pokemon1!.weight, color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.weight, color2: typeColorDelegator(type: pokemon2!.type1), name: "Weight", imageName: "scalemass.fill")
                        } else {
                            
                            ZStack {
                                
                                HStack {
                                    Image(systemName: "scalemass.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .opacity(0.6)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.leading)
                                
                                VStack {
                                    Text("Weight")
                                        .foregroundColor(.primary)
                                    HStack {
                                        ZStack {
                                            Rectangle()
                                                .frame(height: 30)
                                                .foregroundColor(.black)
                                                .opacity(0.2)
                                            Text("Data Unavaliable")
                                                .fontWeight(.bold)
                                                .foregroundColor(Color.primary)
                                        }
                                    }
                                }
                            }
                            
                        }
                        
    //                    FOComparisonView(stat1: Int(String(pokemon1.EVYield[String.Index(encodedOffset: 0)]))!, color1: typeColorDelegator(type: pokemon1!.type1), stat2: Int(String(pokemon2.EVYield[String.Index(encodedOffset: 0)]))!, color2: typeColorDelegator(type: pokemon1!.type1), name: "EV Yield", imageName: "star.fill")
                        
                        FOComparisonView(stat1: pokemon1!.catchRate, color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.catchRate, color2: typeColorDelegator(type: pokemon2!.type1), name: "Catch Rate", imageName: "checkmark.seal.fill")
                        
                        FOComparisonView(stat1: pokemon1!.baseFriendship, color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.baseFriendship, color2: typeColorDelegator(type: pokemon2!.type1), name: "Base Friendship", imageName: "heart.fill")
                        
                        FOComparisonView(stat1: pokemon1!.baseEXP, color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.baseEXP, color2: typeColorDelegator(type: pokemon2!.type1), name: "Base Exp.", imageName: "sparkles")
                        
                        FOComparisonView(stat1: pokemon1!.eggCycles, color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.eggCycles, color2: typeColorDelegator(type: pokemon2!.type1), name: "Egg Cycles", imageName: "arrow.clockwise")
                        
                        if !(pokemon1!.maleRate == -1 || pokemon2!.maleRate == -1) {
                            FOComparisonViewD(stat1: pokemon1!.maleRate, color1: typeColorDelegator(type: pokemon1!.type1), stat2: pokemon2!.maleRate, color2: typeColorDelegator(type: pokemon2!.type1), name: "Male Rate", imageName: "stethoscope")
                                .padding(.bottom)
                        } else {
                            ZStack {
                                
                                HStack {
                                    Image(systemName: "stethoscope")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .opacity(0.6)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.leading)
                                
                                VStack {
                                    Text("Male Rate")
                                        .foregroundColor(.primary)
                                    HStack {
                                        ZStack {
                                            Rectangle()
                                                .frame(height: 30)
                                                .foregroundColor(.black)
                                                .opacity(0.2)
                                            Text("Data Unavaliable")
                                                .fontWeight(.bold)
                                                .foregroundColor(Color.primary)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom)
                        }
                    }
                }
                
            }
            
            .navigationBarTitle("Face-Off", displayMode: .inline)
            .navigationBarItems(trailing: buttonText == "Settings" ? AnyView(Button(action: {
                self.showingSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .imageScale(.large)
            }.sheet(isPresented: $showingSettings) { SettingsView(showingSettings: $showingSettings).environmentObject(sessionData) }) : AnyView(Button(action: {
                self.presentationMode.wrappedValue.dismiss() }) {
                Text(buttonText)
            }))

        }
        
    }
    
    func grabBinding(state: Binding<Pokemon?>) -> Binding<Pokemon> {
        let unwrapped = state.wrappedValue
        let answer: Binding<Pokemon> = Binding<Pokemon>(state)!
        answer.wrappedValue = unwrapped!
        return answer
    }
    
    func getBST(pokemon: Pokemon) -> Int {
        var answer = 0
        for eachStat in pokemon.baseStats {
            answer += eachStat
        }
        return answer
    }
    
}

//struct FaceOffView_Previews: PreviewProvider {
//    static var previews: some View {
//        FaceOffView(pokemon1: Pokemon.theTestList()[0], pokemon2: pokemonDataList[5])
//    }
//}

struct PictureGIFView: View {
    
    // Variables
    var pokemon: Pokemon
    
    var body: some View {
        GIFView(gifName: "\(pokemon.name)-gif")
    }
}
