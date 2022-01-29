//
//  Teambuilder.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/8/21.
//

import SwiftUI

struct Teambuilder: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @State private var editMode = EditMode.inactive
    @State var activeSheet: ActiveSheet?
    @State var settings = false
    
    // Enumerations
    enum ActiveSheet: Identifiable {
        case export, help, settings
        
        var id: Int {
            hashValue
        }
    }
    
    var body: some View {
            
        ZStack {
                
            if sessionData.teams.isEmpty {

                VStack {
                    Text("No Teams")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Tap + to create a new team or import one from Pokémon Showdown in the ⋯ menu!")
                        .multilineTextAlignment(.center)
                        .padding(.top, 1)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
            } else {
                
                List {
                    ForEach(sessionData.teams) { team in
                        
                        TeamListOption(tIndex: sessionData.teams.firstIndex(where: { $0.id == team.id })!)
                        
                    }
                    .onDelete(perform: onDelete)
                    .onMove(perform: onMove)
                }
                .listStyle(PlainListStyle())
                
            }
            
        }
            
            // MARK: Nav view settings
            .navigationBarTitle(Text("Teambuilder"))
            .navigationBarItems(trailing: TeambuilderTrailingNavButtons)
            
            .environment(\.editMode, $editMode)
            
        
    }
    
    var TeambuilderTrailingNavButtons: some View {
        
        HStack {
            
            if editMode == .inactive {
                
                Menu {
                    if !sessionData.teams.isEmpty {
                        EditButton()
                    }
                    Button {
                        activeSheet = .export
                    } label: {
                        Label("Import Team", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        activeSheet = .help
                    } label: {
                        Label("Teambuilder Help", systemImage: "questionmark.circle")
                    }
                    Button {
                        activeSheet = .settings
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Label("", systemImage: "ellipsis.circle").imageScale(.large)
                }
                .sheet(item: $activeSheet) { item in
                    switch item {
                    case .export:
                        TeamImportView().environmentObject(sessionData)
                    case .help:
                        Text("Help!")
                    case .settings:
                        SettingsView(showingSettings: $settings, usePrez: true).environmentObject(sessionData)
                    }
                }
                
                Button(action: {
                    
                    // Find the highest "New Team x" team
                    var highestNewTeam = -1
                    for eachTeam in sessionData.teams {
                        
                        if eachTeam.name.contains("New Team") && Int(eachTeam.name.suffix(1)) != nil {
                            
                            if Int(eachTeam.name.suffix(1))! > highestNewTeam {
                                
                                highestNewTeam = Int(eachTeam.name.suffix(1))!
                                
                            }
                            
                        } else if eachTeam.name == "New Team" && highestNewTeam == -1 {
                            highestNewTeam = 0
                        }
                        
                    }
                    
                    // Set the team's name
                    var newName = ""
                    if highestNewTeam == -1 {
                        newName = "New Team"
                    } else {
                        newName = "New Team \(highestNewTeam + 1)"
                    }
                    
                    // Add a new team
                    sessionData.teams.insert(Team(name: newName, members: [nil, nil, nil, nil, nil, nil]), at: 0)
                    
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
                
//                Button(action: {
//                    showingSettings.toggle()
//                }) {
//                    Image(systemName: "gearshape")
//                        .foregroundColor(.blue)
//                        .imageScale(.large)
//                }
//                .sheet(isPresented: $showingSettings) {
//                    SettingsView(showingSettings: $showingSettings).environmentObject(sessionData)
//                }
                
            } else {
                
                EditButton()
                
            }
        }
        
    }
    
    // MARK: Functions
    private func onDelete(offsets: IndexSet) {
        sessionData.teams.remove(atOffsets: offsets)
    }
    
    private func onMove(source: IndexSet, destination: Int) {
        sessionData.teams.move(fromOffsets: source, toOffset: destination)
    }
    
}

struct Teambuilder_Previews: PreviewProvider {
    static var previews: some View {
        Teambuilder().environmentObject(SessionData())
    }
}

struct TeamListOption: View {
    
    // Variables
    var tIndex: Int
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        if sessionData.teams.indices.contains(tIndex) {
            NavigationLink(destination: TeamDetailView(tIndex: tIndex)) {
                HStack {
                    
                    VStack(alignment: .leading, spacing: 5) {
                        
                        Text(sessionData.teams[tIndex].name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        HStack {
                            
                            if sessionData.teams[tIndex].members[0] != nil {
                                Image(uiImage: UIImage(named: "\(sessionData.teams[tIndex].members[0]!.pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .padding(.all, 3.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image("Poké Ball")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                            }
                            
                            if sessionData.teams[tIndex].members[1] != nil {
                                Image(uiImage: UIImage(named: "\(sessionData.teams[tIndex].members[1]!.pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .padding(.all, 3.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image("Poké Ball")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                            }
                            
                            if sessionData.teams[tIndex].members[2] != nil {
                                Image(uiImage: UIImage(named: "\(sessionData.teams[tIndex].members[2]!.pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .padding(.all, 3.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image("Poké Ball")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                            }
                            
                            if sessionData.teams[tIndex].members[3] != nil {
                                Image(uiImage: UIImage(named: "\(sessionData.teams[tIndex].members[3]!.pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .padding(.all, 3.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image("Poké Ball")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                            }
                            
                            if sessionData.teams[tIndex].members[4] != nil {
                                Image(uiImage: UIImage(named: "\(sessionData.teams[tIndex].members[4]!.pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .padding(.all, 3.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image("Poké Ball")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                            }
                            
                            if sessionData.teams[tIndex].members[5] != nil {
                                Image(uiImage: UIImage(named: "\(sessionData.teams[tIndex].members[5]!.pokemon.name)-sprite")!.trimmingTransparentPixels()!)
                                    .resizable()
                                    .padding(.all, 3.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image("Poké Ball")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                            }
                            
                        }
                        
                    }
                    
    //                Spacer()
    //
    //                Image(systemName: "chevron.right")
    //                    .foregroundColor(.secondary)
    //                    .padding(.trailing)
                    
                }
                .padding(.leading)
            }
        }
        
    }
    
}
