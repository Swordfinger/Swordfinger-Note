//
//  Item.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
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
