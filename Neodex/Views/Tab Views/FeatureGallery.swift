//
//  FeatureGallery.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/4/21.
//

import SwiftUI

struct FeatureGallery: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
    @State var showingSettings: Bool = false
    @State var showingGrid = false
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    
                    if !showingGrid {
                        
                        HStack(spacing: 12) {
                            
                            VStack {
                                
                                NavigationLink(destination: PokedexView().environmentObject(sessionData)) {
                                    FeatureGalleryBigSquare(color: .blue, text: "Pokédex", imageName: "person.fill")
                                }
                                    .padding(.bottom)
                                
                                NavigationLink(destination: SearchTabView().environmentObject(sessionData)) {
                                    FeatureGalleryBigSquare(color: .fairy, text: "Search", imageName: "magnifyingglass")
                                }
                                
                            }
                            
                            VStack {
                                
                                NavigationLink(destination: AbilityDexView().environmentObject(sessionData)) {
                                    FeatureGalleryOption(color: .gold, text: "Ability Dex", imageName: "sparkles")
                                }
//                                    .padding(.leading, 5)
                                    .padding(.bottom)
                                
                                NavigationLink(destination: MoveDexView().environmentObject(sessionData)) {
                                    FeatureGalleryOption(color: .red, text: "Move Dex", imageName: "burst.fill")
                                }
//                                    .padding(.leading, 5)
                                    .padding(.bottom)
                                
                                NavigationLink(destination: ItemDexView().environmentObject(sessionData)) {
                                    FeatureGalleryOption(color: .flying, text: "Item Dex", imageName: "cube.fill")
                                }
//                                    .padding(.leading, 5)
                                
                            }
                            .padding(.leading, 4.5)
                            
                        }
                        .padding(.leading)
                        
                    } else {
                        
                        HStack(spacing: 12) {
                            
                            NavigationLink(destination: PokedexView().environmentObject(sessionData)) {
                                FeatureGalleryBigSquare(color: .blue, text: "Pokédex", imageName: "person.fill")
                            }
                                .padding(.bottom)
                            
                            NavigationLink(destination: SearchTabView().environmentObject(sessionData)) {
                                FeatureGalleryBigSquare(color: .fairy, text: "Search", imageName: "magnifyingglass")
                            }
                            .padding(.bottom)
                            .padding(.trailing)
                            
                        }
                        .padding(.leading)
//                        .padding(.trailing)
                        
                    }
                    
                    if !showingGrid {
                        
                        NavigationLink(destination: TypeOMaticView().environmentObject(sessionData)) {
                            FeatureGalleryOption(color: .psychic, text: "Type-O-Matic", imageName: "circle.grid.cross.fill")
                        }
                            .padding([.top, .leading])
                        
                        NavigationLink(destination: ExploreView().environmentObject(sessionData)) {
                            FeatureGalleryOption(color: .bronze, text: "Explore", imageName: "wand.and.stars")
                        }
                            .padding([.top, .leading])
                        
                        NavigationLink(destination: Teambuilder().environmentObject(sessionData)) {
                            FeatureGalleryOption(color: .ice, text: "Teambuilder", imageName: "rectangle.stack.person.crop.fill")
                        }
                            .padding([.top, .leading])
                        
                        NavigationLink(destination: FaceOffView().environmentObject(sessionData)) {
                            FeatureGalleryOption(color: .dragon, text: "Face-Off", imageName: "bolt.circle.fill")
                        }
                            .padding([.top, .leading])
                        
                        NavigationLink(destination: Text("Dex Quests")) {
                            FeatureGalleryOption(color: .ground, text: "Dex Quests", imageName: "map.fill")
                        }
                            .padding([.top, .leading])
                        
                        NavigationLink(destination: NatureGuide().environmentObject(sessionData)) {
                            FeatureGalleryOption(color: .green, text: "Nature Checker", imageName: "leaf.fill")
                        }
                            .padding([.top, .leading])
                        
                        NavigationLink(destination: GlobalStats()) {
                            FeatureGalleryOption(color: .blue, text: "Global Stats", imageName: "network")
                        }
                            .padding([.top, .leading])
                        
                        NavigationLink(destination: HelpGuideView().environmentObject(sessionData)) {
                            FeatureGalleryOption(color: .gray, text: "Help Guide", imageName: "questionmark.circle.fill")
                        }
                            .padding([.top, .leading, .bottom])
                        
                    } else {
                        
                        // Grid view
                        
                        HStack {
                            
                            NavigationLink(destination: AbilityDexView().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "sparkles", color: .gold)
                            }
                            
                            NavigationLink(destination: MoveDexView().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "burst.fill", color: .red)
                            }
                            
                            NavigationLink(destination: ItemDexView().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "cube.fill", color: .flying)
                            }
                            
                            NavigationLink(destination: TypeOMaticView().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "circle.grid.cross.fill", color: .psychic)
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        Rectangle()
                            .frame(height: 3)
                            .hidden()
                        
                        HStack {
                            
                            NavigationLink(destination: ExploreView().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "wand.and.stars", color: .bronze)
                            }
                            
                            NavigationLink(destination: Teambuilder().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "rectangle.stack.person.crop.fill", color: .ice)
                            }
                            
                            NavigationLink(destination: FaceOffView().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "bolt.circle.fill", color: .dragon)
                            }
                            
                            NavigationLink(destination: Text("Dex Quests")) {
                                HomeOptionGridView(imageName: "map.fill", color: .ground)
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        Rectangle()
                            .frame(height: 3)
                            .hidden()
                        
                        HStack {
                            
                            NavigationLink(destination: NatureGuide().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "leaf.fill", color: .green)
                            }
                            
                            NavigationLink(destination: GlobalStats()) {
                                HomeOptionGridView(imageName: "network", color: .blue)
                            }
                            
                            NavigationLink(destination: HelpGuideView().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "questionmark.circle.fill", color: .gray)
                            }
                            
                            NavigationLink(destination: HelpGuideView().environmentObject(sessionData)) {
                                HomeOptionGridView(imageName: "questionmark.circle.fill", color: .gray)
                            }
                            .hidden()
                            
                        }
                        .padding(.horizontal)
                        
                    }
                    
                }
                .padding(.top)
            }
            
            
            .navigationBarTitle(Text("Home"))
            .navigationBarItems(trailing: HStack { Button(action: { self.showingGrid.toggle() }) { Image(systemName: !showingGrid ? "square.grid.2x2" : "list.bullet").imageScale(.large) }.padding(.trailing); FeatureGalleryTrailingNavButtons(showingSettings: $showingSettings).environmentObject(sessionData) })
        }
        
    }
}

struct FeatureGallery_Previews: PreviewProvider {
    static var previews: some View {
        FeatureGallery().environmentObject(SessionData())


    }
}

struct FeatureGalleryTrailingNavButtons: View {
    
    // Variables
    @EnvironmentObject var sessionData: SessionData
//    @Binding var showingHelp: Bool
    @Binding var showingSettings: Bool
    
    var body: some View {
        
        HStack {
            
//            Button(action: {
//                showingHelp.toggle()
//            }) {
//                Image(systemName: "questionmark.circle")
//                    .foregroundColor(.blue)
//                    .padding(.trailing)
//                    .imageScale(.large)
//            }
//            .sheet(isPresented: $showingHelp) {
//                NavigationView {
//                    HelpGuideView()
//                }
//            }
            
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
            
        }
        
    }
    
}

struct FeatureGalleryOption: View {
    
    // Variables
    @Environment(\.colorScheme) var colorScheme
    var color: Color
    var text: String
    var imageName: String
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(height: 92)
                .foregroundColor(colorScheme == .dark ? .secondary : .white)
                .opacity(colorScheme == .dark ? 0.4 : 1.0)
                .cornerRadius(10)
                .padding(.trailing)
                .shadow(color: .secondary, radius: colorScheme == .dark ? 0 : 15)
            
            HStack {
                
                HStack {
                    Image(systemName: imageName)
                        .resizable()
                        .frame(width: 35, height: 35)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading) {
                    
                    Text(text)
                        .foregroundColor(.primary)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 8)
                        .multilineTextAlignment(.leading)
                        .padding(.trailing)
                        .lineLimit(2)

                }
                
                Spacer()
                
            }
            .padding(.leading, 12)
            
        }
        
    }
    
}

struct FeatureGalleryBigSquare: View {
    
    // Variables
    @Environment(\.colorScheme) var colorScheme
    var color: Color
    var text: String
    var imageName: String
    var cancelPadding = false
    
    var body: some View {
        
        ZStack {
            
            Rectangle()
                .frame(height: 150)
                .foregroundColor(colorScheme == .dark ? .secondary : .white)
                .opacity(colorScheme == .dark ? 0.4 : 1.0)
                .cornerRadius(10)
                .padding(.leading, (cancelPadding ? 0 : 5))
                .shadow(color: .secondary, radius: colorScheme == .dark ? 0 : 15)
            
            VStack {
                
                HStack {
                    Image(systemName: imageName)
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(color)
                }
                
                VStack() {
                    
                    Text(text)
                        .foregroundColor(.primary)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                }
                
            }
            .padding(.leading, (cancelPadding ? 0 : 5))
            
        }
        
    }
    
}

struct HomeOptionGridView: View {
    
    // Variables
    var imageName: String
    var color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        ZStack {
            Rectangle()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(colorScheme == .dark ? .secondary : .white)
                .opacity(colorScheme == .dark ? 0.4 : 1.0)
                .cornerRadius(10)
                .shadow(color: .secondary, radius: colorScheme == .dark ? 0 : 15)
            
            Image(systemName: imageName)
                .resizable()
                .frame(width: 35, height: 35)
                .foregroundColor(color)
            
        }
        .padding(.horizontal, 2)
        
    }
    
}
