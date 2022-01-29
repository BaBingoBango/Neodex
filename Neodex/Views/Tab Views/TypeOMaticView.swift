//
//  TypeOMaticView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/18/20.
//

import SwiftUI

struct TypeOMaticView: View {
    
    // Variables
    @State var showingTypeView = false
    @State var normal: Bool = false
    @State var fire: Bool = false
    @State var water: Bool = false
    @State var electric: Bool = false
    @State var grass: Bool = false
    @State var ice: Bool = false
    @State var fighting: Bool = false
    @State var poison: Bool = false
    @State var ground: Bool = false
    @State var flying: Bool = false
    @State var psychic: Bool = false
    @State var bug: Bool = false
    @State var rock: Bool = false
    @State var ghost: Bool = false
    @State var dragon: Bool = false
    @State var dark: Bool = false
    @State var steel: Bool = false
    @State var fairy: Bool = false
    
    @EnvironmentObject var sessionData: SessionData
    @State var showingSettings = false
    @State var showingHelp = false
    
    var body: some View {
        
        VStack {
            
            Spacer()
            
            switch getSelectedTypes().count {
            case 2:
                BigPDTV(types: getSelectedTypes())
                    .padding(.bottom, 50)
            case 1:
                BigPDTV(types: [getSelectedTypes()[0], ""])
                    .padding(.bottom, 50)
            default:
                BigPDTV(types: ["", ""])
                    .padding(.bottom, 50)
                    .hidden()
            }
            
            VStack {
                HStack {
                    
                    Button(action: {
                        if numSelected() != 2 || normal {
                            normal.toggle()
                        }
                    }) {
                        if normal {
                            WidthlessCheckedType(types: ["Normal", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Normal", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || fire {
                            fire.toggle()
                        }
                    }) {
                        if fire {
                            WidthlessCheckedType(types: ["Fire", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Fire", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || water {
                            water.toggle()
                        }
                    }) {
                        if water {
                            WidthlessCheckedType(types: ["Water", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Water", ""])
                        }
                    }
                    
                }
                
                HStack {
                    
                    Button(action: {
                        if numSelected() != 2 || electric {
                            electric.toggle()
                        }
                    }) {
                        if electric {
                            WidthlessCheckedType(types: ["Electric", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Electric", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || grass {
                            grass.toggle()
                        }
                    }) {
                        if grass {
                            WidthlessCheckedType(types: ["Grass", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Grass", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || ice {
                            ice.toggle()
                        }
                    }) {
                        if ice {
                            WidthlessCheckedType(types: ["Ice", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Ice", ""])
                        }
                    }
                    
                }
                
                HStack {
                    
                    Button(action: {
                        if numSelected() != 2 || fighting {
                            fighting.toggle()
                        }
                    }) {
                        if fighting {
                            WidthlessCheckedType(types: ["Fighting", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Fighting", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || poison {
                            poison.toggle()
                        }
                    }) {
                        if poison {
                            WidthlessCheckedType(types: ["Poison", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Poison", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || ground {
                            ground.toggle()
                        }
                    }) {
                        if ground {
                            WidthlessCheckedType(types: ["Ground", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Ground", ""])
                        }
                    }
                    
                }
                
                HStack {
                    
                    Button(action: {
                        if numSelected() != 2 || flying {
                            flying.toggle()
                        }
                    }) {
                        if flying {
                            WidthlessCheckedType(types: ["Flying", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Flying", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || psychic {
                            psychic.toggle()
                        }
                    }) {
                        if psychic {
                            WidthlessCheckedType(types: ["Psychic", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Psychic", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || bug {
                            bug.toggle()
                        }
                    }) {
                        if bug {
                            WidthlessCheckedType(types: ["Bug", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Bug", ""])
                        }
                    }
                    
                }
                
                HStack {
                    
                    Button(action: {
                        if numSelected() != 2 || rock {
                            rock.toggle()
                        }
                    }) {
                        if rock {
                            WidthlessCheckedType(types: ["Rock", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Rock", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || ghost {
                            ghost.toggle()
                        }
                    }) {
                        if ghost {
                            WidthlessCheckedType(types: ["Ghost", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Ghost", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || dragon {
                            dragon.toggle()
                        }
                    }) {
                        if dragon {
                            WidthlessCheckedType(types: ["Dragon", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Dragon", ""])
                        }
                    }
                    
                }
                
                HStack {
                    
                    Button(action: {
                        if numSelected() != 2 || dark {
                            dark.toggle()
                        }
                    }) {
                        if dark {
                            WidthlessCheckedType(types: ["Dark", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Dark", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || steel {
                            steel.toggle()
                        }
                    }) {
                        if steel {
                            WidthlessCheckedType(types: ["Steel", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Steel", ""])
                        }
                    }
                    Button(action: {
                        if numSelected() != 2 || fairy {
                            fairy.toggle()
                        }
                    }) {
                        if fairy {
                            WidthlessCheckedType(types: ["Fairy", ""])
                        } else {
                            WidthlessPokemonDetailTypeView(types: ["Fairy", ""])
                        }
                    }
                    
                }
                
            }
            
            Spacer()
            
            Button(action: {
                self.showingTypeView.toggle()
            }) {
                Text("Go!")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.white)
                    .padding()
                    .padding(.horizontal, 80.0)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0)
                    .background(numSelected() == 0 ? Color.gray: Color.blue)
                    .cornerRadius(10)
//                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .sheet(isPresented: self.$showingTypeView) {
                if numSelected() == 1 {
                    TypeDetailView(type: Type.typeLookup(name: getSelectedTypes()[0])!)
                } else if numSelected() == 2 {
                    TypeDetailView(type: Type.typeLookup(name: getSelectedTypes()[0])!, type2: Type.typeLookup(name: getSelectedTypes()[1]))
                }
            }
            .disabled(numSelected() == 0)
            
        }
        .padding(.horizontal)
        
        .navigationBarTitle("Type-O-Matic", displayMode: .inline)
        .navigationBarItems(trailing: TypeOMaticTrailingNavButtons(showingHelp: $showingHelp, showingSettings: $showingSettings).environmentObject(sessionData))
        
    }
    
    // Functions
    func numSelected() -> Int {
        var answer = 0
        if normal {
            answer += 1
        }
        if fire {
            answer += 1
        }
        if water {
            answer += 1
        }
        if electric {
            answer += 1
        }
        if grass {
            answer += 1
        }
        if ice {
            answer += 1
        }
        if fighting {
            answer += 1
        }
        if poison {
            answer += 1
        }
        if ground {
            answer += 1
        }
        if flying {
            answer += 1
        }
        if psychic {
            answer += 1
        }
        if bug {
            answer += 1
        }
        if rock {
            answer += 1
        }
        if ghost {
            answer += 1
        }
        if dragon {
            answer += 1
        }
        if dark {
            answer += 1
        }
        if steel {
            answer += 1
        }
        if fairy {
            answer += 1
        }
        return answer
    }
    
    func getSelectedTypes() -> [String] {
        var answer: [String] = []
        if normal {
            answer.append("Normal")
        }
        if fire {
            answer.append("Fire")
        }
        if water {
            answer.append("Water")
        }
        if electric {
            answer.append("Electric")
        }
        if grass {
            answer.append("Grass")
        }
        if ice {
            answer.append("Ice")
        }
        if fighting {
            answer.append("Fighting")
        }
        if poison {
            answer.append("Poison")
        }
        if ground {
            answer.append("Ground")
        }
        if flying {
            answer.append("Flying")
        }
        if psychic {
            answer.append("Psychic")
        }
        if bug {
            answer.append("Bug")
        }
        if rock {
            answer.append("Rock")
        }
        if ghost {
            answer.append("Ghost")
        }
        if dragon {
            answer.append("Dragon")
        }
        if dark {
            answer.append("Dark")
        }
        if steel {
            answer.append("Steel")
        }
        if fairy {
            answer.append("Fairy")
        }
        return answer
    }
    
}

struct TypeOMaticTrailingNavButtons: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @Binding var showingHelp: Bool
    @Binding var showingSettings: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                showingHelp.toggle()
            }) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.blue)
                    .padding(.trailing)
                    .imageScale(.large)
            }
            .sheet(isPresented: $showingHelp) {
                NavigationView {
                    PokemonHelpGuide(text: "Done")
                }
            }
            
            Button(action: {
                showingSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .foregroundColor(.blue)
                    .imageScale(.large)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(showingSettings: $showingSettings).environmentObject(sessionData)
            }
        }
    }
}

struct TypeOMaticView_Previews: PreviewProvider {
    static var previews: some View {
        TypeOMaticView().environmentObject(SessionData())
    }
}

struct CheckedType: View {
    var types: [String]
    var body: some View {
        ZStack {
            PokemonDetailTypeView(types: types)
                .grayscale(0.999)
            Image(systemName: "checkmark.circle.fill")
                .renderingMode(.original)
                .font(.title)
        }
    }
}

struct WidthlessCheckedType: View {
    var types: [String]
    var body: some View {
        ZStack {
            WidthlessPokemonDetailTypeView(types: types)
                .grayscale(0.999)
            Image(systemName: "checkmark.circle.fill")
                .renderingMode(.original)
                .font(.title)
        }
    }
}
