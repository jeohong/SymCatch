//
//  SketchCanvas.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import PencilKit
import Domain

/// 캔버스 도구 명령(되돌리기·지우개 등)을 보내는 뷰 계층 객체.
/// PencilKit은 이 객체와 `SketchCanvas` 안에만 둔다. ViewModel은 `Sketch`만 받는다.
@MainActor @Observable
final class SketchCanvasController {
    enum Tool { case pen, eraser }

    private(set) var canUndo = false
    private(set) var canRedo = false
    private(set) var tool: Tool = .pen
    private(set) var isEmpty = true

    fileprivate weak var canvasView: PKCanvasView?

    func undo() { canvasView?.undoManager?.undo(); refresh() }
    func redo() { canvasView?.undoManager?.redo(); refresh() }

    func clear() {
        canvasView?.drawing = PKDrawing()
        refresh()
    }

    func select(_ tool: Tool) {
        self.tool = tool
        canvasView?.tool = Self.makeTool(tool, canvasWidth: canvasView?.bounds.width ?? 0)
    }

    func toggleTool() {
        select(tool == .pen ? .eraser : .pen)
    }

    fileprivate func refresh() {
        canUndo = canvasView?.undoManager?.canUndo ?? false
        canRedo = canvasView?.undoManager?.canRedo ?? false
        isEmpty = canvasView?.drawing.strokes.isEmpty ?? true
    }

    /// 선 굵기는 한 가지로 고정한다(인식 품질을 일정하게). 필압·기울기에 영향받지 않는 monoline 잉크.
    fileprivate static func makeTool(_ tool: Tool, canvasWidth: CGFloat) -> PKTool {
        switch tool {
        case .pen:
            PKInkingTool(.monoline, color: .label, width: max(3.5, canvasWidth * 0.017))
        case .eraser:
            PKEraserTool(.vector)
        }
    }
}

/// 정사각형 그리기 영역. 획을 뗄 때마다 정규화된 `Sketch`를 `onChange`로 알린다.
struct SketchCanvas: UIViewRepresentable {
    let controller: SketchCanvasController
    let onChange: (Sketch) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = LayoutAwareCanvasView()
        // 캔버스 크기가 정해지거나 바뀌면 선 굵기를 다시 맞춘다(창 크기 변경, 회전, 접기).
        canvasView.onWidthChange = { [weak canvasView, controller] width in
            canvasView?.tool = SketchCanvasController.makeTool(controller.tool, canvasWidth: width)
        }
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled = false
        canvasView.delegate = context.coordinator
        // 시스템 설정 "Apple Pencil로만 그리기"를 따른다(기획서 8A.2).
        // PencilKit의 .default는 도구 선택창(PKToolPicker)이 없으면 손가락 입력을 받지 않으므로 설정값을 직접 읽는다.
        canvasView.drawingPolicy = UIPencilInteraction.prefersPencilOnlyDrawing ? .pencilOnly : .anyInput
        canvasView.accessibilityLabel = String(localized: "그리기 영역")
        canvasView.accessibilityIdentifier = "sketchCanvas"
        controller.canvasView = canvasView
        context.coordinator.pencilInteraction.delegate = context.coordinator
        canvasView.addInteraction(context.coordinator.pencilInteraction)
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        controller.canvasView = canvasView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: SketchCanvas
        let pencilInteraction = UIPencilInteraction()

        init(parent: SketchCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.controller.refresh()
            parent.onChange(canvasView.drawing.sketch(canvasSize: canvasView.bounds.size))
        }

        // Apple Pencil 더블탭(또는 스퀴즈)으로 펜과 지우개를 바꾼다.
        @available(iOS 17.5, *)
        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
            parent.controller.toggleTool()
        }

        // iOS 17.0~17.4용
        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            parent.controller.toggleTool()
        }
    }
}

/// 폭이 바뀔 때 알려 주는 캔버스.
private final class LayoutAwareCanvasView: PKCanvasView {
    var onWidthChange: ((CGFloat) -> Void)?
    private var lastWidth: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width != lastWidth else { return }
        lastWidth = bounds.width
        onWidthChange?(bounds.width)
    }
}
