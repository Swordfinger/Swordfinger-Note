//
//  HeadingBlockView.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import SwiftUI
import SwiftData

struct HeadingBlockView: View {
    @Bindable var block: NoteBlock
    let onTextChanged: () -> Void

    var body: some View {
        TextField("Heading", text: $block.textContent)
            .font(.title2.weight(.semibold))
            .textFieldStyle(.plain)
            .padding(.vertical, 6)
            .onChange(of: block.textContent) { _, _ in
                onTextChanged()
            }
    }
}

#Preview {
    HeadingBlockView(
        block: NoteBlock(order: 0, blockType: .heading, textContent: "Heading block"),
        onTextChanged: {}
    )
    .padding()
    .modelContainer(for: [Item.self, Course.self, NotePage.self, NoteBlock.self], inMemory: true)
}
