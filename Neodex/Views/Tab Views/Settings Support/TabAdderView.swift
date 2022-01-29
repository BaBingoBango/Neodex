//
//  TabAdderView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/3/21.
//

import SwiftUI

struct TabAdderView: View {
    
    // Variables
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    
                    if !sessionData.tabs.contains("Home") {
                        TabAdderButton(prez: presentationMode, name: "Home", imageName: "house.fill", desc: "Access all the app's main features from a single screen.", color: .primary).environmentObject(sessionData)
                    }
                    
                    if !sessionData.tabs.contains("Search") {
                        TabAdderButton(prez: presentationMode, name: "Search", imageName: "magnifyingglass", desc: "Search for Pokémon, moves, items, Abilities, types, and Natures all from a single screen.", color: .fairy).environmentObject(sessionData)
                    }
                    
                    if !sessionData.tabs.contains("Pokédex") {
                        TabAdderButton(prez: presentationMode, name: "Pokédex", imageName: "person.fill", desc: "View every Pokémon in a list or grid, and access detailed information about each one.", color: .blue).environmentObject(sessionData)
                    }
                    
                    if !sessionData.tabs.contains("Ability Dex") {
                        TabAdderButton(prez: presentationMode, name: "Ability Dex", imageName: "sparkles", desc: "View details about every Ability and see which Pokémon are compatible.", color: .gold).environmentObject(sessionData)
                    }
                    
                    if !sessionData.tabs.contains("Move Dex") {
                        TabAdderButton(prez: presentationMode, name: "Move Dex", imageName: "burst.fill", desc: "View information about every Pokémon move and see which Pokémon can learn them.", color: .red).environmentObject(sessionData)
                    }
                    
                    if !sessionData.tabs.contains("Item Dex") {
                        TabAdderButton(prez: presentationMode, name: "Item Dex", imageName: "cube.fill", desc: "View details about every item and see which Pokémon evolve after using them.", color: .flying).environmentObject(sessionData)
                    }
                    
                    if !sessionData.tabs.contains("Type-O-Matic") {
                        TabAdderButton(prez: presentationMode, name: "Type-O-Matic", imageName: "circle.grid.cross.fill", desc: "Check attack and defense information for single and dual types with juat a few taps.", color: .psychic).environmentObject(sessionData)
                    }
                    
                    if !sessionData.tabs.contains("Explore") {
                        TabAdderButton(prez: presentationMode, name: "Explore", imageName: "wand.and.stars", desc: "Explore new Pokémon, abilites, moves, and items popular worldwide and reccomended just for you.", color: .bronze).environmentObject(sessionData)
                    }
                    
                    if !sessionData.tabs.contains("Teambuilder") {
                        TabAdderButton(prez: presentationMode, name: "Teambuilder", imageName: "rectangle.stack.person.crop.fill", desc: "Create the perfect Pokémon teams by choosing items, moves, stats, and more.", color: .ice).environmentObject(sessionData)
                    }
                    
                    
                    VStack {
                        
                        if !sessionData.tabs.contains("Face-Off") {
                            TabAdderButton(prez: presentationMode, name: "Face-Off", imageName: "bolt.circle.fill", desc: "Pit two Pokémon against each other to compare their stats, abilities, and characteristics.", color: .dragon).environmentObject(sessionData)
                        }
                        
                        if !sessionData.tabs.contains("Dex Quests") {
                            TabAdderButton(prez: presentationMode, name: "Dex Quests", imageName: "map.fill", desc: "Track and monitor progress on completing regional Pokédexes and the National Dex.", color: .ground).environmentObject(sessionData)
                        }
                        
                        if !sessionData.tabs.contains("Nature Checker") {
                            TabAdderButton(prez: presentationMode, name: "Nature Checker", imageName: "leaf.fill", desc: "Check details of the various Pokémon Natures and how they affect a Pokémon's stats.", color: .green).environmentObject(sessionData)
                        }
                        
                        if !sessionData.tabs.contains("Global Stats") {
                            TabAdderButton(prez: presentationMode, name: "Global Stats", imageName: "network", desc: "View the most popular Pokémon, items, moves, and more from the Pokémon Showdown battle simulator.", color: .blue).environmentObject(sessionData)
                        }
                        
                        if !sessionData.tabs.contains("Help Guide") {
                            TabAdderButton(prez: presentationMode, name: "Help Guide", imageName: "questionmark.circle.fill", desc: "Explore various topics to read and learn more about how the Pokémon world works.", color: .gray).environmentObject(sessionData)
                        }
                        
                    }
                    
                }
            }
            
            
            .navigationBarTitle(Text("Add Quick Access Tab"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
            })
        }
        
    }
}

struct TabAdderButton: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    var prez: Binding<PresentationMode>
    var name: String
    var imageName: String
    var desc: String
    var color: Color
    
    var body: some View {
        
        Button(action: {
            // Add the tab to the tab list and dismiss the modal
            sessionData.tabs.append(name)
            prez.wrappedValue.dismiss()
            
        }) {
        TabAdderOption(imageName: imageName, color: color, name: name, desc: desc)
            .padding(.top)
        }
        
    }
    
}

struct TabAdderOption: View {
    
    // Variables
    var imageName: String
    var color: Color
    var name: String
    var desc: String
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .foregroundColor(.secondary)
                .frame(height: 120)
                .opacity(0.3)
                .cornerRadius(15)
                .padding(.horizontal)
            
            HStack {
                
                Image(systemName: imageName)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(color)
                
                VStack(alignment: .leading) {
                    
                    Text(name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(desc)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .padding(.bottom, 7)
                        .minimumScaleFactor(0.5)
                    
                    Spacer()
                    
                }
                .padding([.top, .leading, .trailing])
                
                Spacer()
                
            }
            .padding(.leading, 30)
            
        }
        .padding(.bottom)
        
    }
    
}
