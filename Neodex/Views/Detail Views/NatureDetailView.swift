//
//  NatureDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/27/21.
//

import SwiftUI

struct NatureDetailView: View {
    
    // Variables
    var nature: Nature
    @EnvironmentObject var sessionData: SessionData
    @Environment(\.presentationMode) var presentationMode
    var buttonText = ""
    
    var body: some View {
        
//        NavigationView {
            
            ScrollView {
                VStack {
                    
                    HStack {
                        
                        ZStack {
                            
                            Circle()
                                .foregroundColor(nature.plus != nature.minus ? .green : .gray)
                                .aspectRatio(contentMode: .fit)
                            
                            VStack {
                                
                                Image(systemName: "arrow.up")
                                    .resizable()
                                    .frame(width: 40, height: 43)
                                    .foregroundColor(.white)
                                
                                Text(nature.plus == "Defense" && UIDevice.modelName.contains("iPod") ? "DEF" : nature.plus.uppercased())
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.top)
                                    .offset(y: -10)
                                
                            }
                            
                        }
                        .padding(.trailing, 10)
                        
                        ZStack {
                            
                            Circle()
                                .foregroundColor(nature.plus != nature.minus ? .red : .gray)
                                .aspectRatio(contentMode: .fit)
                            
                            VStack {
                                
                                Image(systemName: "arrow.down")
                                    .resizable()
                                    .frame(width: 40, height: 43)
                                    .foregroundColor(.white)
                                
                                Text(nature.plus == "Defense" && UIDevice.modelName.contains("iPod") ? "DEF" : nature.minus.uppercased())
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.top)
                                    .offset(y: -10)
                                
                            }
                            
                        }
                        .padding(.leading, 10)
                        
                    }
                    .padding(.horizontal, 37.5)
                    
                    Text(nature.plus != nature.minus ? "Pokémon with the \(nature.name) Nature will see their \(nature.plus) stat grow more quickly and their \(nature.minus) stat grow more slowly. In other words, by the time it reaches level 100, a Pokémon with the \(nature.name) Nature will have their \(nature.plus) stat 10% higher and their \(nature.minus) stat 10% lower than it would usually be." : "Pokémon with the \(nature.name) Nature will see their \(nature.plus) stat grow more quickly and their \(nature.minus) stat grow more slowly. In other words, the \(nature.name) Nature has no effect on a Pokémon's stats, as the increase and decrease in \(nature.plus) cancel each other out to produce an unaffected value.")
                        .padding([.top, .leading, .trailing])
                    
                    
                    HeadingText(text: "Tastes")
                        .padding(.top)
                    
                    if nature.plus != nature.minus {
                        
                        ZStack {
                            
                            Rectangle()
                                .cornerRadius(10)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .frame(height: 50)
                                .opacity(0.25)
                            
                            HStack {
                                
                                Text("Likes ")
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.green)
                                    .padding(.trailing, 21)
                                
                                Text("\(nature.berryPlus) Berries")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                            }
                            .padding(.leading, 35)
                            
                        }
                        
                        ZStack {
                            
                            Rectangle()
                                .cornerRadius(10)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .frame(height: 50)
                                .opacity(0.25)
                            
                            HStack {
                                
                                Text("Dislikes ")
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.red)
                                
                                Text("\(nature.berryMinus) Berries")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                            }
                            .padding(.leading, 35)
                        }
                        
                    } else {
                        
                        ZStack {
                            
                            Rectangle()
                                .cornerRadius(10)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .frame(height: 50)
                                .opacity(0.25)
                            
                            HStack {
                                
                                Text("\(nature.name) Pokémon have no Berry preferences")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .padding(.trailing, 21)
                                
                                Spacer()
                                
                            }
                            .padding(.leading, 35)
                            
                        }
                        
                    }
                    
                    if nature.confusingBerry != "None" {
                        
                        HeadingText(text: "Confusing Berry")
                            .padding(.top)
                        
                        SearchViewItemOption(item: Item.itemList[Item.itemList.firstIndex(where: { $0.name == nature.confusingBerry }) ?? 0]).environmentObject(sessionData)
                        
                    }
                    
                }
                .padding(.vertical)
            }
        
            .navigationBarTitle(Text(nature.name), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text(buttonText) })
            
//        }
        
    }
}

struct NatureDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NatureDetailView(nature: Nature.natureList[16]).environmentObject(SessionData())
    }
}
