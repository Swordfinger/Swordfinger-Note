#if canImport(UIKit)
import UIKit
typealias RuledFont = UIFont
#else
import AppKit
typealias RuledFont = NSFont
#endif

/// The document stays in these coordinates regardless of the viewport.
struct RuledPageDocument {
    let size = CGSize(width: 612, height: 792)
    let margin: CGFloat = 42
    let grid: CGFloat = 28
    let baselineInset: CGFloat = 8

    var textWidth: CGFloat { size.width - margin * 2 }
    var capacity: CGFloat { floor((size.height - margin * 2) / grid) * grid }

    func baseline(forSlot slot: Int) -> CGFloat {
        margin + CGFloat(slot) * grid - baselineInset
    }
}

enum RuledTextSize: Int, CaseIterable, Codable {
    case body = 1
    case heading = 2
    case largeHeading = 3

    var title: String {
        switch self {
        case .body: "正文"
        case .heading: "大标题"
        case .largeHeading: "特大标题"
        }
    }

    var font: RuledFont {
        switch self {
        case .body: .systemFont(ofSize: 16)
        case .heading: .systemFont(ofSize: 32, weight: .semibold)
        case .largeHeading: .systemFont(ofSize: 48, weight: .semibold)
        }
    }

    func attributes(for document: RuledPageDocument) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = CGFloat(rawValue) * document.grid
        paragraph.maximumLineHeight = paragraph.minimumLineHeight
        #if canImport(UIKit)
        let color = UIColor.label
        #else
        let color = NSColor.labelColor
        #endif
        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    }

    static func matching(_ font: RuledFont?) -> RuledTextSize {
        guard let font else { return .body }
        if font.pointSize >= 40 { return .largeHeading }
        if font.pointSize >= 24 { return .heading }
        return .body
    }
}

/// TextKit supplies real soft-wrapped glyph ranges. No character-count estimates.
final class RuledPageLayout: NSObject, NSLayoutManagerDelegate {
    let document: RuledPageDocument

    init(document: RuledPageDocument) {
        self.document = document
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<CGRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<CGRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer,
        forGlyphRange glyphRange: NSRange
    ) -> Bool {
        let characters = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        var slots = 1
        layoutManager.textStorage?.enumerateAttribute(.font, in: characters) { value, _, _ in
            slots = max(slots, RuledTextSize.matching(value as? RuledFont).rawValue)
        }
        let height = CGFloat(slots) * document.grid
        lineFragmentRect.pointee.size.height = height
        lineFragmentUsedRect.pointee.size.height = height
        baselineOffset.pointee = height - document.baselineInset
        return true
    }

    func lineRects(in manager: NSLayoutManager, container: NSTextContainer) -> [CGRect] {
        manager.ensureLayout(for: container)
        var result: [CGRect] = []
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { rect, _, _, _, _ in
            result.append(rect)
        }
        return result
    }

    func hiddenSlots(in manager: NSLayoutManager, container: NSTextContainer) -> Set<Int> {
        var hidden: Set<Int> = []
        for rect in lineRects(in: manager, container: container) {
            let first = Int((rect.minY / document.grid).rounded()) + 1
            let count = Int((rect.height / document.grid).rounded())
            if count > 1 {
                hidden.formUnion(first..<(first + count - 1))
            }
        }
        return hidden
    }

    func fits(_ contents: NSAttributedString, trailingSize: RuledTextSize = .body) -> Bool {
        let storage = NSTextStorage(attributedString: contents)
        let manager = NSLayoutManager()
        manager.delegate = self
        manager.usesFontLeading = false
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: document.textWidth, height: 100_000))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        let rects = lineRects(in: manager, container: container)
        var height = rects.last?.maxY ?? 0
        if contents.length == 0 || contents.string.hasSuffix("\n") {
            height += CGFloat(trailingSize.rawValue) * document.grid
        }
        return height <= document.capacity + 0.5
    }

    func occupiedHeight(in manager: NSLayoutManager, container: NSTextContainer) -> CGFloat {
        let last = lineRects(in: manager, container: container).last?.maxY ?? 0
        // Include the insertion line after Return, not just the last visible glyph.
        return max(last, manager.extraLineFragmentRect.maxY)
    }
}
