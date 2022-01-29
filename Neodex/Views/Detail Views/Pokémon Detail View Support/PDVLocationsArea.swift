//
//  PDVLocationsArea.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/27/20.
//

import SwiftUI

struct PDVLocationsArea: View {
    
    // Variables
    var pokemon: Pokemon
    
    var body: some View {
        
        let chunkedLocations = pokemon.locations.chunked(into: 2)
        
        VStack {
            
            if pokemon.locations.count >= 1 {
                
                ForEach(0..<chunkedLocations.count, id: \.self) { index in
                    
                    HStack {
                        
                        ForEach(chunkedLocations[index], id: \.self) { location in
                            
                            LocationOption(location: location)
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                ZStack {
                    
                    Rectangle()
                        .frame(height: 150)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                        .cornerRadius(20)
                    
                    VStack {
                        
                        Image(systemName: "magnifyingglass")
                            .resizable()
                            .frame(width: 50, height: 50)
                        
                        Text("\(pokemon.name) cannot be found in the wild in Galar.")
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 5)
                        
                    }
                    
                }
                
            }
            
        }
        
//        ZStack {
//
//            Rectangle()
//                .frame(height: 150)
//                .foregroundColor(.secondary)
//                .opacity(0.4)
//                .cornerRadius(20)
//
//            VStack(alignment: .leading) {
//                ForEach(pokemon.locations, id: \.self) { location in
//                    HStack {
//                        Image(systemName: "circlebadge.fill")
//                            .imageScale(.small)
//                            .foregroundColor(.primary)
//                        Text(location)
//                            .fontWeight(.bold)
//                            .foregroundColor(.primary)
//                    }
//                }
//            }
//
//        }
        
    }
}

struct PDVLocationsArea_Previews: PreviewProvider {
    static var previews: some View {
        PDVLocationsArea(pokemon: Pokemon.theTestList()[3])
    }
}

struct LocationOption: View {
    
    // Variables
    var location: String
    @State var showingDetail = false
    
    var body: some View {
        
        Button(action: {
            self.showingDetail.toggle()
        }) {
            ZStack {
                Rectangle()
                    .frame(height: 50)
                    .foregroundColor(.secondary)
                    .cornerRadius(20)
                    .opacity(0.7)
                
                if location.contains("SWORD:") {
                    HStack {
                        Spacer()
                        Image(uiImage: UIImage(named: "swordicon")!.trimmingTransparentPixels()!)
                            .resizable()
                            .scaleEffect(0.6)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .offset(x: 15)
                        Text(location.replacingOccurrences(of: "SWORD: ", with: ""))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .offset(x: -15)
                    
                } else if location.contains("SHIELD:") {
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.red)
                            .opacity(0.7)
                        Text(location.replacingOccurrences(of: "SHIELD: ", with: ""))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .opacity(0.7)
                    }
                } else {
                    Text(location)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
            }
        }
        .sheet(isPresented: $showingDetail) {
            LocationDetailView(location: location)
        }
        
    }
    
}
