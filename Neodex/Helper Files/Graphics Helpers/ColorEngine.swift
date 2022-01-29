//
//  ColorEngine.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/12/20.
//

import Foundation
import SwiftUI

extension Color {
    static let bug = Color("bug")
    static let dark = Color("dark")
    static let dragon = Color("dragon")
    static let fairy = Color("fairy")
    static let fighting = Color("fighting")
    static let flying = Color("flying")
    static let ground = Color("ground")
    static let ice = Color("ice")
    static let normal = Color("normal")
    static let psychic = Color("psychic")
    static let ghost = Color("ghost")
    static let rock = Color("rock")
    static let steel = Color("steel")
    static let poison = Color("poison")
    static let gold = Color("gold")
    static let veryLightGray = Color("Very Light Gray")
    static let silver = Color("silver")
    static let bronze = Color("bronze")
}

func categoryColorDelegator(category: String) -> Color {
    if category == "Physical" {
        return Color.orange
    } else if category == "Special" {
        return Color.blue
    } else {
        return Color.gray
    }
}

func typeColorDelegator(type: String) -> Color {
    
    if type == "Normal" {
        return Color.normal
    } else if type == "Fire" {
        return Color.red
    } else if type == "Water" {
        return Color.blue
    } else if type == "Electric" {
        return Color.yellow
    } else if type == "Grass" {
        return Color.green
    } else if type == "Ice" {
        return Color.ice
    } else if type == "Fighting" {
        return Color.fighting
    } else if type == "Poison" {
        return Color.poison
    } else if type == "Ground" {
        return Color.ground
    } else if type == "Flying" {
        return Color.flying
    } else if type == "Psychic" {
        return Color.psychic
    } else if type == "Bug" {
        return Color.bug
    } else if type == "Rock" {
        return Color.rock
    } else if type == "Ghost" {
        return Color.ghost
    } else if type == "Dragon" {
        return Color.dragon
    } else if type == "Dark" {
        return Color.dark
    } else if type == "Steel" {
        return Color.steel
    } else if type == "Fairy" {
        return Color.fairy
    } else {
        return Color.gray
    }
}

func rankColorDelegator(rank: Int) -> Color {
    switch rank {
    case 1: return .gold
    case 2: return .silver
    case 3: return .bronze
    default: return .blue
    }
}

extension UIImage {
    /// Average color of the image, nil if it cannot be found
    var averageColor: UIColor? {
        // convert our image to a Core Image Image
        guard let inputImage = CIImage(image: self) else { return nil }

        // Create an extent vector (a frame with width and height of our current input image)
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                    y: inputImage.extent.origin.y,
                                    z: inputImage.extent.size.width,
                                    w: inputImage.extent.size.height)

        // create a CIAreaAverage filter, this will allow us to pull the average color from the image later on
        guard let filter = CIFilter(name: "CIAreaAverage",
                                  parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        // A bitmap consisting of (r, g, b, a) value
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])

        // Render our output image into a 1 by 1 image supplying it our bitmap to update the values of (i.e the rgba of the 1 by 1 image will fill out bitmap array
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)

        // Convert our bitmap images of r, g, b, a to a UIColor
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: CGFloat(bitmap[3]) / 255)
    }
}
