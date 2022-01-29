//
//  TeambuilderMovePicker.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/5/21.
//

import SwiftUI

struct TeambuilderMovePicker: View {
    
    // Team member variables
    var tIndex: Int
    var pIndex: Int
    var index: Int
    
    // Variables
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    @State private var searchText : String = ""
    @State var showingFilters = false
    @State var showingSorting = false
    private var filterCount: Binding<Int> { Binding (
        get: { return runFilters().count },
        set: { _ in }
        )
    }
    @State var showingHelp = false
    @State var showingSettings = false
    
    // Filter variables
    @State var typeFilters: [String] = []
    @State var categoryFilters: [String] = []
    @State var powerFilters: [String] = []
    @State var priorityFilters: [String] = []
    @State var accuracyFilters: [String] = []
    @State var pokemonFilters: [Pokemon] = []
    
    // Sort variables
    @State var sortCondition: String = "Alphabetical"
    @State var sortDirection: Int = 0
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                
                LazyVStack {
                    
                    SearchBar(text: $searchText)
                        .padding(.top)
                    
                    HStack {
                        
                        Button(action: {
                            self.showingFilters.toggle()
                        }) {
                            DexEditButton(imageName: "line.horizontal.3.decrease.circle", name: numFilters() == 0 ? "Filter" : "\(numFilters()) \(numFilters() == 1 ? "Filter" : "Filters") On", backColor: numFilters() >= 1 ? .blue : .secondary, frontColor: numFilters() >= 1 ? .white : .black)
                        }
                        .sheet(isPresented: $showingFilters) {
                            MoveDexFilterView(filterCount: filterCount, typeFilters: $typeFilters, categoryFilters: $categoryFilters, powerFilters: $powerFilters, priorityFilters: $priorityFilters, accuracyFilters: $accuracyFilters, pokemonFilters: $pokemonFilters).environmentObject(sessionData)
                        }
                        
                        Button(action: {
                            self.showingSorting.toggle()
                        }) {
                            DexEditButton(imageName: "arrow.up.arrow.down", name: (sortCondition != "Alphabetical" || sortDirection != 0) ? "Sorting" : "Sort", backColor: (sortCondition != "Alphabetical" || sortDirection != 0) ? .blue : .secondary, frontColor: (sortCondition != "Alphabetical" || sortDirection != 0) ? .white : .black)
                        }
                        .sheet(isPresented: $showingSorting) {
                            MoveDexSortView(sortCondition: $sortCondition, sortDirection: $sortDirection)
                        }
                        
                    }
                    .padding([.top, .leading, .trailing])
                    
                    Button(action: {
                        sessionData.teams[tIndex].members[pIndex]!.moves[index] = nil
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        ZStack {
                            
                            Rectangle()
                                .frame(height: 75)
                                .foregroundColor(.red)
                                .opacity(0.5)
                                .cornerRadius(10)
                                .padding(.horizontal)
                            
                            HStack {
                                
                                Image(systemName: "nosign")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.red)
                                    .padding(.leading, 35)
                                
                                Text("No Move")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                    .padding(.leading)
                                
                                Spacer()
                                
                            }
                            
                        }
                    }
                    .padding(.top)
                    
                    ForEach((filterAndSort().filter {
                        self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                    }).filter({
                        
                        // Filter out moves that have already been selected
                        if sessionData.teams[tIndex].members[pIndex]!.moves[0] != nil && index != 0 && $0.name == sessionData.teams[tIndex].members[pIndex]!.moves[0]!.name {
                            return false
                        }
                        if sessionData.teams[tIndex].members[pIndex]!.moves[1] != nil && index != 1 && $0.name == sessionData.teams[tIndex].members[pIndex]!.moves[1]!.name {
                            return false
                        }
                        if sessionData.teams[tIndex].members[pIndex]!.moves[2] != nil && index != 2 && $0.name == sessionData.teams[tIndex].members[pIndex]!.moves[2]!.name {
                            return false
                        }
                        if sessionData.teams[tIndex].members[pIndex]!.moves[3] != nil && index != 3 && $0.name == sessionData.teams[tIndex].members[pIndex]!.moves[3]!.name {
                            return false
                        }
                        return true
                        
                    }), id: \.name) { move in
                        
                        if canLearn(pokemon: sessionData.teams[tIndex].members[pIndex]!.pokemon, move: move) {
                            NavigationLink(destination: TeambuilderMoveDetailView(tIndex: tIndex, pIndex: pIndex, index: index, prez: presentationMode, move: move).environmentObject(sessionData)) {
                                MoveOption(move: move)
                            }
                        } else {
                            IllegalMoveOption(tIndex: tIndex, pIndex: pIndex, move: move)
                        }
                        
                    }
                    
                }
            }
            
            .navigationBarTitle("Add Move", displayMode: .inline)
            .navigationBarItems(leading: Button(action: { presentationMode.wrappedValue.dismiss() }) { Text("Cancel") })
            
        }
        
    }
    
    // Functions
    func canLearn(pokemon: Pokemon, move: Move) -> Bool {
        
        for eachMethod in move.viaLevel {
            if eachMethod.name == pokemon.name {
                return true
            }
        }
        for eachMethod in move.viaEgg {
            if eachMethod.name == pokemon.name {
                return true
            }
        }
        for eachMethod in move.viaTM {
            if eachMethod.name == pokemon.name {
                return true
            }
        }
        for eachMethod in move.viaTutor {
            if eachMethod.name == pokemon.name {
                return true
            }
        }
        return false
        
    }
    
    func filterAndSort() -> [Move] {
        let answer = runFilters().sorted(by: {
            
            switch sortCondition {
            
            // 1: Alphabetical
            case "Alphabetical":
                if sortDirection == 0 {
                    return $0.name < $1.name
                } else {
                    return $0.name > $1.name
                }
                
            // 2: Power
            case "Power":
                if sortDirection == 0 {
                    return $0.power < $1.power
                } else {
                    return $0.power > $1.power
                }
                
            // 3: Accuracy
            case "Accuracy":
                if $0.accuracy == -1 {
                    if sortDirection == 1 {
                        return true
                    } else {
                        return false
                    }
                } else if $1.accuracy == -1 {
                    if sortDirection == 1 {
                        return false
                    } else {
                        return true
                    }
                }
                
                if sortDirection == 0 {
                    return $0.accuracy < $1.accuracy
                } else {
                    return $0.accuracy > $1.accuracy
                }
                
            // 4: PP
            case "PP":
                if sortDirection == 0 {
                    return $0.PP < $1.PP
                } else {
                    return $0.PP > $1.PP
                }
                
            // 5: Priority
            case "Priority":
                if sortDirection == 0 {
                    return $0.priority < $1.priority
                } else {
                    return $0.priority > $1.priority
                }
                
            // 6: Compatible Pokémon
            case "Compatible Pokémon":
                if sortDirection == 0 {
                    return ($0.viaTM.count + $0.viaEgg.count + $0.viaLevel.count + $0.viaTutor.count) < ($1.viaTM.count + $1.viaEgg.count + $1.viaLevel.count + $1.viaTutor.count)
                } else {
                    return ($0.viaTM.count + $0.viaEgg.count + $0.viaLevel.count + $0.viaTutor.count) > ($1.viaTM.count + $1.viaEgg.count + $1.viaLevel.count + $1.viaTutor.count)
                }
                
            default:
                if sortDirection == 0 {
                    return $0.name < $1.name
                } else {
                    return $0.name > $1.name
                }
            
            }
            
        })
        return answer
    }
    
    func numFilters() -> Int {
        var answer = 0
        
        if powerFilters.count >= 1 { answer += 1 }
        if accuracyFilters.count >= 1 { answer += 1 }
        if typeFilters.count >= 1 { answer += 1 }
        if priorityFilters.count >= 1 { answer += 1 }
        if categoryFilters.count >= 1 { answer += 1 }
        if pokemonFilters.count >= 1 { answer += pokemonFilters.count }
        
        return answer
    }
    
    func runFilters() -> [Move] {
        
        var answer: [Move] = moveDataList
        
        // 1: 100+ Power
        if powerFilters.count >= 1 {
            answer = answer.filter({
                $0.power >= 100
            })
        }
        
        // 2: Always Hits
        if accuracyFilters.count >= 1 {
            answer = answer.filter({
                $0.accuracy == 100 || $0.accuracy == -1
            })
        }
        
        // 3-1: Physical category
        if categoryFilters.contains("Physical") {
            answer = answer.filter({
                $0.category == "Physical"
            })
        }
        
        // 3-2: Special category
        if categoryFilters.contains("Special") {
            answer = answer.filter({
                $0.category == "Special"
            })
        }
        
        // 3-1: Status category
        if categoryFilters.contains("Status") {
            answer = answer.filter({
                $0.category == "Status"
            })
        }
        
        // 4: Type
        if typeFilters.count >= 1 {
            answer = answer.filter({
                $0.type == typeFilters[0]
            })
        }
        
        // 5-1: Positive priority
        if priorityFilters.contains("Positive") {
            answer = answer.filter({
                $0.priority >= 1
            })
        }
        
        // 5-2: Negative priority
        if priorityFilters.contains("Negative") {
            answer = answer.filter({
                $0.priority <= -1
            })
        }
        
        // 6: Compatability
        for eachPokemonFilter in pokemonFilters {
            answer = answer.filter({
                for eachMethod in $0.viaLevel {
                    if eachMethod.name == eachPokemonFilter.name {
                        return true
                    }
                }
                for eachMethod in $0.viaEgg {
                    if eachMethod.name == eachPokemonFilter.name {
                        return true
                    }
                }
                for eachMethod in $0.viaTM {
                    if eachMethod.name == eachPokemonFilter.name {
                        return true
                    }
                }
                for eachMethod in $0.viaTutor {
                    if eachMethod.name == eachPokemonFilter.name {
                        return true
                    }
                }
                return false
            })
        }
        
        return answer
        
    }
    
}

//struct TeambuilderMovePicker_Previews: PreviewProvider {
//    static var previews: some View {
//        TeambuilderMovePicker(member: TeamMember(pokemon: pokemonDataList[0])).environmentObject(SessionData())
//    }
//}

struct IllegalMoveOption: View {
    
    // Variables
    var tIndex: Int
    var pIndex: Int
    var move: Move
    @State var showingAlert = false
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        Button(action: {
            showingAlert.toggle()
        }) {
            MoveOption(move: move)
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Incompatible Move"), message: Text("\(sessionData.teams[tIndex].members[pIndex]!.name) cannot learn \(move.name) in Pokémon Sword and Shield."))
        }
        
    }
    
}
