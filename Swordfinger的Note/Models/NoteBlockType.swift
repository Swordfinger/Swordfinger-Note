//
//  NoteBlockType.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import Foundation

enum NoteBlockType: String, Codable, CaseIterable {
    case paragraph
    case heading
    case code
    case drawing
}
