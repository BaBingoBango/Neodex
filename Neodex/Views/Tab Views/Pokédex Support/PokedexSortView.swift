//
//  PokedexSortView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/1/21.
//

import SwiftUI

struct PokedexSortView: View {
    
    // Variables
    @Environment(\.presentationMode) var presentationMode
    var directions = ["Ascending", "Descending"]
    
    // Sort variables
    @Binding var sortCondition: String
    @Binding var sortDirection: Int
    
    var body: some View {
        
        NavigationView {
            
            VStack {
                
                Picker(selection: $sortDirection, label: Text("")) {
                    ForEach(0 ..< directions.count) {
                       Text(self.directions[$0])
                    }
                }
                .padding(.all)
                .pickerStyle(SegmentedPickerStyle())
                
                ScrollView {
                    VStack {
                        
                        // MARK: No Category
                        
                        HStack {
                            
                            PokedexSortButton(sortCondition: $sortCondition, sortName: "Dex Number", imageName: "number")
                            
                            PokedexSortButton(sortCondition: $sortCondition, sortName: "Alphabetical", imageName: "a.circle.fill")
                            
                        }
                        .padding(.horizontal)
                        
                        // MARK: Base Stats
                        
                        HeadingText(text: "Base Stats")
                            .padding(.top)
                        
                        HStack {
                            
                            VStack {
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "HP", imageName: "heart.circle.fill")

                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Special Attack", imageName: "bolt.circle.fill")

                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Special Defense", imageName: "shield.checkerboard")
                                
                            }
                            
                            VStack {
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Attack", imageName: "burst.fill")
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Defense", imageName: "shield.fill")
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Speed", imageName: "hare.fill")
                                
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        HStack(alignment: .center) {

                            PokedexSortButton(sortCondition: $sortCondition, sortName: "Base Stat Total", imageName: "star.fill")

                            PokedexSortButton(sortCondition: $sortCondition, sortName: "Base Stat Total", imageName: "star.fill")
                                .hidden()
                            
                        }
                            .padding(.horizontal)
                        
                        // MARK: Characteristics
                        
                        HeadingText(text: "Characteristics")
                            .padding(.top)
                        
                        HStack {
                            
                            VStack {
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Height", imageName: "ruler.fill")
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Catch Rate", imageName: "checkmark.seal.fill")
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Base Exp.", imageName: "sparkles")
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Male Rate", imageName: "stethoscope")
                                
                            }
                            
                            VStack {
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Weight", imageName: "scalemass.fill")
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Friendship", imageName: "heart.fill")
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Egg Cycles", imageName: "arrow.clockwise")
                                
                                PokedexSortButton(sortCondition: $sortCondition, sortName: "Growth Rate", imageName: "arrow.up.to.line.alt")
                                
                            }
                            
                        }
                        .padding(.horizontal)
                        
                    }
                    .padding(.bottom)
                    
                    .navigationBarTitle(Text("Sort Pokémon"), displayMode: .inline)
                    .navigationBarItems(leading: Button(action: { sortCondition = "Dex Number"; sortDirection = 0 }) { Text("Reset").fontWeight(.regular) }.disabled(sortDirection == 0 && sortCondition == "Dex Number"), trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Done") })
                }
            }
        }
        
    }
}

struct SortOptionView: View {
    
    // Variables
    var imageName: String
    var sortName: String
    var color: Color
    
    var body: some View {
        ZStack {
            Rectangle()
                .frame(height: 50)
                .foregroundColor(color)
                .cornerRadius(30)
            HStack {
                Image(systemName: imageName)
                    .padding(.leading)
                    .imageScale(.large)
                    .foregroundColor(.white)
                Text(sortName)
                    .font(.system(size: 15))
                    .fontWeight(.bold)
                    .foregroundColor(Color.white)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.trailing)
        }
    }
}

struct PokedexSortButton: View {
    
    // Variables
    @Binding var sortCondition: String
    var sortName: String
    var imageName: String
    
    var body: some View {
        Button(action: {
            sortCondition = sortName
        }) {
            SortOptionView(imageName: imageName, sortName: sortName, color: sortCondition == sortName ? .blue : .secondary)
        }
    }
}
