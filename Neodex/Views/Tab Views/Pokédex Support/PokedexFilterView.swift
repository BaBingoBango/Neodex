//
//  PokedexFilterView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/29/20.
//

import SwiftUI

struct PokedexFilterView: View {
    
    // Variables
    @State var showingAbilties = false
    @Environment(\.presentationMode) var presentationMode
    @Binding var filterCount: Int
    @Binding var filtersOn: Bool
    @State var showingMoves = false
    
    // Filter variables
    @Binding var typeFilters: [String]
    @Binding var abilityFilters: [String]
    @Binding var evolutionFilters: [String]
    @Binding var eggGroupFilters: [String]
    @Binding var growthRateFilters: [String]
    @Binding var canBeCaughtFilters: [String]
    @Binding var moveFilters: [String]
    @Binding var megaEvolutionFilters: [String]
    @Binding var alolanFormFilters: [String]
    @Binding var galarianFormFilters: [String]
    @Binding var EVYieldTypeFilters: [String]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    
                    VStack {
                        
                        // MARK: No Category
                        HStack {
                            
                            Button(action: {
                                if canBeCaughtFilters.count == 0 {
                                    setFilter(category: "Found in Wild", name: "Found in Wild")
                                } else {
                                    canBeCaughtFilters.removeAll()
                                }
                            }) {
                                FilterOptionView(imageName: "checkmark.seal.fill", filterName: "Found in Wild", color: canBeCaughtFilters.count == 0 ? .secondary : .blue)
                            }
                            
                            Button(action: {
                                if megaEvolutionFilters.count == 0 {
                                    setFilter(category: "Mega Evolved", name: "Mega Evolved")
                                } else {
                                    megaEvolutionFilters.removeAll()
                                }
                            }) {
                                FilterOptionView(imageName: "bolt.fill", filterName: "Mega Evolved", color: megaEvolutionFilters.count == 0 ? .secondary : .blue)
                            }
                            
                        }
                        .padding([.top, .leading, .trailing])
                        
                        HStack {
                            
                            Button(action: {
                                if alolanFormFilters.count == 0 {
                                    setFilter(category: "Alolan Form", name: "Alolan Form")
                                } else {
                                    alolanFormFilters.removeAll()
                                }
                            }) {
                                FilterOptionView(imageName: "sun.max.fill", filterName: "Alolan Form", color: alolanFormFilters.count == 0 ? .secondary : .blue)
                            }
                            
                            Button(action: {
                                if galarianFormFilters.count == 0 {
                                    setFilter(category: "Galarian Form", name: "Galarian Form")
                                } else {
                                    galarianFormFilters.removeAll()
                                }
                            }) {
                                FilterOptionView(imageName: "smoke.fill", filterName: "Galarian Form", color: galarianFormFilters.count == 0 ? .secondary : .blue)
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        // MARK: Type
                        HStack {
                            Text("Type")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding([.top, .leading])
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                
                                VStack {
                                    Button(action: {
                                        if typeFilters.contains("Normal") {
                                            typeFilters = typeFilters.filter({ $0 != "Normal" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Normal")
                                        }
                                    }) {
                                        if typeFilters.contains("Normal") {
                                            CheckedType(types: ["Normal", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Normal", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Fighting") {
                                            typeFilters = typeFilters.filter({ $0 != "Fighting" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Fighting")
                                        }
                                    }) {
                                        if typeFilters.contains("Fighting") {
                                            CheckedType(types: ["Fighting", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Fighting", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Rock") {
                                            typeFilters = typeFilters.filter({ $0 != "Rock" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Rock")
                                        }
                                    }) {
                                        if typeFilters.contains("Rock") {
                                            CheckedType(types: ["Rock", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Rock", ""])
                                        }
                                    }
                                }
                                VStack {
                                    Button(action: {
                                        if typeFilters.contains("Fire") {
                                            typeFilters = typeFilters.filter({ $0 != "Fire" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Fire")
                                        }
                                    }) {
                                        if typeFilters.contains("Fire") {
                                            CheckedType(types: ["Fire", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Fire", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Poison") {
                                            typeFilters = typeFilters.filter({ $0 != "Poison" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Poison")
                                        }
                                    }) {
                                        if typeFilters.contains("Poison") {
                                            CheckedType(types: ["Poison", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Poison", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Ghost") {
                                            typeFilters = typeFilters.filter({ $0 != "Ghost" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Ghost")
                                        }
                                    }) {
                                        if typeFilters.contains("Ghost") {
                                            CheckedType(types: ["Ghost", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Ghost", ""])
                                        }
                                    }
                                }
                                VStack {
                                    Button(action: {
                                        if typeFilters.contains("Water") {
                                            typeFilters = typeFilters.filter({ $0 != "Water" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Water")
                                        }
                                    }) {
                                        if typeFilters.contains("Water") {
                                            CheckedType(types: ["Water", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Water", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Ground") {
                                            typeFilters = typeFilters.filter({ $0 != "Ground" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Ground")
                                        }
                                    }) {
                                        if typeFilters.contains("Ground") {
                                            CheckedType(types: ["Ground", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Ground", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Dragon") {
                                            typeFilters = typeFilters.filter({ $0 != "Dragon" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Dragon")
                                        }
                                    }) {
                                        if typeFilters.contains("Dragon") {
                                            CheckedType(types: ["Dragon", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Dragon", ""])
                                        }
                                    }
                                }
                                VStack {
                                    Button(action: {
                                        if typeFilters.contains("Electric") {
                                            typeFilters = typeFilters.filter({ $0 != "Electric" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Electric")
                                        }
                                    }) {
                                        if typeFilters.contains("Electric") {
                                            CheckedType(types: ["Electric", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Electric", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Flying") {
                                            typeFilters = typeFilters.filter({ $0 != "Flying" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Flying")
                                        }
                                    }) {
                                        if typeFilters.contains("Flying") {
                                            CheckedType(types: ["Flying", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Flying", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Dark") {
                                            typeFilters = typeFilters.filter({ $0 != "Dark" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Dark")
                                        }
                                    }) {
                                        if typeFilters.contains("Dark") {
                                            CheckedType(types: ["Dark", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Dark", ""])
                                        }
                                    }
                                }
                                VStack {
                                    Button(action: {
                                        if typeFilters.contains("Grass") {
                                            typeFilters = typeFilters.filter({ $0 != "Grass" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Grass")
                                        }
                                    }) {
                                        if typeFilters.contains("Grass") {
                                            CheckedType(types: ["Grass", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Grass", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Psychic") {
                                            typeFilters = typeFilters.filter({ $0 != "Psychic" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Psychic")
                                        }
                                    }) {
                                        if typeFilters.contains("Psychic") {
                                            CheckedType(types: ["Psychic", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Psychic", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Steel") {
                                            typeFilters = typeFilters.filter({ $0 != "Steel" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Steel")
                                        }
                                    }) {
                                        if typeFilters.contains("Steel") {
                                            CheckedType(types: ["Steel", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Steel", ""])
                                        }
                                    }
                                }
                                VStack {
                                    Button(action: {
                                        if typeFilters.contains("Ice") {
                                            typeFilters = typeFilters.filter({ $0 != "Ice" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Ice")
                                        }
                                    }) {
                                        if typeFilters.contains("Ice") {
                                            CheckedType(types: ["Ice", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Ice", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Bug") {
                                            typeFilters = typeFilters.filter({ $0 != "Bug" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Bug")
                                        }
                                    }) {
                                        if typeFilters.contains("Bug") {
                                            CheckedType(types: ["Bug", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Bug", ""])
                                        }
                                    }
                                    Button(action: {
                                        if typeFilters.contains("Fairy") {
                                            typeFilters = typeFilters.filter({ $0 != "Fairy" })
                                        } else if typeFilters.count != 2 {
                                            typeFilters.append("Fairy")
                                        }
                                    }) {
                                        if typeFilters.contains("Fairy") {
                                            CheckedType(types: ["Fairy", ""])
                                        } else {
                                            PokemonDetailTypeView(types: ["Fairy", ""])
                                        }
                                    }
                                }
                                
                            }
                            .padding(.horizontal)
                            
                        }
                        
                        // MARK: Evolutions
                        HStack {
                            Text("Evolutions")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding([.top, .leading])
                        
                        HStack {
                            
                            Button(action: {
                                if evolutionFilters.contains("0") {
                                    evolutionFilters = evolutionFilters.filter({ $0 != "0" })
                                } else if evolutionFilters.count != 1 {
                                    evolutionFilters.append("0")
                                } else if evolutionFilters.count == 1 {
                                    evolutionFilters.removeAll()
                                    evolutionFilters.append("0")
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .frame(width: 70, height: 70)
                                        .foregroundColor(evolutionFilters.contains("0") ? .blue : .secondary)
                                    Text("0")
                                        .fontWeight(.bold)
                                        .font(.system(size: 35))
                                        .foregroundColor(.white)
                                }
                            }
                            Button(action: {
                                if evolutionFilters.contains("1") {
                                    evolutionFilters = evolutionFilters.filter({ $0 != "1" })
                                } else if evolutionFilters.count != 1 {
                                    evolutionFilters.append("1")
                                } else if evolutionFilters.count == 1 {
                                    evolutionFilters.removeAll()
                                    evolutionFilters.append("1")
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .frame(width: 70, height: 70)
                                        .foregroundColor(evolutionFilters.contains("1") ? .blue : .secondary)
                                    Text("1")
                                        .fontWeight(.bold)
                                        .font(.system(size: 35))
                                        .foregroundColor(.white)
                                }
                            }
                            Button(action: {
                                if evolutionFilters.contains("2") {
                                    evolutionFilters = evolutionFilters.filter({ $0 != "2" })
                                } else if evolutionFilters.count != 1 {
                                    evolutionFilters.append("2")
                                } else if evolutionFilters.count == 1 {
                                    evolutionFilters.removeAll()
                                    evolutionFilters.append("2")
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .frame(width: 70, height: 70)
                                        .foregroundColor(evolutionFilters.contains("2") ? .blue : .secondary)
                                    Text("2")
                                        .fontWeight(.bold)
                                        .font(.system(size: 35))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                        .padding(.leading)
                        
                    }
                    
                    VStack {
                        
                        // MARK: Moves
                        HStack {
                            Text("Moves")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding([.top, .leading])
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                
                                ForEach(moveFilters, id: \.self) { move in
                                    
                                    Button(action: {
                                        
                                        // Remove the tapped move from the move filters list
                                        moveFilters = moveFilters.filter({
                                            $0 != move
                                        })
                                        
                                    }) {
                                        ZStack {
                                            FilterOptionView(imageName: "burst.fill", filterName: move, color: .blue, showX: true)
                                            HStack {
                                                Spacer()
//                                                Image(systemName: "xmark.circle.fill")
//                                                    .resizable()
//                                                    .frame(width: 25, height: 25)
//                                                    .foregroundColor(.white)
                                            }
                                            .padding(.trailing)
                                        }
                                    }
                                    
                                }
                                
                                Button(action: {
                                    self.showingMoves.toggle()
                                }) {
                                    HStack {
                                        FilterOptionView(imageName: "plus", filterName: "Add Move Filter     ", color: .secondary)
                                        FilterOptionView(imageName: "", filterName: "", color: .secondary)
                                            .hidden()
                                    }
                                }
                                .sheet(isPresented: $showingMoves) {
                                    MoveFilterPicker(moveFilters: $moveFilters)
                                }
                                
                                if moveFilters.count == 0 {
                                    FilterOptionView(imageName: "", filterName: "", color: .secondary)
                                        .hidden()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // MARK: Ability
                        HStack {
                            Text("Ability")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding([.top, .leading])
                        
                        if abilityFilters.count == 0 {
                            Button(action: {
                                self.showingAbilties.toggle()
                            }) {
                                HStack {
                                    FilterOptionView(imageName: "plus", filterName: "Add Ability Filter", color: .secondary)
                                        .padding(.trailing, 100)
//                                    FilterOptionView(imageName: "", filterName: "", color: .secondary)
//                                        .hidden()
                                }
                            }
                            .sheet(isPresented: $showingAbilties) {
                                AbilityFilterPicker(abilityFilters: $abilityFilters)
                            }
                            .padding(.leading)
                        } else {
                            
                            HStack {
                                ForEach(abilityFilters, id: \.self) { ability in
                                    Button(action: {
                                        abilityFilters = []
                                    }) {
                                        ZStack {
                                            FilterOptionView(imageName: "sparkles", filterName: ability, color: .blue)
                                            HStack {
                                                Spacer()
                                                Image(systemName: "xmark.circle.fill")
                                                    .resizable()
                                                    .frame(width: 25, height: 25)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.trailing)
                                        }
                                    }
                                }
                                FilterOptionView(imageName: "", filterName: "", color: .secondary)
                                    .hidden()
                            }
                            .padding(.leading)
                            
                        }
                        
                        // MARK: EV Yield Type
                        HStack {
                            Text("EV Yield Type")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding([.top, .leading])
                        
                        HStack {
                            
                            VStack {
                                Button(action: {
                                    if EVYieldTypeFilters.contains("HP") {
                                        EVYieldTypeFilters = EVYieldTypeFilters.filter({ $0 != "HP" })
                                    } else {
                                        EVYieldTypeFilters.append("HP")
                                    }
                                }) {
                                    FilterOptionView(imageName: "heart.circle.fill", filterName: "HP", color: EVYieldTypeFilters.contains("HP") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if EVYieldTypeFilters.contains("Sp. Atk") {
                                        EVYieldTypeFilters = EVYieldTypeFilters.filter({ $0 != "Sp. Atk" })
                                    } else {
                                        EVYieldTypeFilters.append("Sp. Atk")
                                    }
                                }) {
                                    FilterOptionView(imageName: "bolt.circle.fill", filterName: "Special Attack", color: EVYieldTypeFilters.contains("Sp. Atk") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if EVYieldTypeFilters.contains("Sp. Def") {
                                        EVYieldTypeFilters = EVYieldTypeFilters.filter({ $0 != "Sp. Def" })
                                    } else {
                                        EVYieldTypeFilters.append("Sp. Def")
                                    }
                                }) {
                                    FilterOptionView(imageName: "shield.checkerboard", filterName: "Special Defense", color: EVYieldTypeFilters.contains("Sp. Def") ? .blue : .secondary)
                                }
                            }
                            VStack {
                                Button(action: {
                                    if EVYieldTypeFilters.contains("Attack") {
                                        EVYieldTypeFilters = EVYieldTypeFilters.filter({ $0 != "Attack" })
                                    } else {
                                        EVYieldTypeFilters.append("Attack")
                                    }
                                }) {
                                    FilterOptionView(imageName: "burst.fill", filterName: "Attack", color: EVYieldTypeFilters.contains("Attack") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if EVYieldTypeFilters.contains("Defense") {
                                        EVYieldTypeFilters = EVYieldTypeFilters.filter({ $0 != "Defense" })
                                    } else {
                                        EVYieldTypeFilters.append("Defense")
                                    }
                                }) {
                                    FilterOptionView(imageName: "shield.fill", filterName: "Defense", color: EVYieldTypeFilters.contains("Defense") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if EVYieldTypeFilters.contains("Speed") {
                                        EVYieldTypeFilters = EVYieldTypeFilters.filter({ $0 != "Speed" })
                                    } else {
                                        EVYieldTypeFilters.append("Speed")
                                    }
                                }) {
                                    FilterOptionView(imageName: "hare.fill", filterName: "Speed", color: EVYieldTypeFilters.contains("Speed") ? .blue : .secondary)
                                }
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        // MARK: Growth Rate
                        HStack {
                            Text("Growth Rate")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding([.top, .leading])
                        
                        HStack {
                            
                            VStack {
                                Button(action: {
                                    if growthRateFilters.contains("Slow") {
                                        growthRateFilters = growthRateFilters.filter({ $0 != "Slow" })
                                    } else if growthRateFilters.count == 0 {
                                        growthRateFilters.append("Slow")
                                    } else if growthRateFilters.count == 1 {
                                        growthRateFilters.removeAll()
                                        growthRateFilters.append("Slow")
                                    }
                                }) {
                                    FilterOptionView(imageName: "chevron.left.2", filterName: "Slow", color: growthRateFilters.contains("Slow") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if growthRateFilters.contains("Fast") {
                                        growthRateFilters = growthRateFilters.filter({ $0 != "Fast" })
                                    } else if growthRateFilters.count == 0 {
                                        growthRateFilters.append("Fast")
                                    } else if growthRateFilters.count == 1 {
                                        growthRateFilters.removeAll()
                                        growthRateFilters.append("Fast")
                                    }
                                }) {
                                    FilterOptionView(imageName: "chevron.right.2", filterName: "Fast", color: growthRateFilters.contains("Fast") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if growthRateFilters.contains("Erratic") {
                                        growthRateFilters = growthRateFilters.filter({ $0 != "Erratic" })
                                    } else if growthRateFilters.count == 0 {
                                        growthRateFilters.append("Erratic")
                                    } else if growthRateFilters.count == 1 {
                                        growthRateFilters.removeAll()
                                        growthRateFilters.append("Erratic")
                                    }
                                }) {
                                    FilterOptionView(imageName: "scribble.variable", filterName: "Erratic", color: growthRateFilters.contains("Erratic") ? .blue : .secondary)
                                }
                            }
                            VStack {
                                Button(action: {
                                    if growthRateFilters.contains("Medium Slow") {
                                        growthRateFilters = growthRateFilters.filter({ $0 != "Medium Slow" })
                                    } else if growthRateFilters.count == 0 {
                                        growthRateFilters.append("Medium Slow")
                                    } else if growthRateFilters.count == 1 {
                                        growthRateFilters.removeAll()
                                        growthRateFilters.append("Medium Slow")
                                    }
                                }) {
                                    FilterOptionView(imageName: "chevron.left", filterName: "Medium Slow", color: growthRateFilters.contains("Medium Slow") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if growthRateFilters.contains("Medium Fast") {
                                        growthRateFilters = growthRateFilters.filter({ $0 != "Medium Fast" })
                                    } else if growthRateFilters.count == 0 {
                                        growthRateFilters.append("Medium Fast")
                                    } else if growthRateFilters.count == 1 {
                                        growthRateFilters.removeAll()
                                        growthRateFilters.append("Medium Fast")
                                    }
                                }) {
                                    FilterOptionView(imageName: "chevron.right", filterName: "Medium Fast", color: growthRateFilters.contains("Medium Fast") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if growthRateFilters.contains("Fluctuating") {
                                        growthRateFilters = growthRateFilters.filter({ $0 != "Fluctuating" })
                                    } else if growthRateFilters.count == 0 {
                                        growthRateFilters.append("Fluctuating")
                                    } else if growthRateFilters.count == 1 {
                                        growthRateFilters.removeAll()
                                        growthRateFilters.append("Fluctuating")
                                    }
                                }) {
                                    FilterOptionView(imageName: "waveform.path.ecg", filterName: "Fluctuating", color: growthRateFilters.contains("Fluctuating") ? .blue : .secondary)
                                }
                                
                            }
                            
                        }
                        .padding(.horizontal)
                    }
                    
                    // MARK: Egg Groups
                    HStack {
                        Text("Egg Groups")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding([.top, .leading])
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            
                            VStack {
                                Button(action: {
                                    if eggGroupFilters.contains("Monster") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Monster" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Monster")
                                    }
                                }) {
                                    FilterOptionView(imageName: "ant.fill", filterName: "Monster", color: eggGroupFilters.contains("Monster") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Field") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Field" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Field")
                                    }
                                }) {
                                    FilterOptionView(imageName: "wind", filterName: "Field", color: eggGroupFilters.contains("Field") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Mineral") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Mineral" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Mineral")
                                    }
                                }) {
                                    FilterOptionView(imageName: "cube.fill", filterName: "Mineral", color: eggGroupFilters.contains("Mineral") ? .blue : .secondary)
                                }
                            }
                            .frame(width: UIScreen.screenWidth / 2.25)
                            VStack {
                                Button(action: {
                                    if eggGroupFilters.contains("Water 1") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Water 1" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Water 1")
                                    }
                                }) {
                                    FilterOptionView(imageName: "drop.fill", filterName: "Water 1", color: eggGroupFilters.contains("Water 1") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Fairy") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Fairy" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Fairy")
                                    }
                                }) {
                                    FilterOptionView(imageName: "sparkles", filterName: "Fairy", color: eggGroupFilters.contains("Fairy") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Amorphous") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Amorphous" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Amorphous")
                                    }
                                }) {
                                    FilterOptionView(imageName: "seal.fill", filterName: "Amorphous", color: eggGroupFilters.contains("Amorphous") ? .blue : .secondary)
                                    
                                }
                            }
                            .frame(width: UIScreen.screenWidth / 2.25)
                            VStack {
                                Button(action: {
                                    if eggGroupFilters.contains("Water 2") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Water 2" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Water 2")
                                    }
                                }) {
                                    FilterOptionView(imageName: "drop.fill", filterName: "Water 2", color: eggGroupFilters.contains("Water 2") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Grass") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Grass" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Grass")
                                    }
                                }) {
                                    FilterOptionView(imageName: "leaf.fill", filterName: "Grass", color: eggGroupFilters.contains("Grass") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Ditto") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Ditto" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Ditto")
                                    }
                                }) {
                                    FilterOptionView(imageName: "face.smiling.fill", filterName: "Ditto", color: eggGroupFilters.contains("Ditto") ? .blue : .secondary)
                                }
                            }
                            .frame(width: UIScreen.screenWidth / 2.25)
                            VStack {
                                Button(action: {
                                    if eggGroupFilters.contains("Water 3") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Water 3" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Water 3")
                                    }
                                }) {
                                    FilterOptionView(imageName: "drop.fill", filterName: "Water 3", color: eggGroupFilters.contains("Water 3") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Human-Like") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Human-Like" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Human-Like")
                                    }
                                }) {
                                    FilterOptionView(imageName: "figure.stand", filterName: "Human-Like", color: eggGroupFilters.contains("Human-Like") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Dragon") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Dragon" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Dragon")
                                    }
                                }) {
                                    FilterOptionView(imageName: "bolt.horizontal.fill", filterName: "Dragon", color: eggGroupFilters.contains("Dragon") ? .blue : .secondary)
                                }
                            }
                            .frame(width: UIScreen.screenWidth / 2.25)
                            VStack {
                                Button(action: {
                                    if eggGroupFilters.contains("Flying") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Flying" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Flying")
                                    }
                                }) {
                                    FilterOptionView(imageName: "cloud.fill", filterName: "Flying", color: eggGroupFilters.contains("Flying") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Bug") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Bug" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Bug")
                                    }
                                }) {
                                    FilterOptionView(imageName: "ladybug.fill", filterName: "Bug", color: eggGroupFilters.contains("Bug") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if eggGroupFilters.contains("Undiscovered") {
                                        eggGroupFilters = eggGroupFilters.filter({ $0 != "Undiscovered" })
                                    } else if eggGroupFilters.count != 2 {
                                        eggGroupFilters.append("Undiscovered")
                                    }
                                }) {
                                    FilterOptionView(imageName: "questionmark.circle.fill", filterName: "Undiscovered", color: eggGroupFilters.contains("Undiscovered") ? .blue : .secondary)
                                }
                            }
                            .frame(width: UIScreen.screenWidth / 2.25)
                            
                        }
                        .padding(.horizontal)
                    }
                    
                }
                .padding(.bottom)
            }
            
            .navigationBarTitle(filterCount != 1 ? "\(filterCount) Results" : "\(filterCount) Result", displayMode: .inline)
            .navigationBarItems(leading: Button(action: { clearAllFilters() }) { Text("Clear All").fontWeight(.regular) }.disabled(!filtersOn), trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Done") })
        }

    }
    
    // Functions
    func setFilter(category: String, name: String) {
        switch category {
        case "Found in Wild":
            canBeCaughtFilters.append("Found in Wild")
        case "Mega Evolved":
            megaEvolutionFilters.append("Mega Evolved")
        case "Alolan Form":
            alolanFormFilters.append("Alolan Form")
        case "Galarian Form":
            galarianFormFilters.append("Galarian Form")
        case "Type":
            typeFilters.append(name)
        case "Evolutions":
            evolutionFilters.append(name)
        case "Moves":
            moveFilters.append(name)
        case "Ability":
            abilityFilters.append(name)
        case "EV Yield Type":
            EVYieldTypeFilters.append(name)
        case "Growth Rate":
            growthRateFilters.append(name)
        case "Egg Groups":
            eggGroupFilters.append(name)
        default:
            print("setFilter() was called, but no filter was added.")
        }
    }
    
    func clearAllFilters() {
        typeFilters.removeAll()
        abilityFilters.removeAll()
        evolutionFilters.removeAll()
        eggGroupFilters.removeAll()
        growthRateFilters.removeAll()
        canBeCaughtFilters.removeAll()
        moveFilters.removeAll()
        megaEvolutionFilters.removeAll()
        alolanFormFilters.removeAll()
        galarianFormFilters.removeAll()
        EVYieldTypeFilters.removeAll()
    }
    
}

struct PokedexFilterView_Previews: PreviewProvider {
    static var previews: some View {
        PokedexFilterView(filterCount: .constant(0), filtersOn: .constant(false), typeFilters: .constant([]), abilityFilters: .constant([]), evolutionFilters: .constant([]), eggGroupFilters: .constant([]), growthRateFilters: .constant([]), canBeCaughtFilters: .constant([]), moveFilters: .constant([]), megaEvolutionFilters: .constant([]), alolanFormFilters: .constant([]), galarianFormFilters: .constant([]), EVYieldTypeFilters: .constant([])).environmentObject(SessionData())
    }
}

struct FilterOptionView: View {
    
    // Variables
    var imageName: String
    var filterName: String
    var color: Color
    var showX: Bool = false
    
    var body: some View {
        ZStack {
            Rectangle()
                .frame(height: 50)
                .foregroundColor(color)
                .cornerRadius(30)
            HStack {
                Image(systemName: imageName)
                    .padding(.leading)
                    .imageScale(.large)
                    .foregroundColor(.white)
                Text(filterName)
                    .font(.system(size: 15))
                    .fontWeight(.bold)
                    .foregroundColor(Color.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(filterName == "Fluctuating" || filterName == "Z-Crystals" ? 1 : 2)
                    .minimumScaleFactor(0.5)
                Spacer()
                if showX {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundColor(.white)
                }
            }
            .padding(.trailing)
        }
    }
}
