//
//  TeamMemberEditor.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/2/21.
//

import SwiftUI
import Combine

struct TeamMemberEditor: View {
    
    // Team member variable
    var tIndex: Int
    var pIndex: Int
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @State var showingPokemonDetail = false
    @State var showingGenderAlert = false
    @State var test = ""
    @State var showingAbilityPicker = false
    @State var showingItemPicker = false
    @State var showingMovePicker = false
    
    var body: some View {
        
        if sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members.count >= pIndex + 1 && sessionData.teams[tIndex].members[pIndex] != nil {
            VStack {
                
                HStack(alignment: .top) {
                    
                    // MARK: GIF view
                    
                    Button(action: {
                        showingPokemonDetail.toggle()
                    }) {
                        ZStack {
                            GIFView(gifName: "\(sessionData.teams[tIndex].members[pIndex]!.pokemon.name)-gif")
                                .frame(width: 100, height: 100)
                            Image(systemName: "info.circle")
                                .imageScale(.large)
                                .offset(x: 50, y: -50)
                        }
                        .padding(.leading)
                    }
                    .sheet(isPresented: $showingPokemonDetail) {
                        NavigationView { PokemonDetailView(pokemon: sessionData.teams[tIndex].members[pIndex]!.pokemon, buttonText: "Done") }
                    }
                    
                    VStack(alignment: .leading, spacing: 7) {
                        
                        HStack {
                            
                            // MARK: Nickname editor
                            
                            NicknameEditor(tIndex: tIndex, pIndex: pIndex, nickname: sessionData.teams[tIndex].members[pIndex]!.nickname)
                            
                        }
                        
                        HStack {
                            
                            // MARK: Level indicator
                            
                            ZStack {
                                
                                Rectangle()
                                    .frame(width: 80, height: 35)
                                    .foregroundColor(.secondary)
                                    .cornerRadius(5)
                                    .opacity(0.5)
                                
                                HStack(spacing: 0) {
                                    
                                    Text(" Lv.")
                                        .font(UIDevice.modelName.contains("iPod") ? .system(size: 15) : .title3)
                                        .fontWeight(.bold)
                                    
                                    LevelTextField(tIndex: tIndex, pIndex: pIndex, enteredLevel: String(sessionData.teams[tIndex].members[pIndex]!.level))
                                        .frame(width: 50, height: 35)
                                    
                                }
                                
                            }
                            .padding(.leading, 5)
                            
                            // MARK: Shiny indicator
                            
                            Button(action: {
                                sessionData.teams[tIndex].members[pIndex]!.isShiny.toggle()
                            }) {
                                ZStack {
                                    
                                    Rectangle()
                                        .frame(width: 35, height: 35)
                                        .foregroundColor(sessionData.teams[tIndex].members[pIndex]!.isShiny ? .gold : .secondary)
                                        .cornerRadius(5)
                                        .opacity(sessionData.teams[tIndex].members[pIndex]!.isShiny ? 0.35 : 0.5)
                                    
                                    Image(systemName: "sparkle")
                                        .imageScale(.large)
                                        .foregroundColor(sessionData.teams[tIndex].members[pIndex]!.isShiny ? .gold : .primary)
                                    
                                }
                            }
                            .padding(.leading, 5)
                            
                            // MARK: Gender indicator
                            
                            if sessionData.teams[tIndex].members[pIndex]!.gender == "Male" || sessionData.teams[tIndex].members[pIndex]!.gender == "Female" {
                                
                                Button(action: {
                                    if sessionData.teams[tIndex].members[pIndex]!.pokemon.maleRate == 100 || sessionData.teams[tIndex].members[pIndex]!.pokemon.maleRate == 0 {
                                        
                                        // This member's gender cannot be edited
                                        showingGenderAlert.toggle()
                                        
                                        
                                    } else if sessionData.teams[tIndex].members[pIndex]!.gender == "Male" {
                                        sessionData.teams[tIndex].members[pIndex]!.gender = "Female"
                                    } else if sessionData.teams[tIndex].members[pIndex]!.gender == "Female" {
                                        sessionData.teams[tIndex].members[pIndex]!.gender = "Male"
                                    }
                                }) {
                                    GenderCircle(gender: sessionData.teams[tIndex].members[pIndex]!.gender)
                                        .padding(.leading, 5)
                                }
                                .alert(isPresented: $showingGenderAlert) {
                                    Alert(title: Text("Cannot Edit Gender"), message: sessionData.teams[tIndex].members[pIndex]!.pokemon.maleRate == 100 ? Text("This Pokémon is always male.") : Text("This Pokémon is always female."))
                                }
                                
                            }
                            
                        }
                        .frame(height: 35)
                        
                    }
                    
                    Spacer()
                    
                }
                
                // MARK: Item picker
                
                HStack(spacing: 10) {
                    
                    VStack(spacing: 10) {
                        
    //                    HeadingText(text: "Item")
                        
                        Button(action: {
                            showingItemPicker.toggle()
                        }) {
                            ZStack {
                                
                                Rectangle()
                                    .frame(height: 60)
                                    .foregroundColor(.secondary)
                                    .cornerRadius(100)
                                    .opacity(0.4)
                                
                                HStack {
                                    
                                    if sessionData.teams[tIndex].members[pIndex]!.item == "" {
                                        
                                        Image(systemName: "plus")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
    //                                        .padding(.leading)
                                            .frame(height: 25)
                                            .foregroundColor(.primary)
                                        
                                        Text("Add Item")
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                    } else {
                                        
                                        if UIImage(named: sessionData.teams[tIndex].members[pIndex]!.item) != nil {
                                            Image(sessionData.teams[tIndex].members[pIndex]!.item)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
    //                                            .padding(.leading)
                                                .frame(height: 40)
                                        } else {
                                            Image("Question Mark")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
    //                                            .padding(.leading)
                                                .frame(height: 40)
                                        }
                                        
                                        Text(sessionData.teams[tIndex].members[pIndex]!.item)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        
                                    }
                                    
                                }
                                .padding(.horizontal, 10)
                                
                            }
                        }
                        .sheet(isPresented: $showingItemPicker) {
                            NavigationView {
                                TeamMemberItemPicker(tIndex: tIndex, pIndex: pIndex).environmentObject(sessionData)
                            }
                        }
                        
                    }
                    
                    // MARK: Ability picker
                    
                    VStack(spacing: 10) {
                        
    //                    HeadingText(text: "Ability")
                        
                        Button(action: {
                            showingAbilityPicker.toggle()
                        }) {
                            AbilityView(abilityName: sessionData.teams[tIndex].members[pIndex]!.ability, abilityNumber: getAbilityNumber())
                        }
                        .sheet(isPresented: $showingAbilityPicker) {
                            TeamMemberAbilityPicker(tIndex: tIndex, pIndex: pIndex)
                        }
                        
                    }
                    
                }
                .padding([.top, .leading, .trailing])
                
                // MARK: Move selection area
                
                HeadingText(text: "Moves")
                    .padding(.top)
                
                VStack {
                    
                    Divider()
                    
                    if sessionData.teams[tIndex].members[pIndex]!.moves[0] != nil {
                        
                        TeambuilderMoveDisplay(tIndex: tIndex, pIndex: pIndex, index: 0)
                        
                    } else {
                        
                        AddMoveOption(tIndex: tIndex, pIndex: pIndex, index: 0)
                        
                    }
                    
                    Divider()
                    
                    if sessionData.teams[tIndex].members[pIndex]!.moves[1] != nil {
                        
                        TeambuilderMoveDisplay(tIndex: tIndex, pIndex: pIndex, index: 1)
                        
                    } else {
                        
                        AddMoveOption(tIndex: tIndex, pIndex: pIndex, index: 1)
                        
                    }
                    
                    Divider()
                    
                    if sessionData.teams[tIndex].members[pIndex]!.moves[2] != nil {
                        
                        TeambuilderMoveDisplay(tIndex: tIndex, pIndex: pIndex, index: 2)
                        
                    } else {
                        
                        AddMoveOption(tIndex: tIndex, pIndex: pIndex, index: 2)
                        
                    }
                    
                    Divider()
                    
                    if sessionData.teams[tIndex].members[pIndex]!.moves[3] != nil {
                        
                        TeambuilderMoveDisplay(tIndex: tIndex, pIndex: pIndex, index: 3)
                        
                    } else {
                        
                        AddMoveOption(tIndex: tIndex, pIndex: pIndex, index: 3)
                        
                    }
                    
                    Divider()
                    
                }
                
                // MARK: Stats selection area
                
                HeadingText(text: "Stats")
                    .padding(.top)
                
                VStack {
                    
                    HStack(spacing: 0) {
                        
                        Text("HP")
                            .foregroundColor(.gray)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .hidden()
                        
                        Text("Base")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                        
                        Text("+")
                            .hidden()
        //                    .frame(maxWidth: .infinity)
                        
                        VStack {
                            Text("EV")
                                .fontWeight(.bold)
                            Text("\(508 - (sessionData.teams[tIndex].members[pIndex]!.EVs[0] + sessionData.teams[tIndex].members[pIndex]!.EVs[1] + sessionData.teams[tIndex].members[pIndex]!.EVs[2] + sessionData.teams[tIndex].members[pIndex]!.EVs[3] + sessionData.teams[tIndex].members[pIndex]!.EVs[4] + sessionData.teams[tIndex].members[pIndex]!.EVs[5])) left")
                                .font(.footnote)
                        }
                            .frame(maxWidth: .infinity)
                        
                        Text("+")
                            .hidden()
        //                    .frame(maxWidth: .infinity)
                        
                        VStack {
                            Text("IV")
                                .fontWeight(.bold)
                            Text("0-31")
                                .font(.footnote)
                        }
                            .frame(maxWidth: .infinity)
                        
                        Text("=")
                            .hidden()
        //                    .frame(maxWidth: .infinity)
                        
                        Text("Total")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                        
                    }
                    .padding(.horizontal)
                    
                    TeambuilderStatEditor(tIndex: tIndex, pIndex: pIndex, color: .green, index: 0)
                    
                    TeambuilderStatEditor(tIndex: tIndex, pIndex: pIndex, color: .orange, index: 1)
                    
                    TeambuilderStatEditor(tIndex: tIndex, pIndex: pIndex, color: .steel, index: 2)
                    
                    TeambuilderStatEditor(tIndex: tIndex, pIndex: pIndex, color: .psychic, index: 3)
                    
                    TeambuilderStatEditor(tIndex: tIndex, pIndex: pIndex, color: .ground, index: 4)
                    
                    TeambuilderStatEditor(tIndex: tIndex, pIndex: pIndex, color: .flying, index: 5)
                    
                    ZStack {
                        
                        Rectangle()
                            .frame(height: 40)
                            .foregroundColor(.secondary)
                            .opacity(0.275)
                        
                        HStack(spacing: 0) {
                            
                            Text("Total")
                                .foregroundColor(.primary)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                            
                            Text(String(50))
                                .frame(maxWidth: .infinity)
                                .hidden()
                            
                            Text("+")
                                .hidden()
            //                    .frame(maxWidth: .infinity)
                            
                            EVTextBox(tIndex: tIndex, pIndex: pIndex, index: 0, enteredEV: String(sessionData.teams[tIndex].members[pIndex]!.EVs[0]))
                                .frame(maxWidth: .infinity)
                                .hidden()
                            
                            Text("+")
                                .hidden()
            //                    .frame(maxWidth: .infinity)
                            
                            IVTextBox(tIndex: tIndex, pIndex: pIndex, index: 0, enteredIV: String(sessionData.teams[tIndex].members[pIndex]!.IVs[0]))
                                .frame(maxWidth: .infinity)
                                .hidden()
                            
                            Text("=")
                                .hidden()
            //                    .frame(maxWidth: .infinity)
                            
                            Text(String(sessionData.teams[tIndex].members[pIndex]!.getStatTotal()))
                                .font(.title2)
                                .foregroundColor(.primary)
                                .fontWeight(.heavy)
                                .frame(maxWidth: .infinity)
                            
                        }
                        .padding(.horizontal)
                        
                    }
                    
                }
                
            }
            .padding(.bottom)
        }
        
    }
    
    // MARK: Functions
    func getAbilityNumber() -> Int {
        if sessionData.teams[tIndex].members[pIndex]!.ability == sessionData.teams[tIndex].members[pIndex]!.pokemon.ability1 {
            return 1
        } else if sessionData.teams[tIndex].members[pIndex]!.ability == sessionData.teams[tIndex].members[pIndex]!.pokemon.ability2 {
            return 2
        } else if sessionData.teams[tIndex].members[pIndex]!.ability == sessionData.teams[tIndex].members[pIndex]!.pokemon.hiddenAbility {
            return 0
        }
        return 1
    }
    
}

struct TeamMemberEditor_Previews: PreviewProvider {
    static var previews: some View {
        TeamMemberEditor(tIndex: 0, pIndex: 0).environmentObject(SessionData())
    }
}

struct LevelTextField: View {
    
    // Variables
    var tIndex: Int
    var pIndex: Int
    @State var enteredLevel: String
    @State var placeholder = ""
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        TextField(placeholder, text: $enteredLevel) {
            
            isEditing in
            
            placeholder = enteredLevel
            
            if isEditing {
                enteredLevel = ""
            } else {
                if enteredLevel == "" {
                    
                    enteredLevel = String(sessionData.teams[tIndex].members[pIndex]!.level)
                    
                }
                
                // If it's all 0, set it to 1
                let zero = enteredLevel.filter { "0".contains($0) }
                if zero == enteredLevel {
                    enteredLevel = "1"
                }
                
                // Clip any zeros
                if enteredLevel.prefix(2) == String("00") {
                    enteredLevel = String(enteredLevel.suffix(1))
                } else if enteredLevel.prefix(1) == String("0") {
                    if enteredLevel.count == 3 {
                        enteredLevel = String(enteredLevel.suffix(2))
                    } else if enteredLevel.count == 2 {
                        enteredLevel = String(enteredLevel.suffix(1))
                    }
                }
                
                sessionData.teams[tIndex].members[pIndex]!.level = Int(enteredLevel) ?? sessionData.teams[tIndex].members[pIndex]!.level
            }
            
        } onCommit: {
            
            if enteredLevel == "" {
                
                enteredLevel = String(sessionData.teams[tIndex].members[pIndex]!.level)
                
            }
            
            // If it's all 0, set it to 1
            let zero = enteredLevel.filter { "0".contains($0) }
            if zero == enteredLevel {
                enteredLevel = "1"
            }
            
            // Clip any zeros
            if enteredLevel.prefix(2) == String("00") {
                enteredLevel = String(enteredLevel.suffix(1))
            } else if enteredLevel.prefix(1) == String("0") {
                if enteredLevel.count == 3 {
                    enteredLevel = String(enteredLevel.suffix(2))
                } else if enteredLevel.count == 2 {
                    enteredLevel = String(enteredLevel.suffix(1))
                }
            }
            
            sessionData.teams[tIndex].members[pIndex]!.level = Int(enteredLevel) ?? sessionData.teams[tIndex].members[pIndex]!.level
        }
        .multilineTextAlignment(.center)
        .onReceive(Just(enteredLevel)) { _ in validateLevel() }
        .frame(width: UIDevice.modelName.contains("iPod") ? 30 : 40)
        .font(.system(size: UIDevice.modelName.contains("iPod") ? 15 : 21, weight: .bold))
        
    }
    
    // Functions
    func validateLevel() {
        
        // Clip the text if a non-number is entered
        let filtered = enteredLevel.filter { "0123456789".contains($0) }
        if filtered != enteredLevel {
            self.enteredLevel = filtered
        }
        
        // Clip the text to 3 characters
        if enteredLevel.count > 3 {
            enteredLevel = String(enteredLevel.prefix(3))
        }
        
        // Clip the text if over 100
        if Int(enteredLevel) ?? 0 > 100 {
            enteredLevel = String(enteredLevel.prefix(2))
        }
        
    }
    
}

struct NicknameEditor: View {
    
    // Variables
    var tIndex: Int
    var pIndex: Int
    @State var nickname: String
    @State var placeholder = ""
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        TextField(placeholder, text: $nickname) {
            
            isEditing in
            
            placeholder = sessionData.teams[tIndex].members[pIndex]!.name
            
            if sessionData.teams[tIndex].members[pIndex]!.name == nickname && isEditing {
                nickname = ""
            } else if !isEditing {
                if nickname == "" {
                    
                    nickname = sessionData.teams[tIndex].members[pIndex]!.name
                    
                }
                
                sessionData.teams[tIndex].members[pIndex]!.nickname = nickname
            }
            
        } onCommit: {
            
            if nickname == "" {
                
                nickname = sessionData.teams[tIndex].members[pIndex]!.name
                
            }
            
            sessionData.teams[tIndex].members[pIndex]!.nickname = nickname
            
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .onReceive(Just(nickname)) { _ in limitText(12) }
        .font(.system(size: UIDevice.modelName.contains("iPod") ? 17 : 22, weight: .bold))
        .padding(.top)
        .padding(.leading, 5)
            
        
    }
    
    // Functions
    func limitText(_ upper: Int) {
        if nickname.count > upper && !(nickname == sessionData.teams[tIndex].members[pIndex]?.name) {
                nickname = String(nickname.prefix(upper))
            }
        }
    
}

struct TeambuilderMoveDisplay: View {
    
    // Variables
    @State var showingMovePicker = false
    @EnvironmentObject var sessionData: SessionData
    var tIndex: Int
    var pIndex: Int
    var index: Int
    
    var body: some View {
        
        if sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members.count >= pIndex + 1 && sessionData.teams[tIndex].members[pIndex] != nil {
            Button(action: {
                showingMovePicker.toggle()
            }) {
                if sessionData.teams[tIndex].members[pIndex]!.moves[index] != nil {
                    HStack(spacing: 0) {
                        
                        PokemonDetailTypeView(types: [sessionData.teams[tIndex].members[pIndex]!.moves[index]!.type, ""])
                            .padding(.leading, 10)
                            .scaleEffect(0.8)
                        
                        ZStack {
                            Rectangle()
                                .cornerRadius(7)
                                .frame(width: 35, height: 35)
                                .scaleEffect(0.8)
                                .foregroundColor(categoryColorDelegator(category: sessionData.teams[tIndex].members[pIndex]!.moves[index]!.category))
                                .opacity(0.3)
                            
                            Image(systemName: sessionData.teams[tIndex].members[pIndex]!.moves[index]!.category == "Physical" ? "burst.fill" : (sessionData.teams[tIndex].members[pIndex]!.moves[index]!.category == "Special" ? "sparkles" : "waveform.path.ecg"))
                                .resizable()
                                .frame(width: 23, height: 23)
                                .foregroundColor(categoryColorDelegator(category: sessionData.teams[tIndex].members[pIndex]!.moves[index]!.category))
                        }
                        .offset(x: -5)
                        
                        Text(sessionData.teams[tIndex].members[pIndex]!.moves[index]!.name)
                            .fontWeight(.bold)
                            .padding(.leading, 5)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                    }
                }
            }
            .sheet(isPresented: $showingMovePicker) {
                TeambuilderMovePicker(tIndex: tIndex, pIndex: pIndex, index: index, pokemonFilters: [sessionData.teams[tIndex].members[pIndex]!.pokemon])
            }
        }
    }
}

struct AddMoveOption: View {
    
    // Variables
    @State var showingMovePicker = false
    @EnvironmentObject var sessionData: SessionData
    var tIndex: Int
    var pIndex: Int
    var index: Int
    
    var body: some View {
        Button(action: {
            showingMovePicker.toggle()
        }) {
            HStack {
                
                ZStack {
                    Circle()
                        .frame(width: 35, height: 35)
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                    Image(systemName: "plus")
                        .foregroundColor(.primary)
                }
                
                Text("Add Move")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
            }
        }
        .sheet(isPresented: $showingMovePicker) {
            TeambuilderMovePicker(tIndex: tIndex, pIndex: pIndex, index: index, pokemonFilters: [sessionData.teams[tIndex].members[pIndex]!.pokemon])
        }
        .padding(.leading)
    }
}

struct TeambuilderStatEditor: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    var tIndex: Int
    var pIndex: Int
    var color: Color
    var index: Int
    var statName: String {
        switch index {
        case 0:
            return "HP"
        case 1:
            return "Atk"
        case 2:
            return "Def"
        case 3:
            return "SpAtk"
        case 4:
            return "SpDef"
        case 5:
            return "Spd"
        default:
            return ""
        }
    }
    
    var body: some View {
        
        if sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members.count >= pIndex + 1 && sessionData.teams[tIndex].members[pIndex] != nil {
            ZStack {
                
                Rectangle()
                    .frame(height: 40)
                    .foregroundColor(color)
                    .opacity(0.275)
                
                HStack(spacing: 0) {
                    
                    Text(statName)
                        .foregroundColor(color)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                    
                    Text(String(sessionData.teams[tIndex].members[pIndex]!.pokemon.baseStats[index]))
                        .frame(maxWidth: .infinity)
                    
                    Text("+")
    //                    .frame(maxWidth: .infinity)
                    
                    EVTextBox(tIndex: tIndex, pIndex: pIndex, index: index, enteredEV: String(sessionData.teams[tIndex].members[pIndex]!.EVs[index]))
                        .frame(maxWidth: .infinity)
                    
                    Text("+")
    //                    .frame(maxWidth: .infinity)
                    
                    IVTextBox(tIndex: tIndex, pIndex: pIndex, index: index, enteredIV: String(sessionData.teams[tIndex].members[pIndex]!.IVs[index]))
                        .frame(maxWidth: .infinity)
                    
                    Text("=")
    //                    .frame(maxWidth: .infinity)
                    
                    Text(String(Team.calculateStat(member: sessionData.teams[tIndex].members[pIndex]!, index: index)))
                        .font(.title2)
                        .foregroundColor(color)
                        .fontWeight(.heavy)
                        .frame(maxWidth: .infinity)
                    
                }
                .padding(.horizontal)
                
            }
        }
        
    }
}

struct EVTextBox: View {
    
    // Variables
    var tIndex: Int
    var pIndex: Int
    var index: Int
    @State var enteredEV: String
    @State var placeholder = ""
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .padding(.all, 5)
                .foregroundColor(.secondary)
                .opacity(0.5)
                .cornerRadius(20)
            
            TextField(placeholder, text: $enteredEV) {
                
                isEditing in
                
                placeholder = enteredEV
                
                if isEditing {
                    enteredEV = ""
                } else {
                    if enteredEV == "" {
                        enteredEV = String(sessionData.teams[tIndex].members[pIndex]!.EVs[index])
                    }
                    
                    // If over 252, cut it
                    if Int(enteredEV) ?? -1 > 252 {
                        enteredEV = "252"
                    }
                    
                    // If the sum total is over 508, cut the value to fit
                    var otherEVs = 0
                    if index != 0 {
                        otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[0]
                    }
                    if index != 1 {
                        otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[1]
                    }
                    if index != 2 {
                        otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[2]
                    }
                    if index != 3 {
                        otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[3]
                    }
                    if index != 4 {
                        otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[4]
                    }
                    
                    if Int(enteredEV) ?? -1 > 508 - otherEVs {
                        enteredEV = String(508 - otherEVs)
                    }
                    
                    // Set the data
                    sessionData.teams[tIndex].members[pIndex]!.EVs[index] = Int(enteredEV) ?? 0
                }
                
            } onCommit: {
                
                if enteredEV == "" {
                    enteredEV = String(sessionData.teams[tIndex].members[pIndex]!.EVs[index])
                }
                
                // If over 252, cut it
                if Int(enteredEV) ?? -1 > 252 {
                    enteredEV = "252"
                }
                
                // If the sum total is over 508, cut the value to fit
                var otherEVs = 0
                if index != 0 {
                    otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[0]
                }
                if index != 1 {
                    otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[1]
                }
                if index != 2 {
                    otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[2]
                }
                if index != 3 {
                    otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[3]
                }
                if index != 4 {
                    otherEVs += sessionData.teams[tIndex].members[pIndex]!.EVs[4]
                }
                
                if Int(enteredEV) ?? -1 > 508 - otherEVs {
                    enteredEV = String(508 - otherEVs)
                }
                
                // Set the data
                sessionData.teams[tIndex].members[pIndex]!.EVs[index] = Int(enteredEV) ?? 0
                
            }
            .onReceive(Just(enteredEV)) { _ in validateEV() }
            .multilineTextAlignment(.center)
            
        }
        
    }
    
    // Functions
    func validateEV() {
        
        // Clip the text if a non-number is entered
        let filtered = enteredEV.filter { "0123456789".contains($0) }
        if filtered != enteredEV {
            self.enteredEV = filtered
        }
        
        // Clip the text to 3 characters
        if enteredEV.count > 3 {
            enteredEV = String(enteredEV.prefix(3))
        }
        
    }
    
}

struct IVTextBox: View {
    
    // Variables
    var tIndex: Int
    var pIndex: Int
    var index: Int
    @State var enteredIV: String
    @State var placeholder = ""
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .padding(.all, 5)
                .foregroundColor(.secondary)
                .opacity(0.5)
                .cornerRadius(20)
            
            TextField(placeholder, text: $enteredIV) {
                
                isEditing in
                
                placeholder = enteredIV
                
                if isEditing {
                    enteredIV = ""
                } else {
                    if enteredIV == "" {
                        enteredIV = String(sessionData.teams[tIndex].members[pIndex]!.IVs[index])
                    }
                    
                    // If over 31, cut it
                    if Int(enteredIV) ?? -1 > 31 {
                        enteredIV = "31"
                    }
                    
                    // Set the data
                    sessionData.teams[tIndex].members[pIndex]!.IVs[index] = Int(enteredIV) ?? 0
                }
                
            } onCommit: {
                
                if enteredIV == "" {
                    enteredIV = String(sessionData.teams[tIndex].members[pIndex]!.IVs[index])
                }
                
                // If over 31, cut it
                if Int(enteredIV) ?? -1 > 31 {
                    enteredIV = "31"
                }
                
                // Set the data
                sessionData.teams[tIndex].members[pIndex]!.IVs[index] = Int(enteredIV) ?? 0
                
            }
            .onReceive(Just(enteredIV)) { _ in validateIV() }
            .multilineTextAlignment(.center)
            
        }
        
    }
    
    // Functions
    func validateIV() {
        
        // Clip the text if a non-number is entered
        let filtered = enteredIV.filter { "0123456789".contains($0) }
        if filtered != enteredIV {
            self.enteredIV = filtered
        }
        
        // Clip the text to 2 characters
        if enteredIV.count > 2 {
            enteredIV = String(enteredIV.prefix(2))
        }
        
    }
    
}
