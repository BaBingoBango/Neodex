//
//  PDVStatsAreaView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/11/20.
//

import SwiftUI

struct PDVStatsAreaView: View {
    
    // Variables
    var pokemon: Pokemon
    var BST: Int {
        var answer = 0
        for eachStat in pokemon.baseStats {
            answer += eachStat
        }
        return answer
    }
    @State var selectedPie: String = ""
    @State var selectedDonut: String = ""
    var statColors: [Color] = [.green, .orange, .steel, .psychic, .ground, .flying]
    var statModel: [ChartCellModel] {
        var answer: [ChartCellModel] = []
        for i in 0...5 {
            answer.append(ChartCellModel(color: statColors[i], value: CGFloat(pokemon.baseStats[i]), name: "Stat"))
        }
        return answer
    }
    
    var body: some View {
        
        GeometryReader { geo in
            HStack {
                
                ZStack {
                    
                    DonutChart(dataModel: ChartDataModel.init(dataModel: statModel), onTap: {
                            dataModel in
                            if let dataModel = dataModel {
                                self.selectedDonut = "Subject: \(dataModel.name)\nPointes: \(dataModel.value)"
                            } else {
                                self.selectedDonut = ""
                            }
                        })
    //                .frame(width: 175, height: 175, alignment: .center)
                    
                    VStack {
                        Text("TOTAL")
                            .foregroundColor(.primary)
                        Text(String(BST))
                            .font(.system(size: 30))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                }
                .padding(.leading)
                
                VStack {
                    
                    BaseStatRowView(label: "HP", num: pokemon.baseStats[0], color: .green)
                    BaseStatRowView(label: "Atk", num: pokemon.baseStats[1], color: .orange)
                    BaseStatRowView(label: "Def", num: pokemon.baseStats[2], color: .steel)
                    BaseStatRowView(label: "Sp. Atk", num: pokemon.baseStats[3], color: .psychic)
                    BaseStatRowView(label: "Sp. Def", num: pokemon.baseStats[4], color: .ground)
                    BaseStatRowView(label: "Speed", num: pokemon.baseStats[5], color: .flying)
                    
                }
                .padding(.trailing)
                
    //            Spacer()
    //
    //            Rectangle()
    //                .frame(height: 20)
    //
    //            VStack(alignment: .leading) {
    //                HStack {
    //                    Text("HP")
    //                        .font(.system(size: 19))
    //                        .fontWeight(.heavy)
    //                        .foregroundColor(.green)
    //                    Spacer()
    //                    Text(String(pokemon.baseStats[0]))
    //                        .font(.system(size: 19))
    //                        .foregroundColor(.primary)
    //
    //                }
    //                HStack {
    //                    Text("Atk")
    //                        .font(.system(size: 19))
    //                        .fontWeight(.heavy)
    //                        .foregroundColor(.orange)
    //                    Spacer()
    //                    Text(String(pokemon.baseStats[1]))
    //                        .font(.system(size: 19))
    //                        .foregroundColor(.primary)
    //                }
    //                HStack {
    //                    Text("Def")
    //                        .font(.system(size: 19))
    //                        .fontWeight(.heavy)
    //                        .foregroundColor(.steel)
    //                    Spacer()
    //                    Text(String(pokemon.baseStats[2]))
    //                        .font(.system(size: 19))
    //                        .foregroundColor(.primary)
    //                }
    //            }
    //            .frame(width: 70)
    //
    //            Spacer()
    //
    //            VStack(alignment: .leading) {
    //                HStack {
    //                    Text("Sp. Atk")
    //                        .font(.system(size: 19))
    //                        .fontWeight(.heavy)
    //                        .foregroundColor(.psychic)
    //                    Spacer()
    //                    Text(String(pokemon.baseStats[3]))
    //                        .font(.system(size: 19))
    //                        .foregroundColor(.primary)
    //                }
    //                HStack {
    //                    Text("Sp. Def")
    //                        .font(.system(size: 19))
    //                        .fontWeight(.heavy)
    //                        .foregroundColor(.ground)
    //                    Spacer()
    //                    Text(String(pokemon.baseStats[4]))
    //                        .font(.system(size: 19))
    //                        .foregroundColor(.primary)
    //                }
    //                HStack {
    //                    Text("Speed")
    //                        .font(.system(size: 19))
    //                        .fontWeight(.heavy)
    //                        .foregroundColor(.flying)
    //                    Spacer()
    //                    Text(String(pokemon.baseStats[5]))
    //                        .font(.system(size: 19))
    //                        .foregroundColor(.primary)
    //                }
    //            }
    //            .frame(width: 110)
                
            }
            .frame(height: geo.size.width / 2)
        }
        
    }
}

struct PDVStatsAreaView_Previews: PreviewProvider {
    static var previews: some View {
        PDVStatsAreaView(pokemon: Pokemon.theTestList()[2])
    }
}

struct PieChartCell: Shape {
    let startAngle: Angle
    let endAngle: Angle
   func path(in rect: CGRect) -> Path {
        let center = CGPoint.init(x: (rect.origin.x + rect.width)/2, y: (rect.origin.y + rect.height)/2)
    let radii = min(center.x, center.y)
        let path = Path { p in
            p.addArc(center: center,
                     radius: radii,
                     startAngle: startAngle,
                     endAngle: endAngle,
                     clockwise: true)
            p.addLine(to: center)
        }
        return path
   }
}

struct InnerCircle: Shape {
    let ratio: CGFloat
    func path(in rect: CGRect) -> Path {
         let center = CGPoint.init(x: (rect.origin.x + rect.width)/2, y: (rect.origin.y + rect.height)/2)
        let radii = min(center.x, center.y) * ratio + 20
         let path = Path { p in
             p.addArc(center: center,
                      radius: radii,
                      startAngle: Angle(degrees: 0),
                      endAngle: Angle(degrees: 360),
                      clockwise: true)
             p.addLine(to: center)
         }
        return path
    }
}

struct DonutChart: View {
    @State private var selectedCell: UUID = UUID()
    @Environment(\.colorScheme) var colorScheme
    var displayColor: Color {
        if colorScheme == .dark {
            return .black
        } else {
            return .white
        }
    }
    
    let dataModel: ChartDataModel
    let onTap: (ChartCellModel?) -> ()
    var body: some View {
            ZStack {
                PieChart(dataModel: dataModel, onTap: onTap)
                InnerCircle(ratio: 1/3).foregroundColor(displayColor)
            }
    }
}

struct PieChart: View {
    @State private var selectedCell: UUID = UUID()
    
    let dataModel: ChartDataModel
    let onTap: (ChartCellModel?) -> ()
    var body: some View {
            ZStack {
                ForEach(dataModel.chartCellModel) { dataSet in
                    PieChartCell(startAngle: self.dataModel.angle(for: dataSet.value), endAngle: self.dataModel.startingAngle)
                        .foregroundColor(dataSet.color)
//                       .onTapGesture {
//                         withAnimation {
//                            if self.selectedCell == dataSet.id {
//                                self.onTap(nil)
//                                self.selectedCell = UUID()
//                            } else {
//                                self.selectedCell = dataSet.id
//                                self.onTap(dataSet)
//                            }
//                        }
//                    }
                       .scaleEffect((self.selectedCell == dataSet.id) ? 1.05 : 1.0)
                }
            }
    }
}

struct ChartCellModel: Identifiable {
    let id = UUID()
    let color: Color
    let value: CGFloat
    let name: String
}

final class ChartDataModel: ObservableObject {
    var chartCellModel: [ChartCellModel]
    var startingAngle = Angle(degrees: 0)
    private var lastBarEndAngle = Angle(degrees: 0)
    
        
    init(dataModel: [ChartCellModel]) {
        chartCellModel = dataModel
    }
    
    var totalValue: CGFloat {
        chartCellModel.reduce(CGFloat(0)) { (result, data) -> CGFloat in
            result + data.value
        }
    }
    
    func angle(for value: CGFloat) -> Angle {
        if startingAngle != lastBarEndAngle {
            startingAngle = lastBarEndAngle
        }
        lastBarEndAngle += Angle(degrees: Double(value / totalValue) * 360 )
//        print(lastBarEndAngle.degrees)
        return lastBarEndAngle
    }
}

let sample = [ ChartCellModel(color: Color.red, value: 123, name: "Math"),
               ChartCellModel(color: Color.yellow, value: 233, name: "Physics"),
               ChartCellModel(color: Color.pink, value: 73, name: "Chemistry"),
               ChartCellModel(color: Color.blue, value: 731, name: "Litrature"),
               ChartCellModel(color: Color.green, value: 51, name: "Art")]

struct BaseStatRowView: View {
    var label: String
    var num: Int
    var color: Color
    var body: some View {
        ZStack {
            Rectangle()
//                .frame(height: 25)
                .foregroundColor(color)
                .opacity(0.3)
            HStack {
                Text(label)
                    .fontWeight(.heavy)
                    .foregroundColor(color)
                    .padding(.leading, 5)
                Spacer()
                Text(String(num))
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .padding(.trailing)
            }
        }
    }
}
