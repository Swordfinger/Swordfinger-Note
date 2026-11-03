#if DEBUG && canImport(UIKit)
import Testing
import UIKit
@testable import Swordfinger的Note

@MainActor
struct RuledPagePrototypeTests {
    private func editor(_ text: String) -> RuledPageEditorController {
        let controller = RuledPageEditorController()
        controller.loadViewIfNeeded()
        controller.textView.textStorage.setAttributedString(
            NSAttributedString(string: text, attributes: RuledTextSize.body.attributes(for: controller.document))
        )
        controller.textView.selectedRange = NSRange(location: 0, length: 0)
        return controller
    }

    @Test func softWrappedChineseAndEnglishUseActualGridBaselines() {
        let controller = editor(String(repeating: "中文课程笔记 English words and natural wrapping. ", count: 12))
        let manager = controller.textView.layoutManager
        let container = controller.textView.textContainer
        let rects = controller.pageLayout.lineRects(in: manager, container: container)
        #expect(rects.count > 3)
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { rect, _, _, range, _ in
            let baseline = rect.minY + manager.location(forGlyphAt: range.location).y
            let gridIndex = (baseline + controller.document.baselineInset) / controller.document.grid
            #expect(abs(gridIndex - gridIndex.rounded()) < 0.01)
            #expect(abs(rect.height - controller.document.grid) < 0.01)
        }
    }

    @Test(arguments: [RuledTextSize.heading, .largeHeading])
    func resizingTitleMovesBodyAndRestoresRules(size: RuledTextSize) {
        let controller = editor("Lecture 1\n下一行正文")
        let manager = controller.textView.layoutManager
        let container = controller.textView.textContainer
        controller.apply(size: size)
        let expanded = controller.pageLayout.lineRects(in: manager, container: container)
        #expect(expanded.count == 2)
        #expect(expanded[0].minY == 0)
        #expect(expanded[0].height == CGFloat(size.rawValue) * controller.document.grid)
        #expect(expanded[1].minY == expanded[0].maxY)
        #expect(controller.pageLayout.hiddenSlots(in: manager, container: container) == Set(1..<size.rawValue))
        controller.apply(size: .body)
        let restored = controller.pageLayout.lineRects(in: manager, container: container)
        #expect(restored[1].minY == controller.document.grid)
        #expect(controller.pageLayout.hiddenSlots(in: manager, container: container).isEmpty)
        #expect(controller.textView.text == "Lecture 1\n下一行正文")
    }

    @Test(arguments: [RuledTextSize.heading, .largeHeading])
    func returnAfterHeadingStartsBodyBelowOccupiedSlots(size: RuledTextSize) {
        let controller = editor("Lecture 1")
        controller.apply(size: size)
        controller.textView.selectedRange = NSRange(location: controller.textView.textStorage.length, length: 0)
        controller.textView.insertText("\n")
        #expect(RuledTextSize.matching(controller.textView.typingAttributes[.font] as? UIFont) == .body)
        let caret = controller.textView.caretRect(for: controller.textView.endOfDocument)
        let expectedBaseline = controller.document.margin
            + CGFloat(size.rawValue + 1) * controller.document.grid - controller.document.baselineInset
        #expect(abs(caret.minY + RuledTextSize.body.font.ascender - expectedBaseline) < 0.01)
        controller.textView.insertText("正文")
        let rects = controller.pageLayout.lineRects(in: controller.textView.layoutManager, container: controller.textView.textContainer)
        #expect(rects.count == 2)
        #expect(rects[1].minY == CGFloat(size.rawValue) * controller.document.grid)
        #expect(rects[1].height == controller.document.grid)
    }

    @Test func viewportResizeDoesNotReflowDocument() {
        let controller = editor(String(repeating: "同一行 remains stable across rotation. ", count: 8))
        controller.view.frame = CGRect(x: 0, y: 0, width: 800, height: 1000)
        controller.view.layoutIfNeeded()
        let before = controller.pageLayout.lineRects(in: controller.textView.layoutManager, container: controller.textView.textContainer)
        controller.view.frame = CGRect(x: 0, y: 0, width: 1100, height: 600)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let after = controller.pageLayout.lineRects(in: controller.textView.layoutManager, container: controller.textView.textContainer)
        #expect(controller.textView.textContainer.size.width == controller.document.textWidth)
        #expect(before == after)
    }

    @Test func fullPageRejectsInsertionWithoutRemovingExistingText() {
        let controller = editor("Existing text")
        let tooMuch = String(repeating: "更多文字 more text\n", count: 100)
        #expect(!controller.textView(controller.textView, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: tooMuch))
        #expect(controller.textView.text == "Existing text")
        #expect(controller.textView(controller.textView, shouldChangeTextIn: NSRange(location: 0, length: 1), replacementText: ""))
    }

    @Test func headingSoftWrapReservesSlotsForEveryVisualLine() {
        let controller = editor(String(repeating: "长标题 Heading ", count: 8))
        controller.apply(size: .largeHeading)
        let rects = controller.pageLayout.lineRects(in: controller.textView.layoutManager, container: controller.textView.textContainer)
        #expect(rects.count > 1)
        for (index, rect) in rects.enumerated() {
            #expect(rect.minY == CGFloat(index * 3) * controller.document.grid)
            #expect(rect.height == controller.document.grid * 3)
        }
    }
}
#endif
