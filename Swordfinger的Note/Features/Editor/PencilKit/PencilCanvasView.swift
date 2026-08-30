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

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = ToolPickerCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .secondarySystemBackground
        canvasView.drawingPolicy = .anyInput
        canvasView.isUserInteractionEnabled = isEditable
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
        context.coordinator.configureToolPicker(for: canvasView)
        context.coordinator.apply(drawingData, to: canvasView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
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

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChanged?()
        }
    }
}
#else
struct PencilCanvasView: View {
    @Binding var drawingData: Data?
    let onDrawingChanged: () -> Void
    var isEditable = true
    var showsToolPicker = true

    var body: some View {
        ContentUnavailableView("Drawing is unavailable on this platform", systemImage: "pencil.tip")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary.opacity(0.2))
    }
}
#endif
