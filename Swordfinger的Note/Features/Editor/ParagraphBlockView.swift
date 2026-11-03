//
//  ParagraphBlockView.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import SwiftUI
import SwiftData

struct ParagraphBlockView: View {
    @Bindable var block: NoteBlock
    let onTextChanged: () -> Void

    var body: some View {
        TextEditor(text: $block.textContent)
            .font(.body)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(minHeight: editorHeight)
            .padding(8)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
            .onChange(of: block.textContent) { _, _ in
                onTextChanged()
            }
    }

    private var editorHeight: CGFloat {
        let lineCount = block.textContent
            .components(separatedBy: .newlines)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 79) / 80)
            }

        return max(80, CGFloat(lineCount) * 22 + 36)
    }
}

#Preview {
    ParagraphBlockView(
        block: NoteBlock(order: 0, blockType: .paragraph, textContent: "Paragraph block"),
        onTextChanged: {}
    )
    .padding()
    .modelContainer(for: [Item.self, Course.self, NotePage.self, NoteBlock.self], inMemory: true)
}
