//
//  SketchShape.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 저장된 `Sketch`(정규화 획 좌표)를 다시 그리는 도형. 썸네일·"내 그림과 비교"에 쓴다.
/// 그림을 잘라 가운데에 놓고 여백을 둔다(인식 전처리와 같은 방식이라 심볼과 나란히 볼 때 크기가 맞는다).
nonisolated struct SketchShape: Shape {
    let sketch: Sketch
    var marginRatio: CGFloat = 0.1

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let bounds = sketch.bounds else { return path }
        let available = min(rect.width, rect.height) * (1 - 2 * marginRatio)
        let scale = available / max(CGFloat(bounds.longestSide), .ulpOfOne)
        let originX = rect.midX - CGFloat(bounds.width) * scale / 2
        let originY = rect.midY - CGFloat(bounds.height) * scale / 2

        func point(_ p: SketchPoint) -> CGPoint {
            CGPoint(x: originX + CGFloat(p.x - bounds.minX) * scale, y: originY + CGFloat(p.y - bounds.minY) * scale)
        }
        for stroke in sketch.strokes where !stroke.isEmpty {
            path.move(to: point(stroke[0]))
            if stroke.count == 1 {
                path.addLine(to: point(stroke[0]))
            }
            for p in stroke.dropFirst() {
                path.addLine(to: point(p))
            }
        }
        return path
    }
}

/// 캔버스 바탕의 점 격자(DESIGN_NOTES 2.7)
struct DotGrid: View {
    var spacing: CGFloat = Metrics.dotSpacing

    var body: some View {
        Canvas { context, size in
            let diameter = Metrics.dotDiameter
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)),
                                 with: .color(DSColor.canvasDot))
                    x += spacing
                }
                y += spacing
            }
        }
        .accessibilityHidden(true)
    }
}

private let previewSketch = Sketch(strokes: [
    (0...24).map { step in
        let t = Double(step) / 24 * 2 * .pi
        return SketchPoint(x: 0.5 + 0.3 * pow(sin(t), 3), y: 0.45 - 0.25 * (13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) / 16)
    },
])

#Preview("라이트") {
    ZStack {
        DotGrid()
        SketchShape(sketch: previewSketch)
            .stroke(DSColor.canvasInk, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
    }
    .frame(width: 200, height: 200)
    .background(DSColor.canvasBackground, in: RoundedRectangle(cornerRadius: Radius.canvas))
    .padding()
    .preferredColorScheme(.light)
}

#Preview("다크") {
    ZStack {
        DotGrid()
        SketchShape(sketch: previewSketch)
            .stroke(DSColor.canvasInk, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
    }
    .frame(width: 200, height: 200)
    .background(DSColor.canvasBackground, in: RoundedRectangle(cornerRadius: Radius.canvas))
    .padding()
    .preferredColorScheme(.dark)
}
