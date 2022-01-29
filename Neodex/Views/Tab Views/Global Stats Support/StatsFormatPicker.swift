//
//  StatsFormatPicker.swift
//  Neodex
//
//  Created by Ethan Marshall on 3/1/21.
//

import SwiftUI

struct StatsFormatPicker: View {
    
    // Variables
    @Binding var format: String
    var month: String
    var year: String
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var rankings: [RankingsStat]?
    @Binding var ratings: [Int]?
    var formattedMonth: String
    var selectedDate: Date
    var minRating: String
    
    var body: some View {
        
        let formats = getFormatList()
        
        NavigationView {
            
            if formats != nil && !formats!.isEmpty {
                
                Form {
                    
                    ForEach(formats!, id: \.self) { format in
                        
                        Button(action: {
                            self.format = format
                            updateUIFromNetwork()
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text(format)
                                .foregroundColor(.primary)
                        }
                        
                    }
                    
                }
                
                // MARK: Nav view settings 1
                .navigationBarTitle(Text("Formats for \(month)-\(year)"), displayMode: .inline)
                .navigationBarItems(leading: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel") })
                
            } else {
                
                if !Reachability.isConnectedToNetwork() {
                    
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
                    // MARK: Nav view settings 2
                    .navigationBarTitle(Text("Select Showdown Format"), displayMode: .inline)
                    .navigationBarItems(leading: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel") })
                    
                } else {
                    
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
//                    .padding(.top, 50)
                    // MARK: Nav view settings 2
                    .navigationBarTitle(Text("Select Showdown Format"), displayMode: .inline)
                    .navigationBarItems(leading: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Cancel") })
                    
                }
                
            }
            
        }
        
    }
    
    func getFormatList() -> [String]? {
        
        // Create the link
        let link = "https://www.smogon.com/stats/\(year)-\(month)/"
        
        // Attempt to connect to the network and get the rankings using the prepared link
        let textFile = getURLContents(link: link)
        
        // If there's an error, return nil
        if textFile == nil {
            return nil
        } else {
            
            // Otherwise, parse and return
            var answer: [String] = []
            let lines = textFile!.components(separatedBy: .newlines)
            
            for index in 0...(lines.count - 1) {
                
                if lines[index].contains(".txt") {
                    let split = lines[index].components(separatedBy: ".txt")[0].components(separatedBy: "-")[0].components(separatedBy: "=\"")[1]
                    if !answer.contains(split) {
                        answer.append(split)
                    }
                }
                
            }
            
            return answer
            
        }
        
    }
    
    // MARK: Functions
    func updateUIFromNetwork() {
        rankings = getRankingsData()
        ratings = getFormatOptions()
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
    
}

//struct StatsFormatPicker_Previews: PreviewProvider {
//    static var previews: some View {
//        StatsFormatPicker(format: "gen8vgc2020", month: "05", year: "2020")
//    }
//}
