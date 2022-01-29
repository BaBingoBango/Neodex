//
//  TeamDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 2/1/21.
//

import SwiftUI
import Combine

struct TeamDetailView: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    var tIndex: Int
    @State var showingPokemonAdder = false
    @State var editingIndex = 0
    @State var activeSheet: ActiveSheet?
    @State var showingEditors = false
    @State private var showingExport = false
    @State var showingExportSheet = false
    @State var emergencyStorage: TeamMember = TeamMember(pokemon: pokemonDataList[0])
    
    // Enums
    enum ActiveSheet: Identifiable {
        case nameEditor, importer
        
        var id: Int {
            hashValue
        }
    }
    
    var body: some View {
            
        ScrollView {
            
            if showingEditors {
                
                VStack(alignment: .leading) {
                    
                    // MARK: Top circle buttons
                
                    HStack {
                        
                        TeambuilderCircleButton(tIndex: tIndex, editingIndex: $editingIndex, num: 0).environmentObject(sessionData)
                        
                        TeambuilderCircleButton(tIndex: tIndex, editingIndex: $editingIndex, num: 1).environmentObject(sessionData)
                        
                        TeambuilderCircleButton(tIndex: tIndex, editingIndex: $editingIndex, num: 2).environmentObject(sessionData)
                        
                        TeambuilderCircleButton(tIndex: tIndex, editingIndex: $editingIndex, num: 3).environmentObject(sessionData)
                        
                        TeambuilderCircleButton(tIndex: tIndex, editingIndex: $editingIndex, num: 4).environmentObject(sessionData)
                        
                        TeambuilderCircleButton(tIndex: tIndex, editingIndex: $editingIndex, num: 5).environmentObject(sessionData)
                        
                    }
                    .padding(.horizontal)
                    
                    // MARK: Editing area
                    
                    if editingIndex == 0 && sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members[0] != nil {
                        TeamMemberEditor(tIndex: tIndex, pIndex: 0)
                            .padding(.top)
                    }
                    if editingIndex == 1 && sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members[1] != nil {
                        TeamMemberEditor(tIndex: tIndex, pIndex: 1)
                            .padding(.top)
                    }
                    if editingIndex == 2 && sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members[2] != nil {
                        TeamMemberEditor(tIndex: tIndex, pIndex: 2)
                            .padding(.top)
                    }
                    if editingIndex == 3 && sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members[3] != nil {
                        TeamMemberEditor(tIndex: tIndex, pIndex: 3)
                            .padding(.top)
                    }
                    if editingIndex == 4 && sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members[4] != nil {
                        TeamMemberEditor(tIndex: tIndex, pIndex: 4)
                            .padding(.top)
                    }
                    if editingIndex == 5 && sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members[5] != nil {
                        TeamMemberEditor(tIndex: tIndex, pIndex: 5)
                            .padding(.top)
                    }
                    
                }
                
            } else {
                
                TeamDisplayer(tIndex: tIndex).environmentObject(sessionData)
                
            }
            
        }
        
        // MARK: Nav view settings
        
        .navigationBarTitle(sessionData.teams.count >= tIndex + 1 ? Text(sessionData.teams[tIndex].name) : Text(""))
        .navigationBarItems(trailing: HStack {
            
                            Button(action: { self.showingEditors.toggle() }) { Image(systemName: showingEditors ? "rectangle.on.rectangle.angled" : "pencil").imageScale(.large) }
                                .padding(.trailing, 5)
            
                            Menu {
                                
                                Button {
                                    activeSheet = .nameEditor
                                } label: {
                                    Label("Edit Team Name", systemImage: "signature")
                                }

                                Button {
                                    
                                    if showingEditors {
                                        showingExportSheet.toggle()
                                    } else {
                                        showTeamExportSheet()
                                    }
                                    
                                } label: {
                                    Label(showingEditors ? "Export" : "Export Team", systemImage: "square.and.arrow.up")
                                }
                                
                                if showingEditors {
                                    Button {
                                        activeSheet = .importer
                                        emergencyStorage = sessionData.teams[tIndex].members[editingIndex] ?? TeamMember(pokemon: pokemonDataList[0])
                                        sessionData.teams[tIndex].members[editingIndex] = nil
                                    } label: {
                                        Label("Import Pokémon", systemImage: "square.and.arrow.down")
                                    }
                                }
                                
                            } label: {
                                Label("", systemImage: "ellipsis.circle").imageScale(.large)
                            }
                            .actionSheet(isPresented: $showingExportSheet) {
                                ActionSheet(title: Text("What would you like to export?"), buttons: [
                                    .default(Text("Export \(sessionData.teams[tIndex].members[editingIndex]?.name ?? "Pokémon")")) { showTeamMemberExportSheet(pIndex: editingIndex) },
                                    .default(Text("Export Team")) { showTeamExportSheet() },
                                    .cancel()
                                ])
                            }
                            .sheet(item: $activeSheet) { item in
                                switch item {
                                case .nameEditor:
                                    TeamNameEditor(tIndex: tIndex, teamName: sessionData.teams[tIndex].name)
                                case .importer:
                                    TeamMemberImportView(tIndex: tIndex, pIndex: editingIndex, eStorage: emergencyStorage).environmentObject(sessionData)
                                }
                                
                                
                            }
            
            
        })
        
    }
    
    // Functions
    func showTeamExportSheet() {
        showingExport.toggle()
        let text = sessionData.teams[tIndex].export()
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true, completion: nil)
    }
    func showTeamMemberExportSheet(pIndex: Int) {
        showingExport.toggle()
        let text = sessionData.teams[tIndex].members[pIndex]!.export()
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true, completion: nil)
    }
    
}

struct TeamDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TeamDetailView(tIndex: 0).environmentObject(SessionData())
    }
}

struct GenderCircle: View {
    
    // Variables
    var gender: String
    
    var body: some View {
        
        ZStack {
            
            Circle()
                .frame(width: 35, height: 35)
                .foregroundColor(genderColorDelegator(gender: gender))
            
            if gender == "Male" {
                
                Text("♂")
                    .foregroundColor(Color.white)
                    .font(.system(size: 25))
                    .offset(x: 1)
                
            }
            
            if gender == "Female" {
                
                Text("♀")
                    .foregroundColor(Color.white)
                    .font(.system(size: 25))
                    .offset(x: 1)
                
            }
            
        }
        
    }
    
    
    // Functions
    func genderColorDelegator(gender: String) -> Color {
        
        if gender == "Male" {
            return .blue
        } else if gender == "Female" {
            return .red
        } else {
        return .gray
        }
        
    }
    
}

struct TeambuilderCircleButton: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    var tIndex: Int
    @State var showingMemberAdder = false
    @Binding var editingIndex: Int
    var num: Int
    @State var showingDeleteAlert = false
    
    var body: some View {
        
        // The second part of each if statement is to add a new pokemon (if there isn't one there already) - the first part shows the pokemon in that slot (if there is one there already)
        
        if sessionData.teams.count >= tIndex + 1 && sessionData.teams[tIndex].members[num] != nil {
            
            Button(action: {
                if editingIndex != num {
                    editingIndex = num
                } else {
                    // Show the deletion alert and proceed with deletion if accepted
                    showingDeleteAlert.toggle()
                }
            }) {
                ZStack {
                    
                    Circle()
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(editingIndex == num ? .blue: .secondary)
                        .layoutPriority(2)
                    
                    Image(uiImage: (UIImage(named: "\(sessionData.teams[tIndex].members[num]!.pokemon.name)-sprite")?.trimmingTransparentPixels())!)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .layoutPriority(1)
                        .padding(.all, 10)
//                        .frame(width: 40, height: 40)
                    
                }
                .alert(isPresented: $showingDeleteAlert) {
                        Alert(
                            title: Text("Remove \(sessionData.teams[tIndex].members[num]?.name ?? "Pokémon")?"),
                            message: Text("All entered data for this Pokémon will be lost."),
                            primaryButton: .destructive(Text("Remove")) {
                                sessionData.teams[tIndex].members[num] = nil
                            },
                            secondaryButton: .cancel()
                        )
                    }
            }
            .sheet(isPresented: $showingMemberAdder) {
                TeambuilderPokemonPicker(tIndex: tIndex, editingIndex: $editingIndex, memberIndex: num).environmentObject(sessionData)
            }
            
        } else {
            
            Button(action: {
                showingMemberAdder.toggle()
            }) {
                ZStack {
                    
                    Circle()
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "plus")
                        .imageScale(.large)
                        .foregroundColor(.primary)
                    
                }
            }
            .sheet(isPresented: $showingMemberAdder) {
                TeambuilderPokemonPicker(tIndex: tIndex, editingIndex: $editingIndex, memberIndex: num).environmentObject(sessionData)
            }
            
        }
        
    }
    
}
