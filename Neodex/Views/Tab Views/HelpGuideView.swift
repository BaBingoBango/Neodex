//
//  HelpGuideView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/2/21.
//

import SwiftUI

struct HelpGuideView: View {
    
    // Variables
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State var showingSettings = false
    @EnvironmentObject var sessionData: SessionData
    
    var body: some View {
            
//        NavigationView {
            
            ScrollView {
                VStack {
                    
                    ZStack {
                        Image(systemName: "book.closed.fill")
                            .resizable()
                            .frame(width: 80, height: 89)
                            .foregroundColor(.secondary)
                        Image(systemName: "questionmark")
                            .resizable()
                            .frame(width: 25, height: 33)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .offset(x: 5, y: -13)
                    }
                    .padding(.top)
                    
                    Text("Help Guide")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        
                        NavigationLink(destination: PokemonHelpGuide(text: "")) {
                            HelpGuideTopicButton(name: "Pokémon", imageName: "person.fill", color: .blue)
                        }
                        
                        HelpGuideTopicButton(name: "Abilties", imageName: "sparkles", color: .gold)
                        
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        
                        HelpGuideTopicButton(name: "Moves", imageName: "burst.fill", color: .red)
                        
                        HelpGuideTopicButton(name: "Types", imageName: "circle.grid.cross.fill", color: .psychic)
                        
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                }
                .padding(.vertical)
            }
            
            
            .navigationBarTitle(Text(""), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { self.showingSettings.toggle() }) { Image(systemName: "gearshape").imageScale(.large) }.sheet(isPresented: $showingSettings) { SettingsView(showingSettings: $showingSettings).environmentObject(sessionData) })
//        }
        
    }
}

struct HelpGuideView_Previews: PreviewProvider {
    static var previews: some View {
        HelpGuideView().environmentObject(SessionData())
    }
}

struct HelpGuideTopicButton: View {
    
    // Variables
    var name: String
    var imageName: String
    var color: Color
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .foregroundColor(.secondary)
                .frame(height: 200)
                .cornerRadius(15)
                .opacity(0.4)
            
            VStack {
                
                Text(name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Image(systemName: imageName)
                    .resizable()
                    .foregroundColor(color)
                    .frame(width: 70, height: 70, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                
            }
            
        }
        
    }
}

// MARK: Main Tab Help Guide View
struct HelpGuideTabView: View {
    
    // Variables
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
            
        NavigationView {
            
            ScrollView {
                VStack {
                    
                    ZStack {
                        Image(systemName: "book.closed.fill")
                            .resizable()
                            .frame(width: 80, height: 89)
                            .foregroundColor(.secondary)
                        Image(systemName: "questionmark")
                            .resizable()
                            .frame(width: 25, height: 33)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .offset(x: 5, y: -13)
                    }
                    .padding(.top)
                    
                    Text("Help Guide")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        
                        NavigationLink(destination: PokemonHelpGuide(text: "")) {
                            HelpGuideTopicButton(name: "Pokémon", imageName: "person.fill", color: .blue)
                        }
                        
                        HelpGuideTopicButton(name: "Abilties", imageName: "sparkles", color: .yellow)
                        
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        
                        HelpGuideTopicButton(name: "Moves", imageName: "burst.fill", color: .red)
                        
                        HelpGuideTopicButton(name: "Types", imageName: "circle.grid.cross.fill", color: .poison)
                        
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                }
                .padding(.vertical)
            }
            
            
            .navigationBarTitle(Text(""), displayMode: .inline)
        }
        
    }
}
