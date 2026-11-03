import SwiftUI

#if canImport(UIKit)
import UIKit

struct CodeTextEditor: UIViewRepresentable {
    @Binding var text: String
    let language: CodeBlockLanguage
    let isScrollEnabled: Bool

    func makeUIView(context: Context) -> CodeUITextView {
        let view = CodeUITextView()
        view.delegate = context.coordinator
        view.font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        view.autocapitalizationType = .none
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.keyboardType = .asciiCapable
        view.inlinePredictionType = .no
        view.writingToolsBehavior = .none
        view.text = text
        view.accessibilityLabel = "Code"
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: CodeUITextView, context: Context) {
        context.coordinator.parent = self
        view.language = language
        view.isScrollEnabled = isScrollEnabled
        // Avoid resetting selection, composition, and undo during ordinary binding updates.
        if view.text != text, view.markedTextRange == nil {
            let selection = view.selectedRange
            view.text = text
            let length = (text as NSString).length
            let location = min(selection.location, length)
            view.selectedRange = NSRange(location: location, length: min(selection.length, length - location))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeTextEditor

        init(_ parent: CodeTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

final class CodeUITextView: UITextView {
    var language: CodeBlockLanguage = .plainText
    private var isPasting = false

    override func insertText(_ text: String) {
        guard text == "\n", !isPasting, markedTextRange == nil,
              let insertion = CodeIndentationEngine.insertion(for: self.text, selection: selectedRange, language: language) else {
            super.insertText(text)
            return
        }
        // Native insertion owns selection replacement, cursor placement, and undo registration.
        super.insertText(insertion)
    }

    override func paste(_ sender: Any?) {
        isPasting = true
        defer { isPasting = false }
        super.paste(sender)
    }
}

#elseif canImport(AppKit)
import AppKit

struct CodeTextEditor: NSViewRepresentable {
    @Binding var text: String
    let language: CodeBlockLanguage
    let isScrollEnabled: Bool

    func makeNSView(context: Context) -> CodeEditorScrollView {
        let scrollView = CodeEditorScrollView()
        scrollView.drawsBackground = false
        let view = CodeNSTextView(frame: .zero)
        view.delegate = context.coordinator
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        view.textColor = .textColor
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 5, height: 8)
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.isGrammarCheckingEnabled = false
        view.isAutomaticTextCompletionEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.isAutomaticDataDetectionEnabled = false
        view.writingToolsBehavior = .none
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.string = text
        view.setAccessibilityLabel("Code")
        scrollView.documentView = view
        updateNSView(scrollView, context: context)
        return scrollView
    }

    func updateNSView(_ scrollView: CodeEditorScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.allowsVerticalScrolling = isScrollEnabled
        scrollView.hasVerticalScroller = isScrollEnabled
        guard let view = scrollView.documentView as? CodeNSTextView else { return }
        view.language = language
        if view.string != text, !view.hasMarkedText() {
            let selection = view.selectedRange()
            view.string = text
            let length = (text as NSString).length
            let location = min(selection.location, length)
            view.setSelectedRange(NSRange(location: location, length: min(selection.length, length - location)))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeTextEditor

        init(_ parent: CodeTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}

final class CodeNSTextView: NSTextView {
    var language: CodeBlockLanguage = .plainText

    override func insertNewline(_ sender: Any?) {
        guard !hasMarkedText(), selectedRanges.count == 1,
              let insertion = CodeIndentationEngine.insertion(for: string, selection: selectedRange(), language: language) else {
            super.insertNewline(sender)
            return
        }
        insertText(insertion, replacementRange: selectedRange())
    }
}

final class CodeEditorScrollView: NSScrollView {
    var allowsVerticalScrolling = true

    override func scrollWheel(with event: NSEvent) {
        if !allowsVerticalScrolling || abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            // Inline scroll gestures belong to the surrounding document; horizontal ones
            // belong to the existing horizontal CodeBlock scroll container.
            nextResponder?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
}
#endif
