//
//  NoteBlock.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import Foundation
import SwiftData

@Model
final class NoteBlock {
    var id: UUID
    var page: NotePage?
    var order: Int
    var blockTypeRawValue: String
    var textContent: String
    var drawingData: Data?
    var codeLanguageRawValue: String?

    var blockType: NoteBlockType {
        get {
            NoteBlockType(rawValue: blockTypeRawValue) ?? .paragraph
        }
        set {
            blockTypeRawValue = newValue.rawValue
        }
    }

    var codeLanguage: CodeBlockLanguage {
        get {
            guard let codeLanguageRawValue else {
                return .plainText
            }

            return CodeBlockLanguage(rawValue: codeLanguageRawValue) ?? .plainText
        }
        set {
            codeLanguageRawValue = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        page: NotePage? = nil,
        order: Int,
        blockType: NoteBlockType,
        textContent: String = "",
        drawingData: Data? = nil,
        codeLanguage: CodeBlockLanguage = .plainText
    ) {
        self.id = id
        self.page = page
        self.order = order
        self.blockTypeRawValue = blockType.rawValue
        self.textContent = textContent
        self.drawingData = drawingData
        self.codeLanguageRawValue = codeLanguage.rawValue
    }
}
