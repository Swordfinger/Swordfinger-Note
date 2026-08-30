//
//  CodeBlockLanguage.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import Foundation

enum CodeBlockLanguage: String, Codable, CaseIterable, Identifiable {
    case plainText = "Plain Text"
    case swift = "Swift"
    case python = "Python"
    case c = "C"
    case cpp = "C++"
    case java = "Java"
    case javascript = "JavaScript"
    case haskell = "Haskell"
    case racket = "Racket"
    case prolog = "Prolog"

    var id: String {
        rawValue
    }
}
