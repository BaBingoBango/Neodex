//
//  GlobalStats.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/27/21.
//

import SwiftUI

struct GlobalStats: View {
    
    // Variables
    @State var format: String = "gen8vgc2021series11" {
        didSet {
            updateUIFromNetwork()
        }
    }
    @State var minRating: String = "0" {
        didSet {
            updateUIFromNetwork()
        }
    }
    @State var showingFormatPicker = false
    @State var searchText = ""
    @State var selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())! { // Today's date minus 1 month
        didSet {
            updateUIFromNetwork()
        }
    }
    var formattedMonth: String {
        var start = String(Calendar.current.component(.month, from: selectedDate))
        if start.count == 1 {
            start = "0\(start)"
        }
        return start
    }
    @State var showingRatingSheet = false
    
    @State var rankings: [RankingsStat]? = nil
    @State var ratings: [Int]? = nil
    
    @State var updateOnAppear = true
    
    var body: some View {
        
        let dateBinding = Binding(
            get: { self.selectedDate },
            set: {
                print("Old value was \(self.selectedDate) and new date is \($0)")
                self.selectedDate = $0
                updateUIFromNetwork()
            }
        )
        
//        NavigationView {
            
            ScrollView {
                LazyVStack {
                    
                    HStack {
                        
                        Button(action: {
                            showingFormatPicker.toggle()
                        }) {
                            VStack(alignment: .leading) {
//                                Text("Format")
//                                    .fontWeight(.bold)
//                                    .foregroundColor(.primary)
//                                    .padding(.leading)
//                                    .offset(y: 5)
                                ZStack {
                                    Rectangle()
                                        .frame(height: 35)
                                        .foregroundColor(.secondary)
                                        .opacity(0.2)
                                        .cornerRadius(7)
                                    Text(format)
                                        .foregroundColor(.blue)
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .padding(.horizontal, 3)
//                                        .font(.system(size: 15))
                                }
                            }
                        }
                        .sheet(isPresented: $showingFormatPicker) {
                            StatsFormatPicker(format: $format, month: formattedMonth, year: String(Calendar.current.component(.year, from: selectedDate)), rankings: $rankings, ratings: $ratings, formattedMonth: formattedMonth, selectedDate: selectedDate, minRating: minRating)
                        }
                        
                        Button(action: {
                            if ratings != nil && ratings!.count >= 4 && Reachability.isConnectedToNetwork() {
                                showingRatingSheet.toggle()
                            }
                        }) {
                            ZStack {
                                Rectangle()
                                    .frame(height: 35)
                                    .foregroundColor(.secondary)
                                    .opacity(0.2)
                                    .cornerRadius(7)
                                Text("Rating \(minRating)+")
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
    //                                .font(.system(size: 15))
                            }
                        }
                        .actionSheet(isPresented: $showingRatingSheet) {
                            return ActionSheet(title: Text("Select minimum Showdown rating:"), buttons: [
                                .default(Text(String(ratings![0]))) { minRating = String(ratings![0]) },
                                .default(Text(String(ratings![1]))) { minRating = String(ratings![1]) },
                                .default(Text(String(ratings![2]))) { minRating = String(ratings![2]) },
                                .default(Text(String(ratings![3]))) { minRating = String(ratings![3]) },
                                .cancel()
                            ])
                        }
                        
                        DatePicker("", selection: dateBinding, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())

                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                    
                    // Search bar
                    SearchBar(text: $searchText, placeholder: "Search")
                        .padding(.bottom)
                        .padding(.horizontal, 5)
                    
                    // Try to get the rankings if the view hasn't already
//                    var rankings: [RankingsStat]? = nil
//                    if !hasConnectedToInternet {
//                        rankings = getRankingsData()
//                        hasConnectedToInternet = true
//                    }
                    
                    if rankings != nil && !rankings!.isEmpty && rankings![0].rank == -1 {
                        
                        // Bad URL error message
                        VStack {
                            Image(systemName: "square.stack.3d.up.slash")
                                .resizable()
                                .frame(width: 80, height: 68)
                                .foregroundColor(.secondary)
                            Text("No Results")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.top)
                            Text("There is no usage data avaliable for the selected battle format and month.")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 5)
                        }
                            .padding(.top, 50)
                        
                    } else if rankings != nil {
                        
                        // MARK: Rankings list UI
                        
                        ForEach(rankings!.filter({ self.searchText.isEmpty ? true : $0.name.lowercased().contains(self.searchText.lowercased()) }), id: \.name) { ranking in

                            NavigationLink(destination: StatsDetailView(pokemon: Pokemon.findPokemon(name: ranking.name), ranking: ranking, format: format, month: formattedMonth, year: String(Calendar.current.component(.year, from: selectedDate)), minRating: minRating)) {

                                PokemonStatOption(stat: ranking)

                            }

                        }
                        
                    } else {
                        
                        if !Reachability.isConnectedToNetwork() {
                            
                            // No Internet error message
                            VStack {
                                Image(systemName: "wifi.slash")
                                    .resizable()
                                    .frame(width: 80, height: 68)
                                    .foregroundColor(.secondary)
                                Text("Network Error")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .padding(.top)
                                Text("Please check that your device is connected to the Internet and try again.")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.top, 5)
                            }
                                .padding(.top, 50)
                            
                        } else {
                            
                            // If the URL is OK, the rankings object is nil, and there is a network connection, the data must be loading!
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding(.top, 25)

                        }
                        
                    }
            
                }
                .padding(.bottom)
                
                // MARK: Nav view settings
                .navigationBarTitle(Text("Global Stats"))
//            }
            
        }
            .onAppear {
                
                if updateOnAppear {
                    updateUIFromNetwork()
                    updateOnAppear = false
                }
                
            }
        
    }
    
    // MARK: Functions
    func updateUIFromNetwork() {
        DispatchQueue.main.async {
            rankings = getRankingsData()
            ratings = getFormatOptions()
        }
    }
    func getFormatOptions() -> [Int]? {
        
        // Prepare a link from the user's input
        let link = "https://www.smogon.com/stats/\(String(Calendar.current.component(.year, from: selectedDate)))-\(formattedMonth)/"
        
        // Attempt to connect to the network and get the weboage using the prepared link
        let webpage = getURLContents(link: link)
        
        // If the file could not be retrieved, return nil
        var answer: [Int] = []
        
        if webpage == nil {
            return nil
        } else {
            
            // Get the ratings
            
            let lines = webpage!.components(separatedBy: .newlines)
            
            for eachLine in lines {
                
                if eachLine.contains("\(format)-") {
                    
                    answer.append(Int(eachLine.components(separatedBy: "\(format)-")[1].components(separatedBy: ".txt")[0])!)
                    
                }
                
            }
            
        }
        
        // Return
        return answer
    }
    func getRankingsData() -> [RankingsStat]? {
        
        // Prepare a link from the user's input
        let link = "https://www.smogon.com/stats/\(String(Calendar.current.component(.year, from: selectedDate)))-\(formattedMonth)/\(format)-\(minRating).txt"
        
        // Attempt to connect to the network and get the rankings using the prepared link
        let textFile = getURLContents(link: link)
        
        // If the rankings file could not be retrieved, return nil
        if textFile == nil {
            return nil
        } else if textFile == "BADURL" {
            return [RankingsStat(rank: -1, name: "", usage: -1.0)]
        } else {
            
            // If the rankings file was retrieved, parse it into RankingsStat objects and place them into an array
            var answer: [RankingsStat] = []
            let lines = textFile!.components(separatedBy: .newlines)
            for index in 0...(lines.count - 1) {
                if index >= 5 {
                    // Get the rank value
                    let rank = Int(String(lines[index].prefix(6).suffix(3)).trimmingCharacters(in: .whitespaces))
                    
                    // Get the name
                    let name = String(lines[index].prefix(29).suffix(19)).trimmingCharacters(in: .whitespaces)
                    
                    // Get the usage % value
                    let usagePercent = Double((String(lines[index].prefix(39).suffix(8)).trimmingCharacters(in: .whitespaces)))
                    
                    if rank != nil && usagePercent != nil {
                        // Add the new object to the array
                        answer.append(RankingsStat(rank: rank!, name: name, usage: usagePercent!))
                    }
                }
            }
            
            // Return the array
            return answer
            
        }
        
    }
    func getDetailData() {
        
    }
    
}

struct GlobalStats_Previews: PreviewProvider {
    static var previews: some View {
        GlobalStats()
    }
}

struct RankingsStat {
    
    // Variables
    var rank: Int
    var name: String
    var usage: Double
    
}
