//
//  GlobalStatsSpreadDetail.swift
//  Neodex
//
//  Created by Ethan Marshall on 3/7/21.
//

import SwiftUI
import Combine

struct GlobalStatsSpreadDetail: View {
    
    // Variables
    var stats: [Int]
    var nature: String
    var usage: Double
    var pokemon: Pokemon
    var rankName: String
    @Environment(\.presentationMode) var presentationMode
    @State var selectedPie: String = ""
    @State var selectedDonut: String = ""
    var statColors: [Color] = [.green, .orange, .steel, .psychic, .ground, .flying]
    var statModel: [ChartCellModel] {
        var answer: [ChartCellModel] = []
        for i in 0...5 {
            answer.append(ChartCellModel(color: statColors[i], value: CGFloat(stats[i]), name: "Stat"))
        }
        return answer
    }
    @State var level = "100"
    @State var levelPlaceholder = ""
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    
                    ZStack {
                        
                        DonutChart(dataModel: ChartDataModel.init(dataModel: statModel), onTap: {
                                dataModel in
                                if let dataModel = dataModel {
                                    self.selectedDonut = "Subject: \(dataModel.name)\nPointes: \(dataModel.value)"
                                } else {
                                    self.selectedDonut = ""
                                }
                            })
                        .frame(width: UIScreen.screenWidth / 2, height: UIScreen.screenHeight / 4)
                        
                        
                        VStack {
                            
                            Text(nature)
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("\(String(usage.rounded(toPlaces: 2)))%")
                                .font(.headline)
                                .fontWeight(.light)
                            
                        }
                        
                    }
                    
                    HStack {
                        
                        VStack {
                            StatsSpreadDetailViewOption(color: .green, name: "HP", value: stats[0])
                            StatsSpreadDetailViewOption(color: .orange, name: "Atk", value: stats[1])
                            StatsSpreadDetailViewOption(color: .steel, name: "Def", value: stats[2])
                        }
                        
                        VStack {
                            StatsSpreadDetailViewOption(color: .psychic, name: "Sp. Atk", value: stats[3])
                            StatsSpreadDetailViewOption(color: .ground, name: "Sp. Def", value: stats[4])
                            StatsSpreadDetailViewOption(color: .flying, name: "Speed", value: stats[5])
                        }
                        
                    }
                    
                    HeadingText(text: "Total Stats")
                        .padding(.top)
                    
                    ZStack {
                        
                        Rectangle()
                            .frame(height: 60)
                            .foregroundColor(.blue)
                            .opacity(0.3)
                            .cornerRadius(10)
                        
                        HStack {
                            
                            Text("Level")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            
                            TextField(levelPlaceholder, text: $level) {
                                
                                isEditing in
                                
                                levelPlaceholder = level
                                
                                if isEditing {
                                    level = ""
                                }
                                
                            } onCommit: {
                                
                                if level == "" {
                                    level = levelPlaceholder
                                }
                                
                                // If it's all 0, set it to 1
                                let zero = level.filter { "0".contains($0) }
                                if zero == level {
                                    level = "1"
                                }
                                
                                // Clip any zeros
                                if level.prefix(2) == String("00") {
                                    level = String(level.suffix(1))
                                } else if level.prefix(1) == String("0") {
                                    if level.count == 3 {
                                        level = String(level.suffix(2))
                                    } else if level.count == 2 {
                                        level = String(level.suffix(1))
                                    }
                                }
                                
                            }
                            .foregroundColor(.primary)
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 50)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .multilineTextAlignment(.center)
                            .onReceive(Just(level)) { _ in validateLevel() }

                        }
                        
                    }
                    
                    HStack {
                        
                        VStack {
                            StatsSpreadDetailViewOption(color: .green, name: "HP", value: level == "" || level == "0" || level == "00" || level == "000" ? 0 : calculateStat(level: Int(level)!, pokemon: pokemon, EV: stats[0], IV: 31, index: 0, nature: Nature.natureList[Nature.natureList.firstIndex(where: { $0.name == nature }) ?? 0]))
                            StatsSpreadDetailViewOption(color: .orange, name: "Atk", value: level == "" || level == "0" || level == "00" || level == "000" ? 0 : calculateStat(level: Int(level)!, pokemon: pokemon, EV: stats[1], IV: 31, index: 1, nature: Nature.natureList[Nature.natureList.firstIndex(where: { $0.name == nature }) ?? 0]))
                            StatsSpreadDetailViewOption(color: .steel, name: "Def", value: level == "" || level == "0" || level == "00" || level == "000" ? 0 : calculateStat(level: Int(level)!, pokemon: pokemon, EV: stats[2], IV: 31, index: 2, nature: Nature.natureList[Nature.natureList.firstIndex(where: { $0.name == nature }) ?? 0]))
                        }
                        
                        VStack {
                            StatsSpreadDetailViewOption(color: .psychic, name: "Sp. Atk", value: level == "" || level == "0" || level == "00" || level == "000" ? 0 : calculateStat(level: Int(level)!, pokemon: pokemon, EV: stats[3], IV: 31, index: 3, nature: Nature.natureList[Nature.natureList.firstIndex(where: { $0.name == nature }) ?? 0]))
                            StatsSpreadDetailViewOption(color: .ground, name: "Sp. Def", value: level == "" || level == "0" || level == "00" || level == "000" ? 0 : calculateStat(level: Int(level)!, pokemon: pokemon, EV: stats[4], IV: 31, index: 4, nature: Nature.natureList[Nature.natureList.firstIndex(where: { $0.name == nature }) ?? 0]))
                            StatsSpreadDetailViewOption(color: .flying, name: "Speed", value: level == "" || level == "0" || level == "00" || level == "000" ? 0 : calculateStat(level: Int(level)!, pokemon: pokemon, EV: stats[5], IV: 31, index: 5, nature: Nature.natureList[Nature.natureList.firstIndex(where: { $0.name == nature }) ?? 0]))
                        }
                        
                    }
                    
                }
                .padding(.all)
            }
            
            // MARK: Nav view settings
                .navigationBarTitle(Text("\(rankName) EV Spread"), displayMode: .inline)
                .navigationBarItems(trailing: Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done")
                })
            
        }
        
    }
    
    // Functions
    func validateLevel() {
        
        // Clip the text if a non-number is entered
        let filtered = level.filter { "0123456789".contains($0) }
        if filtered != level {
            self.level = filtered
        }
        
        // Clip the text to 3 characters
        if level.count > 3 {
            level = String(level.prefix(3))
        }
        
        // Clip the text if over 100
        if Int(level) ?? 0 > 100 {
            level = String(level.prefix(2))
        }
        
    }
    func getNatureValue(nature: Nature, index: Int) -> Double {
        
        // Return 1.0 if the team member has a neutral nature
        if nature.plus == nature.minus {
            return 1.0
        }
        
        // Determine the stat being calculated
        var stat = ""
        switch index {
        case 1:
            stat = "Attack"
        case 2:
            stat = "Sp. Atk"
        case 3:
            stat = "Defense"
        case 4:
            stat = "Sp. Def"
        case 5:
            stat = "Speed"
        default:
            stat = "???"
        }
        
        if stat == nature.plus {
            return 1.1
        } else if stat == nature.minus {
            return 0.9
        } else {
            return 1.0
        }
        
    }
    func calculateStat(level: Int, pokemon: Pokemon, EV: Int, IV: Int, index: Int, nature: Nature) -> Int {
        
        let base = pokemon.baseStats[index]
        
        if index == 0 {
            
            // Use the HP stat formula to calculate the total HP value
            let EV4 = Int(Double(EV) / 4.0)
            let numerator = (2.0 * Double(base) + Double(IV) + Double(EV4)) * Double(level)
            let fraction = Int(numerator / 100.0)
            let HP = fraction + level + 10
            return HP
            
        } else {
            
            // Use the general formula to calculate the total stat value
            let EV4 = Int(Double(EV) / 4.0)
            let numerator = (2.0 * Double(base) + Double(IV) + Double(EV4)) * Double(level)
            let fraction = Int(numerator / 100.0)
            let stat = Int(Double(fraction + 5) * getNatureValue(nature: nature, index: index))
            return stat
            
        }
        
    }
    
}

struct GlobalStatsSpreadDetail_Previews: PreviewProvider {
    static var previews: some View {
        GlobalStatsSpreadDetail(stats: [20, 30, 40, 50, 60, 70], nature: "Relaxed", usage: 23.76543, pokemon: Pokemon.findPokemon(name: "Charizard"), rankName: "Charizard")
    }
}

struct StatsSpreadDetailViewOption: View {
    
    // Variables
    var color: Color
    var name: String
    var value: Int
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(height: 40)
                .foregroundColor(color)
                .opacity(0.3)
                .cornerRadius(10)
            
            HStack {
                
                Text(name)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .font(.system(size: 20))
                
                Text(String(value))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .font(.system(size: 20))
                
            }
            
        }
        
    }
    
}
