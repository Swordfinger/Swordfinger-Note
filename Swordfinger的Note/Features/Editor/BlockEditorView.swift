//
//  BlockEditorView.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import SwiftUI
import SwiftData

struct BlockEditorView: View {
    @Environment(\.modelContext) private var modelContext

    let page: NotePage

    private var sortedBlocks: [NoteBlock] {
        page.blocks.sorted { firstBlock, secondBlock in
            if firstBlock.order == secondBlock.order {
                return firstBlock.id.uuidString < secondBlock.id.uuidString
            }

            return firstBlock.order < secondBlock.order
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sortedBlocks.isEmpty {
                ContentUnavailableView("No Blocks", systemImage: "text.alignleft")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedBlocks) { block in
                        editorView(for: block)
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteBlock(block)
                                } label: {
                                    Label("Delete Block", systemImage: "trash")
                                }
                            }
                    }
                    .onMove(perform: moveBlocks)
                }
                .listStyle(.plain)
            }

            HStack {
                #if os(iOS)
                EditButton()
                #endif

                Menu {
                    Button(action: addTextBlock) {
                        Label("Text", systemImage: "text.alignleft")
                    }

                    Button(action: addHeadingBlock) {
                        Label("Heading", systemImage: "textformat.size")
                    }

                    Button(action: addCodeBlock) {
                        Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }

                    Button(action: addDrawingBlock) {
                        Label("Drawing", systemImage: "pencil.tip")
                    }
                } label: {
                    Label("Add Block", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func editorView(for block: NoteBlock) -> some View {
        switch block.blockType {
        case .paragraph:
            ParagraphBlockView(block: block, onTextChanged: updatePageModificationDate)
        case .heading:
            HeadingBlockView(block: block, onTextChanged: updatePageModificationDate)
        case .drawing:
            DrawingBlockView(block: block, onDrawingChanged: updatePageModificationDate)
        case .code:
            CodeBlockView(block: block, onCodeChanged: updatePageModificationDate)
        }
    }

    private func addHeadingBlock() {
        addBlock(type: .heading)
    }

    private func addTextBlock() {
        addBlock(type: .paragraph)
    }

    private func addDrawingBlock() {
        addBlock(type: .drawing)
    }

    private func addCodeBlock() {
        addBlock(type: .code)
    }

    private func addBlock(type: NoteBlockType) {
        let block = NoteBlock(
            page: page,
            order: nextBlockOrder,
            blockType: type
        )

        page.blocks.append(block)
        updatePageModificationDate()
    }

    private func deleteBlock(_ block: NoteBlock) {
        withAnimation {
            page.removeBlock(block)
            modelContext.delete(block)
        }
    }

    private func moveBlocks(from sourceIndexes: IndexSet, to destinationIndex: Int) {
        withAnimation {
            page.moveBlocks(from: sourceIndexes, to: destinationIndex)
        }
    }

    private var nextBlockOrder: Int {
        (page.blocks.map(\.order).max() ?? -1) + 1
    }

    private func updatePageModificationDate() {
        page.modifiedAt = Date()
    }
}

#Preview {
    let page = NotePage(title: "Lecture 1", order: 0)
    page.blocks = [
        NoteBlock(page: page, order: 0, blockType: .heading, textContent: "Heading block"),
        NoteBlock(page: page, order: 1, blockType: .paragraph, textContent: "Paragraph block"),
        NoteBlock(page: page, order: 2, blockType: .code, textContent: "let value = 42", codeLanguage: .swift),
        NoteBlock(page: page, order: 3, blockType: .drawing)
    ]

    return BlockEditorView(page: page)
        .modelContainer(for: [Item.self, Course.self, NotePage.self, NoteBlock.self], inMemory: true)
}
