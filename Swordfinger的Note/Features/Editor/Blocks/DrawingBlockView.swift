//
//  DrawingBlockView.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import SwiftUI
import SwiftData

#if canImport(UIKit) && canImport(PencilKit)
import PencilKit
import UIKit
#endif

struct DrawingBlockView: View {
    @Bindable var block: NoteBlock
    let onDrawingChanged: () -> Void
    var pendingFocusedBlockID: UUID?
    var onPendingFocusConsumed: () -> Void = {}

    @State private var isFocused = false

    var body: some View {
        Button {
            isFocused = true
        } label: {
            ZStack(alignment: .topTrailing) {
                DrawingPreviewView(
                    drawingData: block.drawingData,
                    preset: block.drawingCanvasPreset,
                    paperStyle: block.drawingPaperStyle
                )
                    .aspectRatio(block.drawingCanvasPreset.aspectRatio, contentMode: .fit)
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
        .onAppear(perform: focusIfRequested)
        .onChange(of: pendingFocusedBlockID) {
            focusIfRequested()
        }
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

    private func focusIfRequested() {
        guard pendingFocusedBlockID == block.id else {
            return
        }

        isFocused = true
        onPendingFocusConsumed()
    }
}

#if canImport(UIKit) && canImport(PencilKit)
private struct DrawingPreviewView: View {
    @Environment(\.displayScale) private var displayScale

    let drawingData: Data?
    let preset: DrawingCanvasPreset
    let paperStyle: DrawingPaperStyle

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DrawingPaperBackgroundView(
                    paperStyle: paperStyle,
                    logicalSize: preset.logicalSize
                )

                if let image = renderedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
    }

    private var renderedImage: UIImage? {
        guard let drawingData, let drawing = try? PKDrawing(data: drawingData) else {
            return nil
        }

        let sourceRect = preset.logicalPageRect
        return drawing.image(from: sourceRect, scale: max(displayScale, 1))
    }
}
#else
private struct DrawingPreviewView: View {
    let drawingData: Data?
    let preset: DrawingCanvasPreset
    let paperStyle: DrawingPaperStyle

    var body: some View {
        ContentUnavailableView("Drawing preview is unavailable on this platform", systemImage: "pencil.tip")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary.opacity(0.2))
    }
}
#endif

private struct FocusedDrawingView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var block: NoteBlock
    let onDrawingChanged: () -> Void

    var body: some View {
        NavigationStack {
            PencilCanvasView(
                drawingData: $block.drawingData,
                onDrawingChanged: onDrawingChanged,
                logicalPageSize: block.drawingCanvasPreset.logicalSize,
                paperStyle: block.drawingPaperStyle
            )
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Drawing")
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(DrawingPaperStyle.allCases, id: \.self) { paperStyle in
                                Button {
                                    block.drawingPaperStyle = paperStyle
                                    onDrawingChanged()
                                } label: {
                                    Text(paperStyle.displayName)
                                }
                            }
                        } label: {
                            Label(block.drawingPaperStyle.displayName, systemImage: "doc.plaintext")
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct DrawingPaperBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    let paperStyle: DrawingPaperStyle
    let logicalSize: CGSize

    private var guideColor: Color {
        colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.10)
    }

    private var pageColor: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(pageColor))

            let scale = min(size.width / logicalSize.width, size.height / logicalSize.height)
            guard scale.isFinite, scale > 0 else {
                return
            }

            let spacing = paperStyle.logicalSpacing * scale
            let lineWidth = max(1 / max(scale, 1), 0.75)

            switch paperStyle {
            case .blank:
                break
            case .lined:
                drawHorizontalLines(in: &context, size: size, spacing: spacing, lineWidth: lineWidth)
            case .grid:
                drawHorizontalLines(in: &context, size: size, spacing: spacing, lineWidth: lineWidth)
                drawVerticalLines(in: &context, size: size, spacing: spacing, lineWidth: lineWidth)
            case .dotted:
                drawDots(in: &context, size: size, spacing: spacing, radius: max(1.1, 1.8 * scale))
            }
        }
    }

    private func drawHorizontalLines(in context: inout GraphicsContext, size: CGSize, spacing: CGFloat, lineWidth: CGFloat) {
        guard spacing > 0 else {
            return
        }

        var y = spacing
        while y < size.height {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(guideColor), lineWidth: lineWidth)
            y += spacing
        }
    }

    private func drawVerticalLines(in context: inout GraphicsContext, size: CGSize, spacing: CGFloat, lineWidth: CGFloat) {
        guard spacing > 0 else {
            return
        }

        var x = spacing
        while x < size.width {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(guideColor), lineWidth: lineWidth)
            x += spacing
        }
    }

    private func drawDots(in context: inout GraphicsContext, size: CGSize, spacing: CGFloat, radius: CGFloat) {
        guard spacing > 0 else {
            return
        }

        var y = spacing
        while y < size.height {
            var x = spacing
            while x < size.width {
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(guideColor))
                x += spacing
            }
            y += spacing
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
