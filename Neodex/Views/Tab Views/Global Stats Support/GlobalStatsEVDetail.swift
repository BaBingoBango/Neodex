//
//  GlobalStatsEVDetail.swift
//  Neodex
//
//  Created by Ethan Marshall on 3/7/21.
//

import SwiftUI

struct GlobalStatsEVDetail: View {
    
    // Variables
    var natures: [String]
    var statValues: [[Int]]
    var usages: [Double]
    var pokemon: Pokemon
    var rankName: String
    
    var body: some View {
        
        VStack {
            
            HeadingText(text: "Top EV Spreads")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    
                    ForEach(0..<usages.count) { i in
                        GlobalStatsEVDetailDonut(stats: statValues[i], nature: natures[i], usage: usages[i], pokemon: pokemon, rankName: rankName)
                            .padding(.trailing, 10)
                    }
                    
                }
                .padding(.horizontal)
            }
            
        }
        
    }
}

//struct GlobalStatsEVDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        GlobalStatsEVDetail()
//    }
//}

struct GlobalStatsEVDetailDonut: View {
    
    // Variables
    var stats: [Int]
    var nature: String
    var usage: Double
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
    @State var otherSelectedPie: String = ""
    @State var otherSelectedDonut: String = ""
    var otherStatModel: [ChartCellModel] {
        let answer: [ChartCellModel] = [ChartCellModel(color: .gray, value: 1, name: "Stat")]
        return answer
    }
    @State var showingDetail = false
    var pokemon: Pokemon
    var rankName: String
    
    var body: some View {
        
        if nature != "Other" {
            
            Button(action: {
                showingDetail.toggle()
            }) {
                ZStack {
                    
                    DonutChart(dataModel: ChartDataModel.init(dataModel: statModel), onTap: {
                            dataModel in
                            if let dataModel = dataModel {
                                self.selectedDonut = "Subject: \(dataModel.name)\nPointes: \(dataModel.value)"
                            } else {
                                self.selectedDonut = ""
                            }
                        })
                    .frame(width: 130, height: 130, alignment: .center)
                    
                    VStack {
                        
                        Text(nature)
                            .fontWeight(.bold)
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                        
                        Text("\(String(usage.rounded(toPlaces: 2)))%")
                            .fontWeight(.light)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        
                    }
                    
                }
            }
            .sheet(isPresented: $showingDetail) {
                GlobalStatsSpreadDetail(stats: stats, nature: nature, usage: usage, pokemon: pokemon, rankName: rankName)
            }
            
        } else {
            
            ZStack {
                
                DonutChart(dataModel: ChartDataModel.init(dataModel: otherStatModel), onTap: {
                        dataModel in
                        if let dataModel = dataModel {
                            self.selectedDonut = "Subject: \(dataModel.name)\nPointes: \(dataModel.value)"
                        } else {
                            self.selectedDonut = ""
                        }
                    })
                .frame(width: 130, height: 130, alignment: .center)
                
                VStack {
                    
                    Text(nature)
                        .fontWeight(.bold)
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                    
                    Text("\(String(usage.rounded(toPlaces: 2)))%")
                        .fontWeight(.light)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                }
                
            }
            
        }
        
    }
}
