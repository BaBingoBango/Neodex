//
//  AnimatedGIFDownloader.swift
//  Neodex
//
//  Created by Ethan Marshall on 11/10/21.
//

import Foundation
import UIKit

/// A static structure holding the static function downloadAnimatedGIFs().
struct AnimatedGIFDownloader {
    
    /// Downloads all animated Pokémon sprites not already in the asset catalog to a specified path on the local disk.
    static func downloadAnimatedGIFs() {

        // Loop through all Pokémon in the master list while keeping a count of the number of requested files
        var totalCount = 0
        var downloadCount = 0
        for eachPokemon in pokemonDataList {
            
            // For each Pokémon, first find out if the animted sprite is already in the asset catalog - if it is, move on to the next Pokémon
            if !(FileManager.default.fileExists(atPath: "/Users/ethan/Documents/Neodex Software/Neodex/Neodex/Assets.xcassets/Alolan Form Assets/\(eachPokemon.name)-gif.dataset") || FileManager.default.fileExists(atPath: "/Users/ethan/Documents/Neodex Software/Neodex/Neodex/Assets.xcassets/Alternate Form Assets/\(eachPokemon.name)-gif.dataset") || FileManager.default.fileExists(atPath: "/Users/ethan/Documents/Neodex Software/Neodex/Neodex/Assets.xcassets/Animated Pokémon Sprites/\(eachPokemon.name)-gif.dataset") || FileManager.default.fileExists(atPath: "/Users/ethan/Documents/Neodex Software/Neodex/Neodex/Assets.xcassets/Gmax Form Assets/\(eachPokemon.name)-gif.dataset") || FileManager.default.fileExists(atPath: "/Users/ethan/Documents/Neodex Software/Neodex/Neodex/Assets.xcassets/Mega Evolution Assets/\(eachPokemon.name)-gif.dataset") || FileManager.default.fileExists(atPath: "/Users/ethan/Documents/Neodex Software/Neodex/Neodex/Assets.xcassets/Animated Pokémon Sprites 2/\(eachPokemon.name)-gif.dataset")) {
                
                // Print a pre-download attempt message
                totalCount += 1
                print("Attempting GIF download for \(eachPokemon.name) (\(totalCount))")
                
                // Define and print the filepath to save the images to
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                print("FILE PATH: \(paths[0])")
                
                // Open a URL session and hopefully download the file!
                if let url = URL(string: "https://projectpokemon.org/images/normal-sprite/\(eachPokemon.name.lowercased()).gif") {
                    URLSession.shared.downloadTask(with: url) { location, response, error in
                        guard let location = location else {
                            print("download error:", error ?? "")
                            return
                        }
                        // move the downloaded file from the temporary location url to your app documents directory
                        do {
                            try FileManager.default.moveItem(at: location, to: documents.appendingPathComponent("\(eachPokemon.name)-gif.gif"))
                        } catch {
                            print(error)
                        }
        
                        // If the download was a success, print the following message and increase the count
                        downloadCount += 1
                        print("\(eachPokemon.name) GIF downloaded! (\(downloadCount))")
        
                    }.resume()
                }
                
            }
            
        }
        
    }
    
}
