#if os(macOS)
import AppKit

final class RuledMacTextView: NSTextView {
    let document = RuledPageDocument()
    var hiddenSlots: Set<Int> = []
    var returnCommand: (() -> Void)?
    var enlargeCommand: (() -> Void)?
    private var confirmingComposition = false

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        confirmingComposition = hasMarkedText()
        defer { confirmingComposition = false }
        if isReturn, event.modifierFlags.contains(.shift), !confirmingComposition {
            enlargeCommand?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func insertNewline(_ sender: Any?) {
        guard !hasMarkedText(), !confirmingComposition, let returnCommand else {
            super.insertNewline(sender)
            return
        }
        returnCommand()
    }

    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()
        NSColor.labelColor.withAlphaComponent(0.22).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.5
        for slot in 1...Int(document.capacity / document.grid) where !hiddenSlots.contains(slot) {
            let baseline = document.baseline(forSlot: slot)
            path.move(to: NSPoint(x: document.margin, y: baseline))
            path.line(to: NSPoint(x: document.size.width - document.margin, y: baseline))
        }
        path.stroke()
        super.draw(dirtyRect)
    }
}

private final class RuledMacPageSurface: NSView {
    override var isFlipped: Bool { true }
}

final class RuledPageMacEditor: NSView, NSTextViewDelegate {
    let document = RuledPageDocument()
    let pageLayout: RuledPageLayout
    let textView: RuledMacTextView
    private let scrollView = NSScrollView()
    private let surface = RuledMacPageSurface()
    private let titleLabel = NSTextField(labelWithString: "")
    private let status = NSTextField(wrappingLabelWithString: "")
    private var trailingSize: RuledTextSize = .body
    private var applying = false
    private var lastWidth: CGFloat = 0
    var onContentChanged: ((RuledTextContent) -> Void)?

    override init(frame frameRect: NSRect) {
        pageLayout = RuledPageLayout(document: RuledPageDocument())
        let manager = NSLayoutManager()
        manager.delegate = pageLayout
        manager.usesFontLeading = false
        let storage = NSTextStorage()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: document.textWidth, height: 100_000))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        manager.addTextContainer(container)
        textView = RuledMacTextView(frame: CGRect(origin: .zero, size: document.size), textContainer: container)
        super.init(frame: frameRect)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = surface
        addSubview(scrollView)
        addSubview(status)
        status.isHidden = true
        surface.addSubview(titleLabel)
        surface.addSubview(textView)
        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        textView.delegate = self
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.textContainerInset = CGSize(width: document.margin, height: document.margin)
        textView.typingAttributes = RuledTextSize.body.attributes(for: document)
        textView.setAccessibilityLabel("Letter 横线纸正文")
        textView.returnCommand = { [weak self] in self?.insertReturn() }
        textView.enlargeCommand = { [weak self] in self?.enlargeCurrentLine() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func layout() {
        super.layout()
        let statusHeight: CGFloat = status.isHidden ? 0 : 44
        status.frame = CGRect(x: 8, y: bounds.height - statusHeight, width: bounds.width - 16, height: statusHeight)
        scrollView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - statusHeight)
        titleLabel.frame = CGRect(x: 8, y: 8, width: document.size.width - 16, height: 44)
        textView.frame.origin = CGPoint(x: 0, y: 60)
        surface.frame.size = CGSize(width: document.size.width, height: textView.frame.height + 60)
        if abs(bounds.width - lastWidth) > 0.5, bounds.width > 0 {
            lastWidth = bounds.width
            scrollView.minMagnification = 0.1
            scrollView.maxMagnification = 1.6
            scrollView.setMagnification(min(1.6, max(0.1, (bounds.width - 20) / document.size.width)), centeredAt: .zero)
        }
    }

    func load(_ content: RuledTextContent) {
        let state = content.snapshot(document: document)
        textView.textStorage?.setAttributedString(state.text)
        textView.setSelectedRange(state.selection)
        textView.typingAttributes = state.typingSize.attributes(for: document)
        trailingSize = state.trailingSize
        refresh()
    }

    func updateTitle(_ title: String) { titleLabel.stringValue = title }

    private var snapshot: RuledEditSnapshot {
        RuledEditSnapshot(text: NSAttributedString(attributedString: textView.attributedString()),
                          selection: textView.selectedRange(),
                          typingSize: RuledTextSize.matching(textView.typingAttributes[.font] as? NSFont),
                          trailingSize: trailingSize)
    }

    func enlargeCurrentLine() {
        guard !textView.hasMarkedText(),
              RuledTextCommands.currentSize(snapshot) != .largeHeading else { return }
        commit(RuledTextCommands.enlarged(snapshot, document: document), action: "扩大当前行")
    }

    func insertReturn() {
        guard !textView.hasMarkedText() else { return }
        commit(RuledTextCommands.insertingReturn(snapshot, document: document), action: "换行")
    }

    private func commit(_ state: RuledEditSnapshot, action: String) {
        guard pageLayout.fits(state.text, trailingSize: state.trailingSize) else {
            showMessage("本页已满，操作未应用。请删减文字。")
            return
        }
        textView.breakUndoCoalescing()
        restore(state)
        textView.undoManager?.setActionName(action)
        textView.breakUndoCoalescing()
    }

    private func restore(_ state: RuledEditSnapshot) {
        let before = snapshot
        textView.undoManager?.registerUndo(withTarget: self) { target in target.restore(before) }
        applying = true
        textView.textStorage?.setAttributedString(state.text)
        textView.setSelectedRange(state.selection)
        textView.typingAttributes = state.typingSize.attributes(for: document)
        trailingSize = state.trailingSize
        applying = false
        refresh()
        onContentChanged?(RuledTextContent(snapshot: snapshot))
        textView.scrollRangeToVisible(state.selection)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !applying, !textView.hasMarkedText() else { return }
        if textView.selectedRange().location == (textView.string as NSString).length,
           textView.string.isEmpty || textView.string.hasSuffix("\n") {
            applying = true
            textView.typingAttributes = trailingSize.attributes(for: document)
            applying = false
        }
    }

    func textDidChange(_ notification: Notification) {
        guard !applying else { return }
        if textView.selectedRange().location == (textView.string as NSString).length {
            trailingSize = RuledTextSize.matching(textView.typingAttributes[.font] as? NSFont)
        }
        refresh()
        onContentChanged?(RuledTextContent(snapshot: snapshot))
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard !textView.hasMarkedText(), let replacementString, !replacementString.isEmpty else { return true }
        let candidate = NSMutableAttributedString(attributedString: textView.attributedString())
        candidate.replaceCharacters(in: affectedCharRange, with: NSAttributedString(string: replacementString, attributes: textView.typingAttributes))
        guard pageLayout.fits(candidate, trailingSize: trailingSize) else {
            showMessage("本页已满：此次输入未插入，请删减后继续。")
            return false
        }
        return true
    }

    private func showMessage(_ message: String) {
        status.stringValue = message
        status.isHidden = false
        needsLayout = true
    }

    private func refresh() {
        guard let manager = textView.layoutManager, let container = textView.textContainer else { return }
        textView.hiddenSlots = pageLayout.hiddenSlots(in: manager, container: container)
        let rects = pageLayout.lineRects(in: manager, container: container)
        var height = rects.last?.maxY ?? 0
        if textView.string.isEmpty || textView.string.hasSuffix("\n") {
            let first = Int((height / document.grid).rounded()) + 1
            if trailingSize.rawValue > 1 {
                textView.hiddenSlots.formUnion(first..<(first + trailingSize.rawValue - 1))
            }
            height += CGFloat(trailingSize.rawValue) * document.grid
        }
        let overflow = height > document.capacity + 0.5
        status.isHidden = !overflow
        if overflow { showMessage("本页已满：超出纸张的文字仍保留，请删减。") }
        // Overflow from an IME commit remains reachable, without adding another page.
        textView.frame.size = CGSize(width: document.size.width, height: max(document.size.height, height + document.margin * 2))
        textView.needsDisplay = true
        needsLayout = true
    }
}
#endif
