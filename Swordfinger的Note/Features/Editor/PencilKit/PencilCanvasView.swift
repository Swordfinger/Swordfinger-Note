//
//  PencilCanvasView.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import SwiftUI

#if canImport(UIKit) && canImport(PencilKit)
import PencilKit
import UIKit

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?
    let onDrawingChanged: () -> Void
    var isEditable = true
    var showsToolPicker = true
    var logicalPageSize: CGSize?
    var paperStyle: DrawingPaperStyle = .blank

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = ToolPickerCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = effectiveDrawingPolicy
        canvasView.isUserInteractionEnabled = isEditable
        applyLogicalPageSize(to: canvasView)
        applyPaperBackground(to: canvasView)
        canvasView.onWindowChanged = { [weak coordinator = context.coordinator, weak canvasView] in
            guard let canvasView else {
                return
            }

            coordinator?.configureToolPicker(for: canvasView)
        }
        context.coordinator.apply(drawingData, to: canvasView)
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvasView.isUserInteractionEnabled = isEditable
        canvasView.drawingPolicy = effectiveDrawingPolicy
        applyLogicalPageSize(to: canvasView)
        applyPaperBackground(to: canvasView)
        context.coordinator.configureToolPicker(for: canvasView)
        context.coordinator.apply(drawingData, to: canvasView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func applyLogicalPageSize(to canvasView: PKCanvasView) {
        guard let logicalPageSize else {
            return
        }

        canvasView.contentSize = logicalPageSize
    }

    private func applyPaperBackground(to canvasView: PKCanvasView) {
        guard let canvasView = canvasView as? ToolPickerCanvasView else {
            return
        }

        let pageSize = logicalPageSize ?? canvasView.bounds.size
        canvasView.configurePaperBackground(
            style: paperStyle,
            logicalPageSize: pageSize
        )
    }

    private var effectiveDrawingPolicy: PKCanvasViewDrawingPolicy {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? .pencilOnly : .anyInput
        #else
        .anyInput
        #endif
    }

    static func dismantleUIView(_ canvasView: PKCanvasView, coordinator: Coordinator) {
        coordinator.detachToolPicker()
        canvasView.delegate = nil
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasView
        private let toolPicker = PKToolPicker()
        private var isApplyingDrawing = false
        private var lastAppliedData: Data?
        private weak var configuredCanvasView: PKCanvasView?

        init(parent: PencilCanvasView) {
            self.parent = parent
        }

        deinit {
            detachToolPicker()
        }

        func configureToolPicker(for canvasView: PKCanvasView) {
            guard parent.isEditable, parent.showsToolPicker else {
                detachToolPicker()
                return
            }

            guard canvasView.window != nil else {
                return
            }

            if configuredCanvasView !== canvasView {
                if let configuredCanvasView {
                    toolPicker.setVisible(false, forFirstResponder: configuredCanvasView)
                    toolPicker.removeObserver(configuredCanvasView)
                }

                toolPicker.addObserver(canvasView)
                configuredCanvasView = canvasView
            }

            toolPicker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }

        func detachToolPicker() {
            guard let configuredCanvasView else {
                return
            }

            toolPicker.setVisible(false, forFirstResponder: configuredCanvasView)
            toolPicker.removeObserver(configuredCanvasView)
            configuredCanvasView.resignFirstResponder()
            self.configuredCanvasView = nil
        }

        func apply(_ drawingData: Data?, to canvasView: PKCanvasView) {
            guard drawingData != lastAppliedData else {
                return
            }

            isApplyingDrawing = true
            defer { isApplyingDrawing = false }

            if let drawingData {
                do {
                    let drawing = try PKDrawing(data: drawingData)
                    if canvasView.drawing.dataRepresentation() != drawingData {
                        canvasView.drawing = drawing
                    }
                    lastAppliedData = drawingData
                } catch {
                    lastAppliedData = nil
                }
            } else if !canvasView.drawing.strokes.isEmpty {
                canvasView.drawing = PKDrawing()
                lastAppliedData = nil
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingDrawing else {
                return
            }

            let newData = canvasView.drawing.dataRepresentation()
            guard newData != lastAppliedData else {
                return
            }

            lastAppliedData = newData
            parent.drawingData = newData
            parent.onDrawingChanged()
        }
    }

    final class ToolPickerCanvasView: PKCanvasView {
        var onWindowChanged: (() -> Void)?
        private let paperBackgroundView = PaperBackgroundUIView()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChanged?()
        }

        func configurePaperBackground(style: DrawingPaperStyle, logicalPageSize: CGSize) {
            if paperBackgroundView.superview !== self {
                insertSubview(paperBackgroundView, at: 0)
            }

            paperBackgroundView.style = style
            paperBackgroundView.frame = CGRect(origin: .zero, size: logicalPageSize)
            paperBackgroundView.setNeedsDisplay()
        }
    }

    final class PaperBackgroundUIView: UIView {
        var style: DrawingPaperStyle = .blank {
            didSet {
                setNeedsDisplay()
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else {
                return
            }

            UIColor.secondarySystemBackground.setFill()
            context.fill(bounds)

            let spacing = style.logicalSpacing
            guard spacing > 0 else {
                return
            }

            let guideColor = UIColor.label.withAlphaComponent(0.10)
            context.setStrokeColor(guideColor.cgColor)
            context.setLineWidth(1)

            switch style {
            case .blank:
                break
            case .lined:
                drawHorizontalLines(in: context, spacing: spacing)
            case .grid:
                drawHorizontalLines(in: context, spacing: spacing)
                drawVerticalLines(in: context, spacing: spacing)
            case .dotted:
                drawDots(in: context, spacing: spacing)
            }
        }

        private func drawHorizontalLines(in context: CGContext, spacing: CGFloat) {
            var y = spacing
            while y < bounds.height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: bounds.width, y: y))
                y += spacing
            }
            context.strokePath()
        }

        private func drawVerticalLines(in context: CGContext, spacing: CGFloat) {
            var x = spacing
            while x < bounds.width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: bounds.height))
                x += spacing
            }
            context.strokePath()
        }

        private func drawDots(in context: CGContext, spacing: CGFloat) {
            let radius: CGFloat = 2
            context.setFillColor(UIColor.label.withAlphaComponent(0.10).cgColor)

            var y = spacing
            while y < bounds.height {
                var x = spacing
                while x < bounds.width {
                    context.fillEllipse(in: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}
#else
struct PencilCanvasView: View {
    @Binding var drawingData: Data?
    let onDrawingChanged: () -> Void
    var isEditable = true
    var showsToolPicker = true
    var logicalPageSize: CGSize?
    var paperStyle: DrawingPaperStyle = .blank

    var body: some View {
        ContentUnavailableView("Drawing is unavailable on this platform", systemImage: "pencil.tip")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary.opacity(0.2))
    }
}
#endif
