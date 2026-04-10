//
//  Item.swift
//  FindMyRun
//
//  Created by Miguel Dias on 2026-04-10.
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
