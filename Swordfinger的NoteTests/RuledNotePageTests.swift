import Foundation
import Testing
import SwiftData
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
#if SWIFT_PACKAGE
@testable import FingerNoteRuled
#else
@testable import Swordfinger的Note
#endif

@MainActor
struct RuledNotePageTests {
    private let document = RuledPageDocument()

    private func sample(_ text: String = "Lecture 1\nToday we study graphs.") -> RuledEditSnapshot {
        RuledEditSnapshot(text: NSAttributedString(string: text, attributes: RuledTextSize.body.attributes(for: document)),
                          selection: NSRange(location: 3, length: 0), typingSize: .body)
    }

    @Test func shiftReturnOnlyChangesCurrentLine() {
        let initial = sample()
        let twice = RuledTextCommands.enlarged(initial, document: document)
        let three = RuledTextCommands.enlarged(twice, document: document)
        for (state, slots) in [(twice, 2), (three, 3)] {
            #expect(state.text.string == initial.text.string)
            #expect(state.selection == initial.selection)
            let lines = RuledTextContent(snapshot: state).lines
            #expect(lines.count == 2)
            #expect(lines[0].size.rawValue == slots)
            #expect(lines[1].size == .body)
            #expect(lines[1].text == "Today we study graphs.")
        }
    }

    @Test func returnInMiddlePreservesSuffixAndResetsOnlyNewLine() {
        var state = RuledTextCommands.enlarged(sample(), document: document)
        state.selection = NSRange(location: 7, length: 0)
        let result = RuledTextCommands.insertingReturn(state, document: document)
        #expect(result.text.string == "Lecture\n 1\nToday we study graphs.")
        #expect(result.selection.location == 8)
        let lines = RuledTextContent(snapshot: result).lines
        #expect(lines.map(\.size) == [.heading, .body, .body])
    }

    @Test func emptyTrailingLineRetainsItsSizeAcrossSerialization() throws {
        var state = sample("Lecture 1\n")
        state.selection = NSRange(location: state.text.length, length: 0)
        state = RuledTextCommands.enlarged(state, document: document)
        state = RuledTextCommands.enlarged(state, document: document)
        let content = RuledTextContent(snapshot: state)
        let restored = try RuledTextContent.decode(content.encoded())
        #expect(restored.lines.last?.size == .largeHeading)
        #expect(restored.snapshot(document: document).text.string == state.text.string)
        #expect(restored.snapshot(document: document).trailingSize == .largeHeading)
    }

    @Test func actualVisualLinesReserveSlotsAndRestoreRules() {
        let layout = RuledPageLayout(document: document)
        let storage = NSTextStorage(attributedString: sample().text)
        let manager = NSLayoutManager()
        manager.delegate = layout
        manager.usesFontLeading = false
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: document.textWidth, height: 100_000))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        var state = sample()
        for slots in 1...3 {
            if slots > 1 { state = RuledTextCommands.enlarged(state, document: document) }
            storage.setAttributedString(state.text)
            let rects = layout.lineRects(in: manager, container: container)
            #expect(rects.count == 2)
            #expect(abs(rects[0].minY) < 0.01)
            #expect(abs(rects[1].minY - CGFloat(slots) * document.grid) < 0.01)
            #expect(layout.hiddenSlots(in: manager, container: container) == Set(1..<slots))
        }
        state = RuledTextCommands.resize(state, to: .body, document: document)
        storage.setAttributedString(state.text)
        #expect(layout.hiddenSlots(in: manager, container: container).isEmpty)
        #expect(layout.lineRects(in: manager, container: container)[1].minY == document.grid)
    }

    @Test func chineseSoftWrappingUsesRealGlyphBaselines() {
        let layout = RuledPageLayout(document: document)
        let storage = NSTextStorage(attributedString: sample(String(repeating: "中文 English g p y 123 测试自动换行。", count: 12)).text)
        let manager = NSLayoutManager()
        manager.delegate = layout
        manager.usesFontLeading = false
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: document.textWidth, height: 100_000))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        #expect(layout.lineRects(in: manager, container: container).count > 2)
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { rect, _, _, range, _ in
            let baseline = rect.minY + manager.location(forGlyphAt: range.location).y
            let slots = (baseline + document.baselineInset) / document.grid
            #expect(abs(slots - slots.rounded()) < 0.01)
        }
    }

    @Test func overflowIsDetectedBeforeApplyingExpansion() {
        let layout = RuledPageLayout(document: document)
        let state = sample(Array(repeating: "line", count: 25).joined(separator: "\n"))
        #expect(layout.fits(state.text))
        #expect(!layout.fits(RuledTextCommands.enlarged(state, document: document).text))
        #expect(state.text.string.components(separatedBy: "\n").count == 25)
    }

    @Test func pageIdentityAndLegacyBlocksRemainIndependent() throws {
        let schema = Schema([Course.self, NotePage.self, NoteBlock.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let ruled = NotePage(title: "Same title", order: 0)
        let legacy = NotePage(title: "Same title", order: 1)
        let code = NoteBlock(page: legacy, order: 0, blockType: .code, textContent: "print(42)")
        let drawing = NoteBlock(page: legacy, order: 1, blockType: .drawing, drawingData: Data([1, 2, 3]))
        legacy.blocks = [code, drawing]
        context.insert(ruled)
        context.insert(legacy)
        ruled.ruledDocumentData = try RuledTextContent(snapshot: sample()).encoded()
        try context.save()
        #expect(ruled.usesRuledPaper)
        #expect(!legacy.usesRuledPaper)
        ruled.ruledDocumentData = try RuledTextContent().encoded()
        try context.save()
        #expect(ruled.usesRuledPaper)
        #expect(legacy.blocks.map(\.textContent).contains("print(42)"))
        #expect(drawing.drawingData == Data([1, 2, 3]))
    }

    @Test func twoPagesSurviveClosingAndReopeningTemporaryStore() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("notes.store")
        let first = RuledTextContent(snapshot: RuledTextCommands.enlarged(sample(), document: document))
        let second = RuledTextContent(snapshot: sample("Second independent page"))

        func write() throws {
            let schema = Schema([Course.self, NotePage.self, NoteBlock.self])
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            for (order, content) in [first, second].enumerated() {
                let page = NotePage(title: "Same title", order: order)
                page.ruledDocumentData = try content.encoded()
                context.insert(page)
            }
            try context.save()
        }
        try write()
        let schema = Schema([Course.self, NotePage.self, NoteBlock.self])
        let reopened = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let pages = try ModelContext(reopened).fetch(FetchDescriptor<NotePage>(sortBy: [SortDescriptor(\.order)]))
        #expect(pages.count == 2)
        #expect(try RuledTextContent.decode(#require(pages[0].ruledDocumentData)) == first)
        #expect(try RuledTextContent.decode(#require(pages[1].ruledDocumentData)) == second)
    }

    #if os(macOS)
    @Test func nativeMacShiftReturnRoutesWithoutAddingNewlines() throws {
        let editor = RuledPageMacEditor(frame: CGRect(x: 0, y: 0, width: 800, height: 900))
        editor.load(RuledTextContent(snapshot: sample()))
        editor.textView.setSelectedRange(NSRange(location: 3, length: 0))
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .shift,
            timestamp: 0, windowNumber: 0, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
        ))
        editor.textView.keyDown(with: event)
        editor.textView.keyDown(with: event)
        #expect(editor.textView.string == sample().text.string)
        #expect(editor.textView.selectedRange() == NSRange(location: 3, length: 0))
        #expect(editor.textView.hiddenSlots == [1, 2])
        editor.textView.insertNewline(nil)
        #expect(editor.textView.string == "Lec\nture 1\nToday we study graphs.")
        let font = editor.textView.textStorage?.attribute(.font, at: 4, effectiveRange: nil) as? NSFont
        #expect(RuledTextSize.matching(font) == .body)
    }

    @Test func nativeMacCompositionDoesNotEnlargeOrLoseMarkedText() {
        let editor = RuledPageMacEditor(frame: .zero)
        editor.load(RuledTextContent())
        editor.textView.setMarkedText("拼", selectedRange: NSRange(location: 1, length: 0),
                                      replacementRange: NSRange(location: 0, length: 0))
        let marked = editor.textView.markedRange()
        let text = editor.textView.string
        editor.enlargeCurrentLine()
        #expect(editor.textView.markedRange() == marked)
        #expect(editor.textView.string == text)
        #expect(editor.textView.hiddenSlots.isEmpty)
    }

    @Test func nativeMacResizeKeepsLogicalWidthAndLineGeometry() {
        let editor = RuledPageMacEditor(frame: CGRect(x: 0, y: 0, width: 800, height: 900))
        editor.load(RuledTextContent(snapshot: sample(String(repeating: "中文 wrapping words ", count: 15))))
        guard let manager = editor.textView.layoutManager, let container = editor.textView.textContainer else {
            Issue.record("Missing text system")
            return
        }
        let before = editor.pageLayout.lineRects(in: manager, container: container)
        editor.frame.size = CGSize(width: 450, height: 600)
        editor.layoutSubtreeIfNeeded()
        #expect(container.size.width == document.textWidth)
        #expect(editor.pageLayout.lineRects(in: manager, container: container) == before)
    }

    @Test func nativeMacCommandUndoAndSelectionArePreserved() {
        let editor = RuledPageMacEditor(frame: CGRect(x: 0, y: 0, width: 800, height: 900))
        editor.load(RuledTextContent(snapshot: sample()))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 800, height: 900),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor
        window.makeFirstResponder(editor.textView)
        editor.textView.setSelectedRange(NSRange(location: 3, length: 0))
        let undo = editor.textView.undoManager
        #expect(undo != nil)
        undo?.beginUndoGrouping()
        editor.enlargeCurrentLine()
        undo?.endUndoGrouping()
        #expect(editor.textView.selectedRange().location == 3)
        #expect(editor.textView.string == sample().text.string)
        undo?.undo()
        #expect(editor.textView.string == sample().text.string)
        let font = editor.textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(RuledTextSize.matching(font) == .body)
    }
    #endif
}
