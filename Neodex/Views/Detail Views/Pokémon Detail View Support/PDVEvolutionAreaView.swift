//
//  PDVEvolutionAreaView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/12/20.
//

import SwiftUI

struct PDVEvolutionAreaView: View {
    
    // Variables
    var pokemon: Pokemon
    enum PushedItem: String {
        case firstScreen
        case secondScreen
        case thirdScreen
        case fourthScreen
        case fifthScreen
    }
    @State var selectedPushedItem: PushedItem?
    @EnvironmentObject var sessionData: SessionData
    
    @State var tree1: [Evolution] = []
    @State var tree2: [Evolution] = []
    @State var tree3: [Evolution] = []
    
    var body: some View {
        
        // First, decide which view to present based on how many evolutions the Pokémon in question has
        if pokemon.evolutions.count == 0 {
            
            // MARK: - The view for no evolutions
            VStack {
                
                GIFView(gifName: "\(pokemon.name)-gif")
                    .frame(width: 80, height: 80)
                
                Text("\(pokemon.name) does not evolve.")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
        } else {
            
            // The view for one or more evolution
            VStack {
                
                // MARK: - Normal Tree
                
                HStack {
                    ForEach(tree1, id: \.pokemon) { evolution in
                        HStack {
                            if evolution.method != "" {
                                Spacer()
                                VStack {
                                    Image(systemName: "arrow.right")
                                        .imageScale(.large)
                                        .foregroundColor(.primary)
                                    Text(evolution.method == "Level Up" ? String("Lv. \(evolution.level)") : evolution.method)
                                        .fontWeight(.bold)
                                        .padding(.top, 1)
                                        .foregroundColor(.primary)
                                        .frame(width: 80)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 80, height: 80)
                                Spacer()
                            }
                            VStack {
                                if evolution.treeLevel == 1 {
                                    NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: evolution.pokemon)).environmentObject(sessionData), tag: .firstScreen, selection: $selectedPushedItem) {
                                        GIFView(gifName: "\(evolution.pokemon)-gif")
                                            .frame(width: 80, height: 80)
                                        }
                                    } else if evolution.treeLevel == 2 {
                                        NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: evolution.pokemon)).environmentObject(sessionData), tag: .secondScreen, selection: $selectedPushedItem) {
                                            GIFView(gifName: "\(evolution.pokemon)-gif")
                                                .frame(width: 80, height: 80)
                                        }
                                    } else if evolution.treeLevel == 3 {
                                        NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: evolution.pokemon)).environmentObject(sessionData), tag: .thirdScreen, selection: $selectedPushedItem) {
                                            GIFView(gifName: "\(evolution.pokemon)-gif")
                                                .frame(width: 80, height: 80)
                                        }
                                    }
                                }
                            }
                        
                        }
                }
                
                // MARK: Duplicate Tree
            
                HStack {
//                    Spacer()
                    
                    // If the tree above this duplicate tree exists, add hidden views to match the frame of the above tree
                    if tree1.count >= 1 && tree2.count >= 1 && tree1.count > tree2.count {
                        let numToAdd = tree1.count - tree2.count
//                        Spacer()
                        if numToAdd != 1 {
                            VStack {
                                Image(systemName: "arrow.right")
                                    .imageScale(.large)
                                    .foregroundColor(.primary)
                                Text("Lv. 00")
                                    .fontWeight(.bold)
                                    .padding(.top, 1)
                                    .foregroundColor(.primary)
                                    .frame(width: 80)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.center)
                            }
                            .hidden()
                            Spacer()
                        }
//                        Spacer()
                        ForEach((1...numToAdd), id: \.self) { num in
                            Rectangle()
                                .frame(width: 80, height: 80)
                                .hidden()
//                            Spacer()
                        }
                    }
                    
                    ForEach(tree2, id: \.pokemon) { evolution in
                        HStack {
                            if evolution.method != "" {
                                Spacer()
                                VStack {
                                    Image(systemName: "arrow.right")
                                        .imageScale(.large)
                                        .foregroundColor(.primary)
                                    Text(evolution.method == "Level Up" ? String("Lv. \(evolution.level)") : evolution.method)
                                        .fontWeight(.bold)
                                        .padding(.top, 1)
                                        .foregroundColor(.primary)
                                        .frame(width: 80)
                                        .multilineTextAlignment(.center)
                                }
                                Spacer()
                            }
                            VStack {
                                if evolution.treeLevel == 1 {
                                    NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: evolution.pokemon)).environmentObject(sessionData), tag: .firstScreen, selection: $selectedPushedItem) {
                                        GIFView(gifName: "\(evolution.pokemon)-gif")
                                            .frame(width: 80, height: 80)
                                        }
                                    } else if evolution.treeLevel == 2 {
                                        NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: evolution.pokemon)).environmentObject(sessionData), tag: .secondScreen, selection: $selectedPushedItem) {
                                            GIFView(gifName: "\(evolution.pokemon)-gif")
                                                .frame(width: 80, height: 80)
                                        }
                                    } else if evolution.treeLevel == 3 {
                                        NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: evolution.pokemon)).environmentObject(sessionData), tag: .thirdScreen, selection: $selectedPushedItem) {
                                            GIFView(gifName: "\(evolution.pokemon)-gif")
                                                .frame(width: 80, height: 80)
                                        }
                                    }
                                }
                            }
                        }
//                    Spacer()
                }
                
                // MARK: Double Duplicate Tree
                
                HStack {
//                    Spacer()
                    
                    // If the tree above this duplicate tree exists, add hidden views to match the frame of the above tree
                    if tree2.count >= 1 && tree3.count >= 1 && tree2.count > tree3.count {
                        let numToAdd = tree2.count - tree3.count
//                        VStack {
//                            Image(systemName: "arrow.right")
//                                .imageScale(.large)
//                                .foregroundColor(.primary)
//                            Text("Lv. 00")
//                                .fontWeight(.bold)
//                                .padding(.top, 1)
//                                .foregroundColor(.primary)
//                        }
//                        .hidden()
                        ForEach((1...numToAdd), id: \.self) { num in
                            Rectangle()
                                .frame(width: 80, height: 80)
//                                .hidden()
                        }
                    }
                    if tree1.count >= 1 && tree3.count >= 1 && tree1.count > tree3.count {
                        let numToAdd = tree1.count - tree3.count
//                        VStack {
//                            Image(systemName: "arrow.right")
//                                .imageScale(.large)
//                                .foregroundColor(.primary)
//                            Text("Lv. 00")
//                                .fontWeight(.bold)
//                                .padding(.top, 1)
//                                .foregroundColor(.primary)
//                        }
//                        .hidden()
                        ForEach((1...numToAdd), id: \.self) { num in
                            Rectangle()
                                .frame(width: 80, height: 80)
                                .hidden()
                        }
                    }
//                    Spacer()
                    
                    ForEach(tree3, id: \.pokemon) { evolution in
                        HStack {
                            if evolution.method != "" {
                                Spacer()
                                VStack {
                                    Image(systemName: "arrow.right")
                                        .imageScale(.large)
                                        .foregroundColor(.primary)
                                    Text(evolution.method == "Level Up" ? String("Lv. \(evolution.level)") : evolution.method)
                                        .fontWeight(.bold)
                                        .padding(.top, 1)
                                        .foregroundColor(.primary)
                                        .frame(width: 80)
                                        .multilineTextAlignment(.center)
                                }
                                Spacer()
                            }
                            VStack {
                                if evolution.treeLevel == 1 {
                                    NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: evolution.pokemon)).environmentObject(sessionData), tag: .firstScreen, selection: $selectedPushedItem) {
                                        GIFView(gifName: "\(evolution.pokemon)-gif")
                                            .frame(width: 80, height: 80)
                                        }
                                    } else if evolution.treeLevel == 2 {
                                        NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: evolution.pokemon)).environmentObject(sessionData), tag: .secondScreen, selection: $selectedPushedItem) {
                                            GIFView(gifName: "\(evolution.pokemon)-gif")
                                                .frame(width: 80, height: 80)
                                        }
                                    } else if evolution.treeLevel == 3 {
                                        NavigationLink(destination: PokemonDetailView(pokemon: Pokemon.findPokemon(name: evolution.pokemon)).environmentObject(sessionData), tag: .thirdScreen, selection: $selectedPushedItem) {
                                            GIFView(gifName: "\(evolution.pokemon)-gif")
                                                .frame(width: 80, height: 80)
                                        }
                                    }
                                }
                            }
                        }
                }
                
            }
            .onAppear {
                
                // MARK: - View Launch Code
                
                /// We must first find any Evolution objects with the same tree level. If this is the case, repeat tree levels need to be in a vertical stack rather than in a horizontal stack.

                /// We know that the highest tree level is 3 and there is at most three trees (as far as I know). So, all we have to do is remove any Evolution objects that have duplicate tree levels.

                /// We will do this by creating two new arrays called tree1 and tree2. They are created at the top of this file.

//                @State var tree1: [Evolution] = []
//                @State var tree2: [Evolution] = []
                
                /// This arrays are of type [Evolution] and represent a complete evolution path. They should contain no duplicate tree levels. For instance, tree levels of 1, 2, 3 and 2, 3 are acceptable, but 1, 2, 2 is not. Becuase there is a maximum of two trees, the arrays' maximum length is two. Their minimum length is one.

                /// To populate these arrays, we will iterate through pokemon.evolutions and place any entries with tree levels we've seen already into tree1. Everything else will go into tree2. This will form our two trees! (If there are any duplicates, that is - If there aren't, we will just use tree1)

                var seenTreeLevels: [Int] = []
                var doubleSeenTreeLevels: [Int] = []
                for eachEvolution in pokemon.evolutions {
                    if !(seenTreeLevels.contains(eachEvolution.treeLevel)) {
                        // It's not a duplicate!
                        seenTreeLevels.append(eachEvolution.treeLevel)
                        tree1.append(eachEvolution)
                    } else if !(doubleSeenTreeLevels.contains(eachEvolution.treeLevel)) {
                        // It's not a double duplicate!
                        doubleSeenTreeLevels.append(eachEvolution.treeLevel)
                        tree2.append(eachEvolution)
                    } else {
                        // It's a double duplicate!
                        tree3.append(eachEvolution)
                    }
                }
                
                /// Now, see if tree1 has one entry, That means its a branching evolution system! To make it look nice, we'll clear tree1, and add that entry into other trees with entries! Bam!
                
                if tree1.count == 1 {
                    if !tree2.isEmpty {
                        tree2.insert(tree1[0], at: 0)
                    }
                    if !tree3.isEmpty {
                        tree3.insert(tree1[0], at: 0)
                    }
                    tree1.removeAll()
                }
                
            }
                
            }
            
        }
        
    }

struct PDVEvolutionAreaView_Previews: PreviewProvider {
    static var previews: some View {
        PDVEvolutionAreaView(pokemon: Pokemon.findPokemon(name: "Eevee")).environmentObject(SessionData())
    }
}

extension View {
    func inExpandingRectangle() -> some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
            self
        }
    }
}
