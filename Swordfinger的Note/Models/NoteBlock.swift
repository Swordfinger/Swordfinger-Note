//
//  NoteBlock.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import Foundation
import CoreGraphics
import SwiftData

enum DrawingCanvasPreset: String, CaseIterable {
    case legacySquare
    case sketch
    case sideNote
    case fullNote

    static let newDrawingChoices: [DrawingCanvasPreset] = [.sketch, .sideNote, .fullNote]

    var displayName: String {
        switch self {
        case .legacySquare:
            "Legacy Square"
        case .sketch:
            "Sketch"
        case .sideNote:
            "Side Note"
        case .fullNote:
            "Full Note"
        }
    }

    var logicalSize: CGSize {
        switch self {
        case .legacySquare:
            CGSize(width: 1600, height: 1600)
        case .sketch:
            CGSize(width: 1000, height: 700)
        case .sideNote:
            CGSize(width: 1200, height: 1200)
        case .fullNote:
            CGSize(width: 1600, height: 2200)
        }
    }

    var logicalPageRect: CGRect {
        CGRect(origin: .zero, size: logicalSize)
    }

    var aspectRatio: CGFloat {
        logicalSize.width / logicalSize.height
    }

    func embeddedHeight(forWidth width: CGFloat) -> CGFloat {
        width / aspectRatio
    }
}

enum DrawingPaperStyle: String, CaseIterable {
    case blank
    case lined
    case grid
    case dotted

    var displayName: String {
        switch self {
        case .blank:
            "Blank"
        case .lined:
            "Lined"
        case .grid:
            "Grid"
        case .dotted:
            "Dotted"
        }
    }

    var logicalSpacing: CGFloat {
        switch self {
        case .blank:
            0
        case .lined:
            80
        case .grid:
            80
        case .dotted:
            60
        }
    }
}

@Model
final class NoteBlock {
    var id: UUID
    var page: NotePage?
    var order: Int
    var blockTypeRawValue: String
    var textContent: String
    var drawingData: Data?
    var codeLanguageRawValue: String?
    var drawingCanvasPresetRawValue: String?
    var drawingPaperStyleRawValue: String?

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

    var drawingCanvasPreset: DrawingCanvasPreset {
        get {
            guard let drawingCanvasPresetRawValue else {
                return .legacySquare
            }

            return DrawingCanvasPreset(rawValue: drawingCanvasPresetRawValue) ?? .legacySquare
        }
        set {
            drawingCanvasPresetRawValue = newValue.rawValue
        }
    }

    var drawingPaperStyle: DrawingPaperStyle {
        get {
            guard let drawingPaperStyleRawValue else {
                return .blank
            }

            return DrawingPaperStyle(rawValue: drawingPaperStyleRawValue) ?? .blank
        }
        set {
            drawingPaperStyleRawValue = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        page: NotePage? = nil,
        order: Int,
        blockType: NoteBlockType,
        textContent: String = "",
        drawingData: Data? = nil,
        codeLanguage: CodeBlockLanguage = .plainText,
        drawingCanvasPreset: DrawingCanvasPreset? = nil,
        drawingPaperStyle: DrawingPaperStyle? = nil
    ) {
        self.id = id
        self.page = page
        self.order = order
        self.blockTypeRawValue = blockType.rawValue
        self.textContent = textContent
        self.drawingData = drawingData
        self.codeLanguageRawValue = codeLanguage.rawValue
        self.drawingCanvasPresetRawValue = drawingCanvasPreset?.rawValue
        self.drawingPaperStyleRawValue = drawingPaperStyle?.rawValue
    }
}
