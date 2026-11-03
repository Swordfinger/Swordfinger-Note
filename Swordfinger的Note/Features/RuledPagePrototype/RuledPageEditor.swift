#if canImport(UIKit)
import UIKit

final class RuledPaperView: UIView {
    let document: RuledPageDocument
    var hiddenSlots: Set<Int> = [] {
        didSet { setNeedsDisplay() }
    }

    init(document: RuledPageDocument) {
        self.document = document
        super.init(frame: CGRect(origin: .zero, size: document.size))
        isUserInteractionEnabled = false
        backgroundColor = .systemBackground
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setStrokeColor(UIColor.label.withAlphaComponent(0.22).cgColor)
        context.setLineWidth(0.5)
        let count = Int(document.capacity / document.grid)
        for slot in 1...count where !hiddenSlots.contains(slot) {
            let baseline = document.baseline(forSlot: slot)
            context.move(to: CGPoint(x: document.margin, y: baseline))
            context.addLine(to: CGPoint(x: document.size.width - document.margin, y: baseline))
        }
        context.strokePath()
    }
}

final class RuledTextView: UITextView {
    var returnCommand: (() -> Void)?
    var enlargeCommand: (() -> Void)?
    private var isPasting = false

    override var keyCommands: [UIKeyCommand]? {
        guard markedTextRange == nil else { return super.keyCommands }
        let command = UIKeyCommand(input: "\r", modifierFlags: .shift, action: #selector(enlargeLine))
        command.wantsPriorityOverSystemBehavior = true
        command.discoverabilityTitle = "扩大当前行"
        return (super.keyCommands ?? []) + [command]
    }

    @objc private func enlargeLine() {
        guard markedTextRange == nil else { return }
        enlargeCommand?()
    }
    var document = RuledPageDocument()

    override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        // TextKit's extra fragment inherits the previous paragraph's metrics.
        // For the empty insertion line, use the same grid baseline as its next glyph.
        let atEnd = offset(from: beginningOfDocument, to: position) == textStorage.length
        if atEnd && (textStorage.length == 0 || textStorage.string.hasSuffix("\n")) {
            layoutManager.ensureLayout(for: textContainer)
            var nextTop: CGFloat = 0
            if layoutManager.numberOfGlyphs > 0 {
                nextTop = layoutManager.lineFragmentRect(
                    forGlyphAt: layoutManager.numberOfGlyphs - 1, effectiveRange: nil
                ).maxY
            }
            let size = RuledTextSize.matching(typingAttributes[.font] as? UIFont)
            let baseline = nextTop + CGFloat(size.rawValue) * document.grid - document.baselineInset
            rect.origin.y = textContainerInset.top + baseline - size.font.ascender
            rect.size.height = size.font.lineHeight
        }
        return rect
    }

    override func insertText(_ text: String) {
        if text == "\n", markedTextRange == nil, !isPasting, let returnCommand {
            returnCommand()
        } else {
            super.insertText(text)
        }
    }

    override func paste(_ sender: Any?) {
        // Keep external rich text and attachments from bypassing the three trial sizes.
        if let plainText = UIPasteboard.general.string {
            isPasting = true
            defer { isPasting = false }
            super.insertText(plainText)
        }
    }
}

private final class RuledPageViewport: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

final class RuledPageEditorController: UIViewController, UITextViewDelegate {
    let document = RuledPageDocument()
    let pageLayout: RuledPageLayout
    let textView: RuledTextView
    private let paper: RuledPaperView
    private let viewport = RuledPageViewport()
    private var lastViewportSize: CGSize = .zero
    private let pageTitle = UILabel()
    var titleText = ""
    var onContentChanged: ((RuledTextContent) -> Void)?
    private var trailingSize: RuledTextSize = .body
    private let status = UILabel()
    private var applyingStyle = false

    init() {
        let document = RuledPageDocument()
        let layout = RuledPageLayout(document: document)
        let manager = NSLayoutManager()
        manager.delegate = layout
        manager.usesFontLeading = false
        let storage = NSTextStorage()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: document.textWidth, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        manager.addTextContainer(container)
        pageLayout = layout
        textView = RuledTextView(frame: CGRect(origin: .zero, size: document.size), textContainer: container)
        paper = RuledPaperView(document: document)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        pageTitle.font = .preferredFont(forTextStyle: .largeTitle)
        pageTitle.text = titleText
        viewport.addSubview(pageTitle)
        status.font = .preferredFont(forTextStyle: .caption1)
        status.numberOfLines = 0
        status.isHidden = true
        let stack = UIStackView(arrangedSubviews: [status, viewport])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8)
        ])
        viewport.onLayout = { [weak self] in self?.layoutPaper() }
        viewport.keyboardDismissMode = .interactive
        viewport.addSubview(textView)
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: document.margin, left: document.margin, bottom: document.margin, right: document.margin)
        textView.typingAttributes = RuledTextSize.body.attributes(for: document)
        textView.isScrollEnabled = false
        textView.alwaysBounceVertical = false
        textView.smartInsertDeleteType = .no
        textView.accessibilityLabel = "Letter 横线纸正文"
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.insertSubview(paper, at: 0)
        textView.returnCommand = { [weak self] in self?.insertReturn() }
        textView.enlargeCommand = { [weak self] in self?.enlargeCurrentLine() }
        let accessory = UIToolbar()
        accessory.items = [
            UIBarButtonItem(title: "扩大当前行", style: .plain, target: self, action: #selector(enlargeCurrentLine)),
            UIBarButtonItem(title: "恢复正文", style: .plain, target: self, action: #selector(resetSize)),
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "撤销", style: .plain, target: self, action: #selector(undoEdit))
        ]
        accessory.sizeToFit()
        textView.inputAccessoryView = accessory

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutPaper()
    }

    private func layoutPaper() {
        guard viewport.bounds.width > 32, viewport.bounds.size != lastViewportSize else { return }
        lastViewportSize = viewport.bounds.size
        // Transform only the presentation; never change the text container's width.
        let scale = max(0.1, min((viewport.bounds.width - 16) / document.size.width, 1.6))
        textView.transform = .identity
        textView.bounds = CGRect(origin: textView.bounds.origin, size: document.size)
        textView.transform = CGAffineTransform(scaleX: scale, y: scale)
        let headerHeight: CGFloat = titleText.isEmpty ? 0 : 60
        pageTitle.frame = CGRect(x: 8, y: 0, width: viewport.bounds.width - 16, height: headerHeight)
        textView.center = CGPoint(x: viewport.bounds.width / 2, y: document.size.height * scale / 2 + headerHeight + 8)
        viewport.contentSize = CGSize(width: viewport.bounds.width, height: document.size.height * scale + headerHeight + 16)
    }

    func load(_ content: RuledTextContent) {
        loadViewIfNeeded()
        let state = content.snapshot(document: document)
        textView.textStorage.setAttributedString(state.text)
        textView.selectedRange = state.selection
        textView.typingAttributes = state.typingSize.attributes(for: document)
        trailingSize = state.trailingSize
        refresh()
    }

    func updateTitle(_ title: String) {
        titleText = title
        pageTitle.text = title
        view.setNeedsLayout()
    }

    private var snapshot: RuledEditSnapshot {
        RuledEditSnapshot(text: NSAttributedString(attributedString: textView.textStorage),
                          selection: textView.selectedRange,
                          typingSize: RuledTextSize.matching(textView.typingAttributes[.font] as? UIFont),
                          trailingSize: trailingSize)
    }

    @objc func enlargeCurrentLine() {
        guard textView.markedTextRange == nil,
              RuledTextCommands.currentSize(snapshot) != .largeHeading else { return }
        commit(RuledTextCommands.enlarged(snapshot, document: document), action: "扩大当前行")
    }

    @objc private func resetSize() { apply(size: .body) }
    @objc private func undoEdit() { textView.undoManager?.undo() }

    func apply(size: RuledTextSize) {
        guard textView.markedTextRange == nil else { return }
        commit(RuledTextCommands.resize(snapshot, to: size, document: document), action: "字号")
    }

    func insertReturn() {
        guard textView.markedTextRange == nil else { return }
        commit(RuledTextCommands.insertingReturn(snapshot, document: document), action: "换行")
    }

    private func commit(_ state: RuledEditSnapshot, action: String) {
        guard pageLayout.fits(state.text, trailingSize: state.trailingSize) else {
            showMessage("本页已满，操作未应用。请删减文字或缩小字号。")
            return
        }
        restore(state)
        textView.undoManager?.setActionName(action)
    }

    private func restore(_ state: RuledEditSnapshot) {
        let before = snapshot
        textView.undoManager?.registerUndo(withTarget: self) { target in target.restore(before) }
        applyingStyle = true
        textView.textStorage.setAttributedString(state.text)
        textView.selectedRange = state.selection
        textView.typingAttributes = state.typingSize.attributes(for: document)
        trailingSize = state.trailingSize
        applyingStyle = false
        refresh()
        onContentChanged?(RuledTextContent(snapshot: snapshot))
    }

    private func showMessage(_ message: String) {
        status.text = message
        status.isHidden = false
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView.selectedRange.location == textView.textStorage.length {
            trailingSize = RuledTextSize.matching(textView.typingAttributes[.font] as? UIFont)
        }
        refresh()
        onContentChanged?(RuledTextContent(snapshot: snapshot))
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !applyingStyle, textView.markedTextRange == nil else { return }
        if textView.selectedRange.location == textView.textStorage.length,
           textView.text.isEmpty || textView.text.hasSuffix("\n") {
            applyingStyle = true
            textView.typingAttributes = trailingSize.attributes(for: document)
            applyingStyle = false
        }
        revealCaret()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Never interrupt IME composition or prevent deletion/recovery.
        guard textView.markedTextRange == nil, !text.isEmpty else { return true }
        let candidate = NSMutableAttributedString(attributedString: textView.textStorage)
        candidate.replaceCharacters(in: range, with: NSAttributedString(string: text, attributes: textView.typingAttributes))
        if !fits(candidate) {
            showMessage("本页已满：此次输入未插入。请删减文字或缩小字号后继续。")
            return false
        }
        return true
    }

    func fits(_ contents: NSAttributedString) -> Bool {
        pageLayout.fits(contents, trailingSize: trailingSize)
    }

    private func refresh() {
        let manager = textView.layoutManager
        paper.hiddenSlots = pageLayout.hiddenSlots(in: manager, container: textView.textContainer)
        let height = pageLayout.occupiedHeight(in: manager, container: textView.textContainer)
        let overflow = height > document.capacity + 0.5
        // IME commits and enlarging existing text may overflow. Keep every character
        // editable in the scrollable recovery area instead of truncating or reverting composition.
        textView.isScrollEnabled = overflow
        if !overflow { textView.setContentOffset(.zero, animated: false) }
        status.isHidden = !overflow
        if overflow {
            showMessage("本页已满：超出纸张的文字仍保留，可在编辑区上下滚动；请缩小字号或删减。")
        }
        if textView.text.isEmpty || textView.text.hasSuffix("\n") {
            let top = pageLayout.lineRects(in: manager, container: textView.textContainer).last?.maxY ?? 0
            let first = Int((top / document.grid).rounded()) + 1
            if trailingSize.rawValue > 1 {
                paper.hiddenSlots.formUnion(first..<(first + trailingSize.rawValue - 1))
            }
        }
        paper.setNeedsDisplay()
        revealCaret()
    }

    private func revealCaret() {
        guard textView.isFirstResponder, let selection = textView.selectedTextRange else { return }
        let caret = textView.caretRect(for: selection.end)
        let rect = textView.convert(caret.insetBy(dx: -8, dy: -20), to: viewport)
        viewport.scrollRectToVisible(rect, animated: false)
    }
}
#endif
