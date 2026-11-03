import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import FingerNoteCode
#else
@testable import Swordfinger的Note
#endif

#if canImport(AppKit)
import AppKit
import SwiftUI

@MainActor
struct CodeTextEditorTests {
    @Test func nativeReturnKeepsCursorInMiddleAndCanUndoAndRedo() throws {
        let view = CodeNSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        _ = NSApplication.shared
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = view
        window.makeFirstResponder(view)
        view.allowsUndo = true
        view.language = .python
        view.string = "    if x:rest\nlast"
        view.setSelectedRange(NSRange(location: 9, length: 0))
        let undoManager = try #require(view.undoManager)
        undoManager.beginUndoGrouping()
        view.insertNewline(nil)
        undoManager.endUndoGrouping()
        #expect(view.string == "    if x:\n        rest\nlast")
        #expect(view.selectedRange() == NSRange(location: 18, length: 0))
        #expect(view.undoManager?.canUndo == true)
        view.undoManager?.undo()
        #expect(view.string == "    if x:rest\nlast")
        view.undoManager?.redo()
        #expect(view.string == "    if x:\n        rest\nlast")
    }

    @Test func nativeReturnReplacesSelectionAndRespectsLanguageChanges() {
        let view = CodeNSTextView(frame: .zero)
        view.string = "if x: remove"
        view.setSelectedRange(NSRange(location: 5, length: 7))
        view.language = .python
        view.insertNewline(nil)
        #expect(view.string == "if x:\n")
        #expect(view.selectedRange().location == 6)
        view.string = "if x:"
        view.setSelectedRange(NSRange(location: 5, length: 0))
        view.language = .plainText
        view.insertNewline(nil)
        #expect(view.string == "if x:\n")
    }

    @Test func insertingSourceTextDoesNotReindentIt() {
        let view = CodeNSTextView(frame: .zero)
        view.language = .python
        view.string = "if x:"
        view.setSelectedRange(NSRange(location: 5, length: 0))
        view.insertText("\n", replacementRange: view.selectedRange())
        view.insertText("  value\nnext", replacementRange: view.selectedRange())
        #expect(view.string == "if x:\n  value\nnext")
    }
    @Test(arguments: [false, true])
    func hostedEditorHasUsableLayoutAndUpdatesBinding(isScrollEnabled: Bool) throws {
        _ = NSApplication.shared
        var source = "if x:"
        let editor = CodeTextEditor(text: Binding(get: { source }, set: { source = $0 }), language: .python, isScrollEnabled: isScrollEnabled)
        let host = NSHostingView(rootView: editor.frame(width: 520, height: 180))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 180), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let view = try #require(descendant(CodeNSTextView.self, in: host))
        let scrollView = try #require(view.enclosingScrollView as? CodeEditorScrollView)
        #expect(view.bounds.width >= 500)
        #expect(view.bounds.height > 0)
        #expect((view.textContainer?.containerSize.width ?? 0) > 0)
        #expect(scrollView.allowsVerticalScrolling == isScrollEnabled)
        #expect(!view.isAutomaticQuoteSubstitutionEnabled)
        #expect(!view.isAutomaticDashSubstitutionEnabled)
        #expect(!view.isAutomaticTextReplacementEnabled)
        #expect(!view.isAutomaticSpellingCorrectionEnabled)
        #expect(!view.isContinuousSpellCheckingEnabled)
        #expect(!view.isGrammarCheckingEnabled)
        window.makeFirstResponder(view)
        view.setSelectedRange(NSRange(location: 5, length: 0))
        view.insertNewline(nil)
        #expect(source == "if x:\n    ")
        #expect(view.selectedRange().location == 10)
    }

    private func descendant<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        return view.subviews.lazy.compactMap { descendant(type, in: $0) }.first
    }

}
#endif
