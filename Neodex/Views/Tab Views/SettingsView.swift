//
//  SettingsView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/2/21.
//

import SwiftUI

struct SettingsView: View {
    
    // Variables
    @State var persistSorting = false
    @State var persistFilters = false
    @State var unitIndex = 0
    @State var gridAndListIndex = 0
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    @Binding var showingSettings: Bool
    var usePrez = false
    
    var unitOptions = ["ft / lbs", "m / kg"]
    var gridAndList = ["List", "Grid"]
    
    var body: some View {
        
        NavigationView {
            
            Form {
                
                Section(header: Text("CUSTOMIZATION")) {
                    
                    NavigationLink(destination: TabEditorView().environmentObject(sessionData)) {
                        Text("Quick Access Tabs")
                    }
                    
                }
                
                Section(header: Text("Pokédex".uppercased()), footer: Text("Enabling persistance will preserve selected options even after the app is closed.")) {
                    
                    Picker(selection: $unitIndex, label: Text("Default Units")) {
                            ForEach(0 ..< unitOptions.count) {
                                Text(self.unitOptions[$0])
                            }
                        }
                    
                    Picker(selection: $gridAndListIndex, label: Text("Default View")) {
                        ForEach(0 ..< gridAndList.count) {
                            Text(self.gridAndList[$0])
                        }
                    }
                    
                    Toggle(isOn: $persistSorting) {
                        Text("Persist Sorting")
                    }
                    
                    Toggle(isOn: $persistFilters) {
                        Text("Persist Filters")
                    }
                    
                }
                
                Section(header: Text("SPOTLIGHT"), footer: Text("Enabling the above will include the selected data in the system Spotlight search.")) {
                    
                    if !workingOnPokemonSP {
                        Toggle(isOn: $sessionData.userRecords.hasIndexedPokemon) {
                            Text("Include Pokémon")
                        }
                    } else {
                        ProgressView()
                    }
                    if !workingOnMovesSP {
                        Toggle(isOn: $sessionData.userRecords.hasIndexedMoves) {
                            Text("Include Moves")
                        }
                    } else {
                        ProgressView()
                    }
                    if !workingOnAbilitiesSP {
                        Toggle(isOn: $sessionData.userRecords.hasIndexedAbilities) {
                            Text("Include Abilities")
                        }
                    } else {
                        ProgressView()
                    }
                    if !workingOnNaturesSP {
                        Toggle(isOn: $sessionData.userRecords.hasIndexedNatures) {
                            Text("Include Natures")
                        }
                    } else {
                        ProgressView()
                    }
                    if !workingOnItemsSP {
                        Toggle(isOn: $sessionData.userRecords.hasIndexedItems) {
                            Text("Include Items")
                        }
                    } else {
                        ProgressView()
                    }
                    
                }
                
                Section(header: Text("PRIVACY")) {
                    
                    NavigationLink(destination: UserDataViewer().environmentObject(sessionData).navigationBarTitle("", displayMode: .inline)) {
                        Text("View User Data")
                    }
                    
                }
                
                Section(header: Text("ABOUT")) {
                    
                    HStack {
                        Text("Version Name")
                        Spacer()
                        Text("Beta Version A")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Version Number")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build Number")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                    
                }
                
            }
            
            .navigationBarTitle(Text("Settings"))
            .navigationBarItems(leading: HStack {
                Spacer()
                Image(systemName: "chevron.compact.down").foregroundColor(.secondary).imageScale(.large).scaleEffect(2)
                Spacer()
            }.frame(width: UIScreen.screenWidth))
//            .navigationBarItems(trailing: Button(action: {
//                if usePrez {
//                    self.presentationMode.wrappedValue.dismiss()
//                }
//                self.showingSettings.toggle()
//            }) {
//                Text("Done")
//            })
        }
        
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView( showingSettings: .constant(true)).environmentObject(SessionData())
    }
}

var workingOnPokemonSP = false
var workingOnMovesSP = false
var workingOnAbilitiesSP = false
var workingOnNaturesSP = false
var workingOnItemsSP = false
