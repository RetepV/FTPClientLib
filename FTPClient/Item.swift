//
//  Item.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 15-10-2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
