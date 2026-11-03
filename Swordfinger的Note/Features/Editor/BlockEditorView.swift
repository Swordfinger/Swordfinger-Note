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
    var showsPageHeader = false

    @State private var isShowingDrawingConfiguration = false
    @State private var selectedDrawingPreset: DrawingCanvasPreset = .sideNote
    @State private var selectedDrawingPaperStyle: DrawingPaperStyle = .blank
    @State private var createdDrawingBlockIDAwaitingFocus: UUID?
    @State private var pendingFocusedDrawingBlockID: UUID?

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
                List {
                    if showsPageHeader {
                        pageHeader
                            .listRowSeparator(.hidden)
                    }

                    ContentUnavailableView("No Blocks", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            } else {
                List {
                    if showsPageHeader {
                        pageHeader
                            .listRowSeparator(.hidden)
                    }

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

                    Button(action: presentDrawingConfiguration) {
                        Label("Drawing", systemImage: "pencil.tip")
                    }
                } label: {
                    Label("Add Block", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .sheet(isPresented: $isShowingDrawingConfiguration) {
            DrawingConfigurationSheet(
                selectedPreset: $selectedDrawingPreset,
                selectedPaperStyle: $selectedDrawingPaperStyle,
                onCancel: {
                    isShowingDrawingConfiguration = false
                },
                onCreate: {
                    let block = createDrawingBlock(
                        preset: selectedDrawingPreset,
                        paperStyle: selectedDrawingPaperStyle
                    )
                    createdDrawingBlockIDAwaitingFocus = block.id
                    isShowingDrawingConfiguration = false
                }
            )
            .onDisappear {
                guard let createdDrawingBlockIDAwaitingFocus else {
                    return
                }

                pendingFocusedDrawingBlockID = createdDrawingBlockIDAwaitingFocus
                self.createdDrawingBlockIDAwaitingFocus = nil
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.semibold)

            Divider()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func editorView(for block: NoteBlock) -> some View {
        switch block.blockType {
        case .paragraph:
            ParagraphBlockView(block: block, onTextChanged: updatePageModificationDate)
        case .heading:
            HeadingBlockView(block: block, onTextChanged: updatePageModificationDate)
        case .drawing:
            DrawingBlockView(
                block: block,
                onDrawingChanged: updatePageModificationDate,
                pendingFocusedBlockID: pendingFocusedDrawingBlockID,
                onPendingFocusConsumed: {
                    pendingFocusedDrawingBlockID = nil
                }
            )
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

    private func presentDrawingConfiguration() {
        selectedDrawingPreset = .sideNote
        selectedDrawingPaperStyle = .blank
        isShowingDrawingConfiguration = true
    }

    private func createDrawingBlock(preset: DrawingCanvasPreset, paperStyle: DrawingPaperStyle) -> NoteBlock {
        addBlock(
            type: .drawing,
            drawingCanvasPreset: preset,
            drawingPaperStyle: paperStyle
        )
    }

    private func addCodeBlock() {
        addBlock(type: .code)
    }

    @discardableResult
    private func addBlock(
        type: NoteBlockType,
        drawingCanvasPreset: DrawingCanvasPreset? = nil,
        drawingPaperStyle: DrawingPaperStyle? = nil
    ) -> NoteBlock {
        let block = NoteBlock(
            page: page,
            order: nextBlockOrder,
            blockType: type,
            drawingCanvasPreset: drawingCanvasPreset,
            drawingPaperStyle: drawingPaperStyle
        )

        page.blocks.append(block)
        updatePageModificationDate()
        return block
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

private struct DrawingConfigurationSheet: View {
    @Binding var selectedPreset: DrawingCanvasPreset
    @Binding var selectedPaperStyle: DrawingPaperStyle

    let onCancel: () -> Void
    let onCreate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Canvas") {
                    Picker("Canvas", selection: $selectedPreset) {
                        ForEach(DrawingCanvasPreset.newDrawingChoices, id: \.self) { preset in
                            Text(preset.displayName)
                                .tag(preset)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Paper") {
                    Picker("Paper", selection: $selectedPaperStyle) {
                        ForEach(DrawingPaperStyle.allCases, id: \.self) { paperStyle in
                            Text(paperStyle.displayName)
                                .tag(paperStyle)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("New Drawing")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: onCreate)
                }
            }
        }
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
