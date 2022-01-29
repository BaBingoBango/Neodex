//
//  ImageDownloader.swift
//  Neodex
//
//  Created by Ethan Marshall on 3/22/21.
//

import Foundation

struct ImageDownloader {
    
    static func download(pokemon: Pokemon) {
        
        // The goal is to download 3 images for each pokemon - the art, the sprite, and the gif!
        
//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        print("FILE PATH: \(paths[0])")
        
//        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        // MARK: 1: Art Download
        
//        if let url = URL(string: "https://img.pokemondb.net/artwork/\(pokemon.name.lowercased()).jpg") {
//            URLSession.shared.downloadTask(with: url) { location, response, error in
//                guard let location = location else {
//                    print("download error:", error ?? "")
//                    return
//                }
//                // move the downloaded file from the temporary location url to your app documents directory
//                do {
//                    try FileManager.default.moveItem(at: location, to: documents.appendingPathComponent("\(pokemon.name)-art.jpg"))
//                } catch {
//                    print(error)
//                }
//
//                print("\(pokemon.name) art downloaded!")
//
//            }.resume()
//        }
        
        // MARK: 2: Sprite Download
        
//        if let url = URL(string: "https://img.pokemondb.net/sprites/sword-shield/normal/\(pokemon.name.lowercased()).png") {
//            URLSession.shared.downloadTask(with: url) { location, response, error in
//                guard let location = location else {
//                    print("download error:", error ?? "")
//                    return
//                }
//                // move the downloaded file from the temporary location url to your app documents directory
//                do {
//                    try FileManager.default.moveItem(at: location, to: documents.appendingPathComponent("\(pokemon.name)-sprite.jpg"))
//                } catch {
//                    print(error)
//                }
//
//                print("\(pokemon.name) art downloaded!")
//
//            }.resume()
//        }
        
        // Check Documents for failed files - then download different versions!
//        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
//            let url = NSURL(fileURLWithPath: path)
//        if let pathComponent = url.appendingPathComponent("\(pokemon.name)-sprite.jpg") {
//                let filePath = pathComponent.path
//                let fileManager = FileManager.default
//                if fileManager.fileExists(atPath: filePath) {
////                    print("FILE AVAILABLE")
//                    print("\"\(pokemon.name.lowercased())\",")
//                } else {
////                    print("FILE NOT AVAILABLE")
//                }
//            } else {
////                print("FILE PATH NOT AVAILABLE")
//            }
        
        // Get alternative sprites
//        let altSpriteList = [
//            "farfetch'd",
//            "blacephalon",
//            "minior",
//            "naganadel",
//            "oricorio",
//            "poipole",
//            "sirfetch'd",
//            "stakataka"
//        ]
//        for eachName in altSpriteList {
//
//            if let url = URL(string: "https://img.pokemondb.net/sprites/ultra-sun-ultra-moon/normal/\(eachName).png") {
//                URLSession.shared.downloadTask(with: url) { location, response, error in
//                    guard let location = location else {
//                        print("download error:", error ?? "")
//                        return
//                    }
//                    // move the downloaded file from the temporary location url to your app documents directory
//                    do {
//                        try FileManager.default.moveItem(at: location, to: documents.appendingPathComponent("\(eachName.capitalizingFirstLetter())-sprite.jpg"))
//                    } catch {
//                        print(error)
//                    }
//
//                    print("\(eachName.capitalizingFirstLetter()) art downloaded!")
//
//                }.resume()
//            }
//
//        }

    }
    
}
