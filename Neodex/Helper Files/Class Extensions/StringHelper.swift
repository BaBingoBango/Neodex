//
//  StringHelper.swift
//  Neodex
//
//  Created by Ethan Marshall on 3/29/21.
//

import Foundation

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}
