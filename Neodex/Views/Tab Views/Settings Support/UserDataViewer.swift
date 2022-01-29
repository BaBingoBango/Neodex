//
//  UserDataViewer.swift
//  Neodex
//
//  Created by Ethan Marshall on 6/9/21.
//

import SwiftUI

struct UserDataViewer: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        ScrollView {
            VStack {
                
                Image(systemName: "doc.on.doc.fill")
                    .resizable()
                    .foregroundColor(.blue)
                    .frame(width: 63, height: 75)
                
                Text("Your Neodex Data")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                ZStack {
                    
                    Rectangle()
                        .opacity(0.2)
                        .cornerRadius(15)
                        .foregroundColor(.yellow)
                        .frame(height: 170)
                    
                    VStack {
                        
                        HStack {
                            Text("Note")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding([.top, .leading])
                                .foregroundColor(.yellow)
                            Spacer()
                        }
                        
                        HStack {
                            Text("All of your data for Neodex is stored on your device and is never transmitted anywhere for tracking, analysis, or storage.")
                                .fontWeight(.regular)
                                .padding(.horizontal)
                            Spacer()
                        }
                        
                    }
                    .padding(.bottom)
                    
                }
                .padding(.horizontal)
                
                HStack {
                    Text("Preferences")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding([.top, .leading])
                    Spacer()
                }
                
                NavigationLink(destination: QADataViewer().environmentObject(sessionData)) {
                    DataViewerOption(text: "Quick Access Bar")
                }
                
                HStack {
                    Text("Save Data")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding([.top, .leading])
                    Spacer()
                }
                
                NavigationLink(destination: TeamDataBrowser()) {
                    DataViewerOption(text: "Teambuilder Teams")
                }
                
                HStack {
                    Text("User Activity")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding([.top, .leading])
                    Spacer()
                }
                
                Group {
                    
                    NavigationLink(destination: BrowsingHistoryView(dataType: 1).navigationBarTitle(Text("Pokémon Browsing History")).environmentObject(sessionData)) {
                        DataViewerOption(text: "Pokémon Browsing History")
                    }
                    NavigationLink(destination: BrowsingHistoryView(dataType: 2).navigationBarTitle(Text("Ability Browsing History")).environmentObject(sessionData)) {
                        DataViewerOption(text: "Ability Browsing History")
                    }
                    NavigationLink(destination: BrowsingHistoryView(dataType: 3).navigationBarTitle(Text("Move Browsing History")).environmentObject(sessionData)) {
                        DataViewerOption(text: "Move Browsing History")
                    }
                    NavigationLink(destination: BrowsingHistoryView(dataType: 4).navigationBarTitle(Text("Item Browsing History")).environmentObject(sessionData)) {
                        DataViewerOption(text: "Item Browsing History")
                    }
                    
                }
                
            }
            .padding(.vertical)
        }
        
    }
}

struct UserDataViewer_Previews: PreviewProvider {
    static var previews: some View {
        UserDataViewer().environmentObject(SessionData())
    }
}

struct DataViewerOption: View {
    
    // Variables
    var text: String
    
    var body: some View {
        
        ZStack {
            Rectangle()
                .cornerRadius(15)
                .foregroundColor(.gray)
                .opacity(0.2)
                .frame(height: 50)
            HStack {
                Text(text)
                    .fontWeight(.regular)
                    .padding(.leading)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                    .padding(.trailing)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        
    }
    
}

struct QADataViewer: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        Form {
            ForEach(sessionData.tabs, id: \.self) { tab in
                Text(tab)
            }
        }
    }
}
