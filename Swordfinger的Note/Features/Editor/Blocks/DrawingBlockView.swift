//
//  DrawingBlockView.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import SwiftUI
import SwiftData

struct DrawingBlockView: View {
    @Bindable var block: NoteBlock
    let onDrawingChanged: () -> Void

    var body: some View {
        PencilCanvasView(drawingData: $block.drawingData, onDrawingChanged: onDrawingChanged)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
    }
}

#Preview {
    DrawingBlockView(
        block: NoteBlock(order: 0, blockType: .drawing),
        onDrawingChanged: {}
    )
    .padding()
    .modelContainer(for: [Item.self, Course.self, NotePage.self, NoteBlock.self], inMemory: true)
}
