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
    /// 마지막 그림과 그때의 캔버스 폭. 배치가 바뀌어 캔버스가 새로 생기거나(Duo 접기·펴기)
    /// 크기가 바뀌면 이 그림을 새 폭에 맞춰 다시 그린다(그리던 그림 유지, CLAUDE.md 2.3).
    fileprivate private(set) var drawing = PKDrawing()
    fileprivate private(set) var drawingWidth: CGFloat = 0
    /// 크기에 맞춰 다시 그리는 중(사용자 획이 아니므로 검색을 다시 부르지 않는다)
    fileprivate private(set) var isRestoring = false

    func undo() { canvasView?.undoManager?.undo(); refresh() }
    func redo() { canvasView?.undoManager?.redo(); refresh() }

    func clear() {
        drawing = PKDrawing()
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
        isEmpty = canvasView?.drawing.strokes.isEmpty ?? drawing.strokes.isEmpty
    }

    fileprivate func drawingDidChange(in canvasView: PKCanvasView) {
        drawing = canvasView.drawing
        drawingWidth = canvasView.bounds.width
    }

    /// 캔버스 폭이 정해지거나 바뀌었을 때: 선 굵기를 맞추고, 기억한 그림을 새 폭에 맞춰 늘리거나 줄인다.
    fileprivate func canvasDidResize(_ canvasView: PKCanvasView, width: CGFloat) {
        canvasView.tool = Self.makeTool(tool, canvasWidth: width)
        guard width > 0 else { return }
        defer { drawingWidth = width }
        guard drawingWidth > 0, width != drawingWidth, !drawing.strokes.isEmpty else { return }
        let scale = width / drawingWidth
        drawing = drawing.transformed(using: CGAffineTransform(scaleX: scale, y: scale))
        // PencilKit은 크기가 바뀌는 중에 그림을 바꾸면 이전 크기의 그림을 계속 보여 준다(데이터는 바뀌어도).
        // 레이아웃이 끝난 뒤, 빈 그림을 한 번 넣었다가 바꿔 화면을 새로 그리게 한다.
        let resized = drawing
        DispatchQueue.main.async { [weak self, weak canvasView] in
            guard let self, let canvasView, canvasView.bounds.width == width else { return }
            isRestoring = true
            canvasView.drawing = PKDrawing()
            canvasView.drawing = resized
            isRestoring = false
            // 되돌리기 기록은 이전 크기의 좌표라 크기를 바꾼 뒤에는 맞지 않는다. 비운다.
            canvasView.undoManager?.removeAllActions()
            refresh()
        }
    }

    /// 선 굵기는 한 가지로 고정한다(인식 품질을 일정하게). 필압·기울기에 영향받지 않는 monoline 잉크.
    fileprivate static func makeTool(_ tool: Tool, canvasWidth: CGFloat) -> PKTool {
        switch tool {
        case .pen:
            PKInkingTool(.monoline, color: .canvasInkForPencilKit, width: max(3.5, canvasWidth * 0.017))
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
        // 배치가 바뀌어 새로 만든 캔버스면 그리던 그림을 이어받는다(크기는 폭이 정해질 때 맞춘다).
        canvasView.drawing = controller.drawing
        // 캔버스 크기가 정해지거나 바뀌면 선 굵기와 그림 크기를 다시 맞춘다(창 크기 변경, 회전, 접기).
        canvasView.onWidthChange = { [weak canvasView, controller] width in
            guard let canvasView else { return }
            controller.canvasDidResize(canvasView, width: width)
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
            guard !parent.controller.isRestoring else { return }
            parent.controller.drawingDidChange(in: canvasView)
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
