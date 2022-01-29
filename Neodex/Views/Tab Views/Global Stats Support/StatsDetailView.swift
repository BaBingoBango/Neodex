//
//  StatsDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 3/2/21.
//

import SwiftUI

struct StatsDetailView: View {
    
    // Variables
    var pokemon: Pokemon
    var ranking: RankingsStat
    var format: String
    var month: String
    var year: String
    var minRating: String
    @State var showingMoreMoves = false
    @State var showingMoreItems = false
    @State var showingDetail = false
    
    @State var detail: RankingDetail? = nil
    let dataTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State var shouldShowDataFailure = false
    
    var body: some View {
        
        let sortedMoves = sortStatsDict(dict: detail?.moves ?? [:])
        let sortedItems = sortStatsDict(dict: detail?.items ?? [:])
        let sortedTeammates = sortStatsDict(dict: detail?.teammates ?? [:])
        let sortedSpreads = sortEVDict(dict: detail?.EVspreads ?? [:])
        
//        NavigationView {
            ScrollView {
                if !sortedMoves.isEmpty {
                    VStack {
                    
                        ZStack {
                            
                            VStack {
                                Rectangle()
                                .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                    .frame(height: 90)
                                Spacer()
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Rectangle()
                                            .frame(width: UIScreen.screenWidth / 1.8, height: 50)
                                            .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                            .opacity(0.3)
                                            .cornerRadius(50)
                                        Text("\(String(ranking.usage.rounded(toPlaces: 2)))% Usage")
                                            .fontWeight(.bold)
                                            .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                            .font(.system(size: !UIDevice.modelName.contains("iPod") ? 20 : 15))
                                            .padding(.trailing)
                                    }
                                    .offset(x: 21)
                                }
                            }
                            
                            HStack(alignment: .top) {
                                
                                Button(action: {
                                    showingDetail.toggle()
                                }) {
                                    Image("\(pokemon.name)-art")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: UIScreen.screenWidth / 3, height: 150)
                                        .padding(.top, 10)
                                }
                                .sheet(isPresented: $showingDetail) {
                                    NavigationView {
                                        PokemonDetailView(pokemon: pokemon, buttonText: "Done")
                                    }
                                }
                                
                                Spacer()
                                
                                VStack {
                                    Spacer()
                                    Text(ranking.name)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                    Spacer()
                                }
                                .frame(height: 90)
                                
                                Spacer()
                                
                            }
                            .padding(.leading, 30)
                            
                        }
                    
                        
                        // MARK: Top Abilities
                        HeadingText(text: "Top Abilities")
                        
                        let sortedAbilities = sortStatsDict(dict: detail!.abilities)

                        if !sortedAbilities.isEmpty {
                            ForEach(sortedAbilities, id: \.self) { abilityName in
                                
                                AbilityRankOption(rank: sortedAbilities.firstIndex(of: abilityName)! + 1, name: abilityName, usage: detail!.abilities[abilityName]!.rounded(toPlaces: 1))
                                
                            }
                        }
                        
                        // MARK: Top Moves
    //                    let sortedMoves = sortStatsDict(dict: detail!.moves)
                        
                        HStack {
                            Text("Top Moves")
                                .font(.title)
                                .fontWeight(.bold)
                            if sortedMoves.count >= 4 {
                                Button(action: {
                                    self.showingMoreMoves.toggle()
                                }) {
                                    HStack {
                                        Text("See All")
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color.blue)
                                            .padding(.leading, 5)
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Color.blue)
                                    }
                                }
                                .sheet(isPresented: $showingMoreMoves) {
                                    MoreMovesView(sortedMoves: sortedMoves, moves: detail!.moves, name: ranking.name)
                                }
                            }
                            Spacer()
                        }
                        .padding([.top, .leading])
                        
                        if !sortedMoves.isEmpty {
                            
                            if sortedMoves.count >= 3 {
                                
                                ForEach(sortedMoves[0...2], id: \.self) { moveName in
                                    
                                    MoveRankOption(rank: sortedMoves.firstIndex(of: moveName)! + 1, name: moveName, usage: detail!.moves[moveName]!.rounded(toPlaces: 1))
                                    
                                }
                                
                            } else {
                                
                                ForEach(sortedMoves[0...(sortedMoves.count - 1)].filter({ $0 != "Nothing" }), id: \.self) { moveName in
                                    
                                    MoveRankOption(rank: sortedMoves.filter({ $0 != "Nothing" }).firstIndex(of: moveName)! + 1, name: moveName, usage: detail!.moves[moveName]!.rounded(toPlaces: 1))
                                    
                                }
                                
                            }
                            
                        }
                        
                        // MARK: Top Items
                        GlobalStatsItemsDetail(sortedItems: sortedItems, detail: detail!, name: ranking.name)
                        
                        // MARK: Top Teammates
                        GlobalStatsTeammatesDetail(sortedTeammates: sortedTeammates, detail: detail!)
                            .padding(.top)
                        
                        // MARK: Top EV Spreads
                        GlobalStatsEVDetail(natures: sortedSpreads.natures, statValues: sortedSpreads.statValues, usages: sortedSpreads.usages, pokemon: pokemon, rankName: ranking.name)
                        
                    }
                    .padding(.bottom)
                } else if !Reachability.isConnectedToNetwork() {
                    
                    VStack {
                        
                        ZStack {
                            
                            VStack {
                                Rectangle()
                                .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                    .frame(height: 90)
                                Spacer()
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Rectangle()
                                            .frame(width: UIScreen.screenWidth / 1.8, height: 50)
                                            .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                            .opacity(0.3)
                                            .cornerRadius(50)
                                        Text("\(String(ranking.usage.rounded(toPlaces: 2)))% Usage")
                                            .fontWeight(.bold)
                                            .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                            .font(.system(size: !UIDevice.modelName.contains("iPod") ? 20 : 15))
                                            .padding(.trailing)
                                    }
                                    .offset(x: 21)
                                }
                            }
                            
                            HStack(alignment: .top) {
                                
                                Button(action: {
                                    showingDetail.toggle()
                                }) {
                                    Image("\(pokemon.name)-art")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: UIScreen.screenWidth / 3, height: 150)
                                        .padding(.top, 10)
                                }
                                .sheet(isPresented: $showingDetail) {
                                    NavigationView {
                                        PokemonDetailView(pokemon: pokemon, buttonText: "Done")
                                    }
                                }
                                
                                Spacer()
                                
                                VStack {
                                    Spacer()
                                    Text(ranking.name)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .frame(height: 90)
                                
                                Spacer()
                                
                            }
                            .padding(.leading, 30)
                            
                        }
                        
                        Text("Network Error")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.top, 30)
                            .padding(.horizontal)
                        Text("Please check that your device is connected to the Internet and try again.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                            .padding(.horizontal)
                        
                    }
                    
                } else {
                    
                    VStack {
                        
                        ZStack {
                            
                            VStack {
                                Rectangle()
                                .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                    .frame(height: 90)
                                Spacer()
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Rectangle()
                                            .frame(width: UIScreen.screenWidth / 1.8, height: 50)
                                            .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                            .opacity(0.3)
                                            .cornerRadius(50)
                                        Text("\(String(ranking.usage.rounded(toPlaces: 2)))% Usage")
                                            .fontWeight(.bold)
                                            .foregroundColor(typeColorDelegator(type: pokemon.type1))
                                            .font(.system(size: !UIDevice.modelName.contains("iPod") ? 20 : 15))
                                            .padding(.trailing)
                                    }
                                    .offset(x: 21)
                                }
                            }
                            
                            HStack(alignment: .top) {
                                
                                Button(action: {
                                    showingDetail.toggle()
                                }) {
                                    Image("\(pokemon.name)-art")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: UIScreen.screenWidth / 3, height: 150)
                                        .padding(.top, 10)
                                }
                                .sheet(isPresented: $showingDetail) {
                                    NavigationView {
                                        PokemonDetailView(pokemon: pokemon, buttonText: "Done")
                                    }
                                }
                                
                                Spacer()
                                
                                VStack {
                                    Spacer()
                                    Text(ranking.name)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .frame(height: 90)
                                
                                Spacer()
                                
                            }
                            .padding(.leading, 30)
                            
                        }
                        
                        if shouldShowDataFailure {
                            
                            Text("No Data Avaliable")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.top, 30)
                                .padding(.horizontal)
                            Text("Detailed usage statistics are not available for \(ranking.name) in \(format) during \(month)-\(year).")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                                .padding(.horizontal)
                            
                        } else {
                            
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding(.top, 25)
                            
                        }
                        
                    }
                    
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    detail = getRankingDetail()
                    
                }
            }
            .onReceive(dataTimer) { input in
                shouldShowDataFailure = true
            }
//            .edgesIgnoringSafeArea(.top)
            
            // MARK: Nav view settings
            .navigationBarTitle(Text(""), displayMode: .inline)
            
//        }
        
    }
    
    // MARK: Functions
    func getRankingDetail() -> RankingDetail? {
        
        // Prep a link
        let link = "https://www.smogon.com/stats/\(year)-\(month)/moveset/\(format)-\(minRating).txt"
        
        // Attempt to connect to the network and get the data using the prepared link
        let textFile = getURLContents(link: link)
        
        var detail = RankingDetail(abilities: [:], items: [:], EVspreads: [:], moves: [:], teammates: [:])
        if textFile == nil {
            return nil
        } else {
            
            // Parse the text file
            let lines = textFile!.components(separatedBy: .newlines)
            for index in 0...(lines.count - 1) {
                
                // Find the correct line
                if lines[index].contains(ranking.name) && !lines[index].contains("%") && !lines[index].contains("+") {
                    
                    // Capture the abilities section by splitting
                    let lines2 = textFile!.components(separatedBy: " | \(ranking.name)   ")[1].components(separatedBy: "Items")[0].components(separatedBy: .newlines)
                    
                    // Grab the abilities
                    for eachLine in lines2 {
                        if eachLine.contains("%") && !eachLine.contains("+") {
                            // Split the line to get the name and the usage %
                            let abilityName = eachLine.components(separatedBy: " | ")[1].components(separatedBy: .decimalDigits)[0].trimmingCharacters(in: .whitespaces)
                            let abilityUsage = eachLine.components(separatedBy: "%")[0].components(separatedBy: " | ")[1].components(separatedBy: "\(abilityName) ")[1].trimmingCharacters(in: .whitespaces)
                            detail.abilities[abilityName] = Double(abilityUsage.trimmingCharacters(in: .whitespaces))
                        }
                    }
                    
                    // Capture the moves section by splitting
                    let moveLines = textFile!.components(separatedBy: " | \(ranking.name)   ")[1].components(separatedBy: "Teammates")[0].components(separatedBy: "Moves")[1].components(separatedBy: .newlines)
                    
                    // Grab the abilities
                    for eachLine in moveLines {
                        if eachLine.contains("%") && !eachLine.contains("+") {
                            // Split the line to get the name and the usage percent
                            let moveName = eachLine.components(separatedBy: " | ")[1].components(separatedBy: .decimalDigits)[0].trimmingCharacters(in: .whitespaces)
                            let moveUsage = eachLine.components(separatedBy: "%")[0].components(separatedBy: " | ")[1].components(separatedBy: "\(moveName) ")[1].trimmingCharacters(in: .whitespaces)
                            detail.moves[moveName] = Double(moveUsage.trimmingCharacters(in: .whitespaces))
                        }
                    }
                    
                    // Capture the items section by splitting
                    let itemLines = textFile!.components(separatedBy: " | \(ranking.name)   ")[1].components(separatedBy: "Spreads")[0].components(separatedBy: "Items")[1].components(separatedBy: .newlines)
                    
                    // Grab the moves
                    for eachLine in itemLines {
                        if eachLine.contains("%") && !eachLine.contains("+") {
                            // Split the line to get the name and the usage percent
                            let itemName = eachLine.components(separatedBy: " | ")[1].components(separatedBy: .decimalDigits)[0].trimmingCharacters(in: .whitespaces)
                            let itemUsage = eachLine.components(separatedBy: "%")[0].components(separatedBy: " | ")[1].components(separatedBy: "\(itemName) ")[1].trimmingCharacters(in: .whitespaces)
                            detail.items[itemName] = Double(itemUsage.trimmingCharacters(in: .whitespaces))
                        }
                    }
                    
                    // Capture the teammates section by splitting
                    let teammateLines = textFile!.components(separatedBy: " | \(ranking.name)   ")[1].components(separatedBy: "Checks and Counters")[0].components(separatedBy: "Teammates")[1].components(separatedBy: .newlines)
                    
                    // Grab the teammates
                    for eachLine in teammateLines {
                        if (eachLine.contains("+") || eachLine.contains("%")) && !eachLine.contains("------") {
                            // Split the line to get the name and the usage percent
                            var teammateName = ""
                            if eachLine.contains("+") {
                                teammateName = eachLine.components(separatedBy: " | ")[1].components(separatedBy: "+")[0].trimmingCharacters(in: .whitespaces)
                            } else {
                                teammateName = eachLine.components(separatedBy: " ")[2].components(separatedBy: "%")[0]
                            }
                            var teammateUsage = ""
                            if eachLine.contains("+") {
                                teammateUsage = eachLine.components(separatedBy: "+")[1].components(separatedBy: "%")[0]
                            } else {
                                teammateUsage = eachLine.components(separatedBy: " ")[3].components(separatedBy: "%")[0]
                            }
                            detail.teammates[teammateName] = Double(teammateUsage)
                        }
                    }
                    
                    // Capture the spreads section by splitting
                    let EVlines = textFile!.components(separatedBy: " | \(ranking.name)   ")[1].components(separatedBy: "Moves")[0].components(separatedBy: "Spreads")[1].components(separatedBy: .newlines)
                    
                    // Grab the spreads
                    for eachLine in EVlines {
                        if eachLine.contains("%") && !eachLine.contains("+") {
                            if eachLine.contains(":") {
                                // Collect the spread's nature, values, and usage percent
                                let EVnature = eachLine.components(separatedBy: " | ")[1].components(separatedBy: ":")[0]
                                let splitValues = eachLine.components(separatedBy: ":")[1].components(separatedBy: .whitespaces)[0].trimmingCharacters(in: .whitespaces)
                                let EVStringValues = splitValues.components(separatedBy: "/")
                                var EVDoubleValues: [Int] = []
                                for eachString in EVStringValues {
                                    EVDoubleValues.append(Int(eachString)!)
                                }
                                let EVusage = eachLine.components(separatedBy: splitValues)[1].components(separatedBy: "%")[0].trimmingCharacters(in: .whitespaces)
                                detail.EVspreads[[EVnature : EVDoubleValues]] = Double(EVusage)
                            } else {
                                // This is for "Other" - get the usage percent
                                let EVusage = eachLine.components(separatedBy: "Other ")[1].components(separatedBy: "%")[0]
                                detail.EVspreads[["Other" : []]] = Double(EVusage)
                            }
                        }
                    }
                    
                }
                
            }
            
        }
        
        return detail
        
    }
    
    // MARK: Functions
    func sortStatsDict(dict: [String : Double]) -> [String] {
        // Create a double array
        var percents: [Double] = []
        for eachPercent in dict.values {
            percents.append(eachPercent)
        }
        percents = percents.sorted(by: >)
        
        // Make and return a new string array
        var answer: [String] = []
        for eachPercent in percents {
            for (eachKey, eachValue) in dict {
                if eachValue == eachPercent {
                    answer.append(eachKey)
                }
            }
        }
        for eachName in answer {
            if eachName == "Other" {
                answer = answer.filter({ $0 != "Other" })
                answer.append("Other")
            }
        }
        return answer
        
    }
    func getStatsDictIndex(dict: [String : Double], name: String) -> Int {
        // Create a string array
        var names: [String] = []
        for eachKey in dict.keys {
            names.append(eachKey)
        }
        
        return names.firstIndex(of: name) ?? -1
        
    }
    func sortEVDict(dict: [[String: [Int]] : Double]) -> EVDataBundle {
        
        // Get a sorted array of Doubles
        var usages: [Double] = []
        for eachUsage in dict.values {
            usages.append(eachUsage)
        }
        usages = usages.sorted(by: >)
        
        // Get arrays of Strings and [Int]s in order
        var natures: [String] = []
        var stats: [[Int]] = []
        for eachUsage in usages {
            for (eachKey, eachValue) in dict {
                if eachValue == eachUsage {
                    natures.append(eachKey.keys.first!)
                    stats.append(eachKey.values.first!)
                }
            }
        }
        
        // Move "Other" to the last spot
        for eachNature in natures {
            if eachNature == "Other" {
                let index = natures.firstIndex(of: "Other")!
                // Save the usage data for Other
                let otherUsage = usages[index]
                // Remove
                natures.remove(at: index)
                stats.remove(at: index)
                usages.remove(at: index)
                // Re-add
                natures.append("Other")
                stats.append([])
                usages.append(otherUsage)
            }
        }
        
        // Returneth
        return EVDataBundle(natures: natures, statValues: stats, usages: usages)
        
    }
    
}

struct StatsDetailView_Previews: PreviewProvider {
    static var previews: some View {
        StatsDetailView(pokemon: pokemonDataList[6], ranking: RankingsStat(rank: 30, name: "Charizard", usage: 6.48423), format: "gen8vgc2021", month: "02", year: "2021", minRating: "0")
    }
}

struct RankingDetail {
    
    // Variables
    var abilities: [String : Double]
    var items: [String : Double]
    var EVspreads: [[String: [Int]] : Double] // Nature, EV values, usage %
    var moves: [String : Double]
    var teammates: [String : Double]
    
}

struct EVDataBundle {
    // Variables
    var natures: [String]
    var statValues: [[Int]]
    var usages: [Double]
}

struct AbilityRankOption: View {
    
    // Variables
    var rank: Int
    var name: String
    var usage: Double
    var isOther: Bool {
        return name == "Other"
    }
    @State var showingDetail = false
    
    var body: some View {
        
        let abilityDetail = Ability.getDetail(ability: name)
        
        Button(action: {
            showingDetail.toggle()
        }) {
            ZStack {
                
                Rectangle()
                    .cornerRadius(50)
                    .padding(.horizontal, 10)
                    .frame(height: 45)
                    .foregroundColor(!isOther ? rankColorDelegator(rank: rank) : .gray)
                    .opacity(0.3)
                
                HStack {
                    
                    if !isOther {
                        Text(String(rank))
                            .fontWeight(.heavy)
                            .foregroundColor(rankColorDelegator(rank: rank))
                            .font(.system(size: 30))
                    }
                    
                    Spacer()
                    
                    Text(name)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .font(.system(size: 19))
                    
                    Spacer()
                    
                    Text(String("\(usage)%"))
                        .font(.system(size: 19))
                        .fontWeight(.bold)
                        .foregroundColor(!isOther ? rankColorDelegator(rank: rank) : .gray)
                        .frame(width: 80)
                    
    //                Spacer()
                    
                }
                .padding(.horizontal, 35)
                
            }
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                AbilityDetailView(name: name, detail: abilityDetail)
            }
        }
    }
}

struct MoveRankOption: View {
    
    // Variables
    var rank: Int
    var name: String
    var usage: Double
    var isOther: Bool {
        return name == "Other"
    }
    @State var showingDetail = false
    
    var body: some View {
        
        let move = Move.moveLookup(name: name)
        
        Button(action: {
            if !isOther {
                showingDetail.toggle()
            }
        }) {
            ZStack {
                
                Rectangle()
                    .cornerRadius(50)
                    .padding(.horizontal, 10)
                    .frame(height: 45)
                    .foregroundColor(!isOther ? typeColorDelegator(type: move.type) : .gray)
                    .opacity(0.3)
                
                HStack {
                    
                    if !isOther {
                        Text(String(rank))
                            .fontWeight(.heavy)
                            .foregroundColor(typeColorDelegator(type: move.type))
                            .font(.system(size: 30))
                    } else {
                        Text("9")
                            .fontWeight(.heavy)
                            .foregroundColor(typeColorDelegator(type: move.type))
                            .font(.system(size: 30))
                            .hidden()
                    }
                    
                    Spacer()
                    
                    Text(name)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .font(.system(size: 19))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer()
                    
                    Text(String("\(usage)%"))
                        .font(.system(size: 19))
                        .fontWeight(.bold)
                        .foregroundColor(!isOther ? typeColorDelegator(type: move.type) : .gray)
                        .frame(width: 80)
                    
    //                Spacer()
                    
                }
                .padding(.horizontal, 35)
                
            }
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                MoveDetailView(move: move, buttonText: "Done")
            }
        }
    }
}

struct MoreMovesView: View {
    
    // Variables
    var sortedMoves: [String]
    var moves: [String : Double]
    var name: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    ForEach(sortedMoves, id: \.self) { moveName in
                        
                        MoveRankOption(rank: sortedMoves.firstIndex(of: moveName)! + 1, name: moveName, usage: moves[moveName]!.rounded(toPlaces: 1))
                        
                    }
                    
                    .navigationBarTitle(Text("Top \(name) Moves"), displayMode: .inline)
                    .navigationBarItems(trailing: Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                })
                }
                .padding(.vertical)
            }
            
        }
        
    }
    
}

struct ItemRankOption: View {
    
    // Variables
    var rank: Int
    var name: String
    var usage: Double
    var isOther: Bool {
        return name == "Other"
    }
    @State var showingDetail = false
    
    var body: some View {
        
        Button(action: {
            if !isOther {
                showingDetail.toggle()
            }
        }) {
            ZStack {
                
                Rectangle()
                    .cornerRadius(50)
                    .padding(.horizontal, 10)
                    .frame(height: 45)
                    .foregroundColor(!isOther ? rankColorDelegator(rank: rank) : .gray)
                    .opacity(0.3)
                
                HStack {
                    
                    if !isOther {
                        if UIImage(named: name) != nil {
                            Image(name)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 35, height: 35)
                        } else {
                            Image("Question Mark")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 35, height: 35)
                        }
                    } else {
                        Image("Question Mark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 35, height: 35)
                            .hidden()
                    }
                    
                    Spacer()
                    
                    Text(name)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .font(.system(size: 19))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer()
                    
                    Text(String("\(usage)%"))
                        .font(.system(size: 19))
                        .fontWeight(.bold)
                        .foregroundColor(!isOther ? rankColorDelegator(rank: rank) : .gray)
                        .frame(width: 80)
                    
    //                Spacer()
                    
                }
                .padding(.horizontal, 35)
                
            }
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                ItemDetailView(item: Item.itemList[Item.itemList.firstIndex(where: { $0.name == name }) ?? 0], buttonText: "Done")
            }
        }
    }
}

struct MoreItemsView: View {
    
    // Variables
    var sortedItems: [String]
    var items: [String : Double]
    var name: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    ForEach(sortedItems, id: \.self) { itemName in
                        
                        ItemRankOption(rank: sortedItems.firstIndex(of: itemName)! + 1, name: itemName, usage: items[itemName]!.rounded(toPlaces: 1))
                        
                    }
                    
                    .navigationBarTitle(Text("Top \(name) Items"), displayMode: .inline)
                    .navigationBarItems(trailing: Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                })
                }
                .padding(.vertical)
            }
            
        }
        
    }
    
}
