//
//  NatureGuide.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/26/21.
//

import SwiftUI

struct NatureGuide: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @State var searchText: String = ""
    @State var showingFilters = false
    var numberOfFiltersOn: Int {
        var answer = 0
        answer += plusFilters.count
        answer += minusFilters.count
        answer += likesFilters.count
        answer += dislikesFilters.count
        answer += confusingBerryFilters.count
        return answer
    }
    private var filterResults: Binding<Int> { Binding (
        get: { return filterNatures().count },
        set: { _ in }
        )
    }
    @State var showingHelp = false
    @State var showingSettings = false
    
    // Filter variables
    @State var plusFilters: [String] = []
    @State var minusFilters: [String] = []
    @State var likesFilters: [String] = []
    @State var dislikesFilters: [String] = []
    @State var confusingBerryFilters: [String] = []
    
    var body: some View {
        
        let chunkedNatures = filterNatures().filter {
            self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased())
        }.chunked(into: 2)
        
//        NavigationView {
            
            ScrollView {
                VStack {
                    
                    SearchBar(text: $searchText)
                        .padding(.bottom)
                    
                    Button(action: {
                        showingFilters.toggle()
                    }) {
                        DexEditButton(imageName: "line.horizontal.3.decrease.circle", name: numberOfFiltersOn >= 1 ? (numberOfFiltersOn == 1 ? "1 Filter On" : "\(numberOfFiltersOn) Filters On") : "Filter", backColor: numberOfFiltersOn >= 1 ? .blue : .secondary, frontColor: numberOfFiltersOn >= 1 ? .white : .black)
                    }
                    .padding([.leading, .bottom, .trailing])
                    .sheet(isPresented: $showingFilters) {
                        NatureFilterView(plusFilters: $plusFilters, minusFilters: $minusFilters, likesFilters: $likesFilters, dislikesFilters: $dislikesFilters, confusingBerryFilters: $confusingBerryFilters, filterResults: filterResults)
                    }
                    
                    ForEach(0..<chunkedNatures.count) { index in
                        
                        if (index <= (chunkedNatures.count - 1)) {
                            
                            HStack {
                                
                                NatureRowView(chunkedNatures: chunkedNatures, index: index)
                                
                            
                            }
                            
                        }
                        
                    }
            
                }
                .padding(.vertical)
        
            }
            
            .navigationBarTitle(Text("Natures"))
            .navigationBarItems(trailing: HStack {
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
                        Text("Nature help guide! :)")
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
            })
            
//        }
    }
    
    // Functions
    func filterNatures() -> [Nature] {
        
        var answer = Nature.natureList
        
        // 1: Increased stat
        if plusFilters.count >= 1 {
            answer = answer.filter({
                $0.plus == plusFilters[0]
            })
        }
        
        // 2: Decreased stat
        if minusFilters.count >= 1 {
            answer = answer.filter({
                $0.minus == minusFilters[0]
            })
        }
        
        // 3: Likes
        if likesFilters.count >= 1 {
            answer = answer.filter({
                $0.berryPlus == likesFilters[0]
            })
        }
        
        // 4: Dislikes
        if dislikesFilters.count >= 1 {
            answer = answer.filter({
                $0.berryMinus == dislikesFilters[0]
            })
        }
        
        // 5: Confusing berry
        if confusingBerryFilters.count >= 1 {
            answer = answer.filter({
                $0.confusingBerry == confusingBerryFilters[0]
            })
        }
        
        return answer
        
    }
    
}

struct NatureGuide_Previews: PreviewProvider {
    static var previews: some View {
        NatureGuide().environmentObject(SessionData())
            
            
    }
}

struct NatureOption: View {
    
    // Variables
    var nature: Nature
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .cornerRadius(10)
                .padding(.horizontal, 11)
                .frame(height: 70)
                .shadow(color: .gray, radius: 15)
            
            HStack {
                
                VStack(alignment: .center) {
                    
                    Text(nature.name)
                        .foregroundColor(.primary)
                        .font(.system(size: 23))
                        .fontWeight(.bold)
                        .padding(.trailing, 20)
                        .offset(y: 5)
                    
                    HStack {
                        
                        ZStack {
                            Rectangle()
                                .cornerRadius(10)
                                .frame(height: 20)
                                .foregroundColor(nature.plus != nature.minus ? .green : .gray)
                            Text(nature.plus == "Defense" && UIDevice.modelName.contains("iPod") ? "DEF" : nature.plus.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        
                        ZStack {
                            Rectangle()
                                .cornerRadius(10)
                                .frame(height: 20)
                                .foregroundColor(nature.plus != nature.minus ? .red : .gray)
                            Text(nature.minus == "Defense" && UIDevice.modelName.contains("iPod") ? "DEF" : nature.minus.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        
                    }
                    .padding(.trailing)
                    .offset(y: -5)
                    
                }
                
                Spacer()
                
            }
            .padding(.leading, 30)
            
        }
        
    }
}

struct NatureRowView: View {
    
    // Variables
    var chunkedNatures: [[Nature]]
    var index: Int
    
    var body: some View {
        
        ForEach(chunkedNatures[index], id: \.name) { nature in
            
            NavigationLink(destination: NatureDetailView(nature: nature)) {
                NatureOption(nature: nature)
                    .padding(.bottom, 5)
                    .offset(x: (chunkedNatures[index].firstIndex(where: { $0.name == nature.name }) == 0) ? 8 : -8)
            }
            
            if chunkedNatures[index].count == 1 {
                
                NatureOption(nature: nature)
                    .padding(.bottom, 5)
                    .offset(x: (chunkedNatures[index].firstIndex(where: { $0.name == nature.name }) == 0) ? 8 : -8)
                    .hidden()
                
            }
                
        }
        
    }
    
}
