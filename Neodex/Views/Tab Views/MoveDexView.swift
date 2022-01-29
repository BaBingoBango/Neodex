//
//  MoveDexView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/30/20.
//

import SwiftUI

struct MoveDexView: View {
    
    // Variables
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
        
        ScrollView {
            
            VStack {
                
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
                
                LazyVStack {
                    ForEach(filterAndSort().filter {
                        self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
                    }, id: \.name) { move in
                        NavigationLink(destination: MoveDetailView(move: move).environmentObject(sessionData)) {
                            MoveOption(move: move)
                        }
                    }
                }
                
            }
        }
        
        .navigationBarTitle("Move Dex")
        .navigationBarItems(trailing: MoveDexTrailingNavButtons(showingHelp: $showingHelp, showingSettings: $showingSettings).environmentObject(sessionData))
        
    }
    
    // Functions
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

struct MoveDexView_Previews: PreviewProvider {
    static var previews: some View {
        MoveDexView().environmentObject(SessionData())
    }
}

struct MoveDexTrailingNavButtons: View {
    
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
                    Text("Future home of the Move help guide!")
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

struct MoveOption: View {
    
    // Variables
    var move: Move
    @Environment(\.colorScheme) var colorScheme
    var removeTopPadding = false
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .cornerRadius(10)
                .frame(height: 80)
                .shadow(color: .secondary, radius: 15)
            
            HStack {
                
                RectangleIndicatorStack(color1: typeColorDelegator(type: move.type), text1: move.type, color2: categoryColorDelegator(category: move.category), text2: move.category, roundedLeftSide: true, height: 80.0)
                
                VStack(alignment: .leading) {
                    
                    Text(move.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                    
                }
                .padding(.leading, 5)
                
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
        .padding(removeTopPadding ? [.leading, .trailing] : [.top, .leading, .trailing])
        .padding(.bottom, removeTopPadding ? 5 : 0)
    }

}

struct DexEditButton: View {
    
    // Variables
    var imageName: String
    var name: String
    var backColor: Color
    var frontColor: Color
    
    var body: some View {
        
        ZStack {
            Rectangle()
                .frame(height: 50)
                .foregroundColor(backColor)
                .cornerRadius(15)
            HStack {
                Image(systemName: imageName)
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundColor(frontColor)
                Text(name)
                    .fontWeight(.bold)
                    .foregroundColor(frontColor)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.leading)
        }
        
    }
}
