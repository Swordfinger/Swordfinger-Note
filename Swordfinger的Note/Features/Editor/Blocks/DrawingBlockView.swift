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

    @State private var isFocused = false

    var body: some View {
        Button {
            isFocused = true
        } label: {
            ZStack(alignment: .topTrailing) {
                PencilCanvasView(
                    drawingData: $block.drawingData,
                    onDrawingChanged: {},
                    isEditable: false,
                    showsToolPicker: false
                )
                .frame(height: 260)
                .allowsHitTesting(false)

                Label("Edit Drawing", systemImage: "arrow.up.left.and.arrow.down.right")
                    .labelStyle(.iconOnly)
                    .padding(8)
                    .background(.regularMaterial)
                    .clipShape(Circle())
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .sheet(isPresented: $isFocused) {
            FocusedDrawingView(block: block, onDrawingChanged: onDrawingChanged)
                .frame(minWidth: 720, minHeight: 520)
        }
        #else
        .fullScreenCover(isPresented: $isFocused) {
            FocusedDrawingView(block: block, onDrawingChanged: onDrawingChanged)
        }
        #endif
    }
}

private struct FocusedDrawingView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var block: NoteBlock
    let onDrawingChanged: () -> Void

    var body: some View {
        NavigationStack {
            PencilCanvasView(drawingData: $block.drawingData, onDrawingChanged: onDrawingChanged)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Drawing")
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
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
