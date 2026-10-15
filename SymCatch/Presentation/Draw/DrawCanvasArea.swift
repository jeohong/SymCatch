//
//  DrawCanvasArea.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 정사각형 그리기 영역 + 빈 상태 안내 + 그림 부족 안내 + 지우개 표시(DESIGN_NOTES 3.1).
struct DrawCanvasArea: View {
    let controller: SketchCanvasController
    let isEmpty: Bool
    let isTooSmall: Bool
    let onChange: (Sketch) -> Void

    var body: some View {
        ZStack {
            DotGrid()
            if isEmpty {
                emptyHint
            }
            SketchCanvas(controller: controller, onChange: onChange)
        }
        .background(DSColor.canvasBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.canvas))
        .overlay(RoundedRectangle(cornerRadius: Radius.canvas).strokeBorder(DSColor.separator))
        .overlay(alignment: .topLeading) {
            if controller.tool == .eraser {
                Text("지우개")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSColor.bgPrimary)
                    .padding(.horizontal, Spacing.s + Spacing.xxs)
                    .padding(.vertical, Spacing.xs)
                    .background(DSColor.textPrimary, in: Capsule())
                    .padding(Spacing.m)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if isTooSmall {
                Label("조금 더 크게 그려 주세요", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSColor.bgPrimary)
                    .padding(.horizontal, Spacing.m + Spacing.xxs)
                    .padding(.vertical, Spacing.s)
                    .background(DSColor.textPrimary, in: Capsule())
                    .padding(.bottom, Spacing.m + Spacing.xxs)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isTooSmall)
    }

    /// 희미한 점선 하트 예시 + 안내 문구
    private var emptyHint: some View {
        VStack(spacing: Spacing.m + Spacing.xxs) {
            SketchShape(sketch: .exampleHeart, marginRatio: 0)
                .stroke(DSColor.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [6, 7]))
                .frame(width: 120, height: 120)
                .opacity(0.22)
            Text("찾고 싶은 아이콘을 그려 보세요")
                .font(.subheadline)
                .foregroundStyle(DSColor.textSecondary)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension Sketch {
    /// 빈 캔버스에 희미하게 보여 주는 하트 예시
    static let exampleHeart: Sketch = {
        let points = (0...40).map { step -> SketchPoint in
            let t = Double(step) / 40 * 2 * .pi
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            return SketchPoint(x: 0.5 + x / 34, y: 0.5 - y / 34)
        }
        return Sketch(strokes: [points])
    }()
}

private func drawCanvasAreaPreview() -> some View {
    VStack(spacing: Spacing.l) {
        DrawCanvasArea(controller: SketchCanvasController(), isEmpty: true, isTooSmall: false) { _ in }
            .frame(width: 300, height: 300)
        DrawCanvasArea(controller: SketchCanvasController(), isEmpty: false, isTooSmall: true) { _ in }
            .frame(width: 300, height: 300)
    }
    .padding(Spacing.screen)
    .background(DSColor.bgPrimary)
}

#Preview("라이트") { drawCanvasAreaPreview().preferredColorScheme(.light) }
#Preview("다크") { drawCanvasAreaPreview().preferredColorScheme(.dark) }
