//
//  SketchRasterizer.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import CoreGraphics
import Domain

/// `Sketch`(획 좌표)를 모델 입력용 흑백 이미지로 그린다.
/// 기기·캔버스 크기·테마와 무관하게 항상 같은 크기, 같은 선 굵기, 흰 바탕 검은 선이다.
public struct SketchRasterizer: Sendable {
    public let options: PreprocessingOptions

    public init(options: PreprocessingOptions = PreprocessingOptions()) {
        self.options = options
    }

    /// 빈 그림이면 nil.
    public func bitmap(for sketch: Sketch) -> GrayBitmap? {
        guard let bounds = sketch.bounds,
              let context = GrayBitmap.makeContext(width: options.size, height: options.size) else { return nil }

        let lineWidth = options.lineWidth
        // 선 굵기만큼 안쪽으로 줄여, 굵어진 선도 여백 안에 들어오게 한다.
        let (scale, origin) = options.fit(
            contentWidth: CGFloat(bounds.width),
            contentHeight: CGFloat(bounds.height),
            inset: lineWidth
        )

        // 위가 0인 좌표로 그리기 위해 뒤집는다.
        context.translateBy(x: 0, y: CGFloat(options.size))
        context.scaleBy(x: 1, y: -1)
        context.setStrokeColor(gray: 0, alpha: 1)
        context.setFillColor(gray: 0, alpha: 1)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        func map(_ point: SketchPoint) -> CGPoint {
            CGPoint(
                x: origin.x + CGFloat(point.x - bounds.minX) * scale,
                y: origin.y + CGFloat(point.y - bounds.minY) * scale
            )
        }

        for stroke in sketch.strokes where !stroke.isEmpty {
            if stroke.count == 1 {
                // 점 하나는 선 굵기만 한 원으로 찍는다.
                let center = map(stroke[0])
                context.fillEllipse(in: CGRect(
                    x: center.x - lineWidth / 2, y: center.y - lineWidth / 2,
                    width: lineWidth, height: lineWidth
                ))
                continue
            }
            context.beginPath()
            context.move(to: map(stroke[0]))
            for point in stroke.dropFirst() {
                context.addLine(to: map(point))
            }
            context.strokePath()
        }
        return GrayBitmap(context: context)
    }

    public func image(for sketch: Sketch) -> CGImage? {
        bitmap(for: sketch)?.makeCGImage()
    }
}
