//
//  PKDrawing+Sketch.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import PencilKit
import Domain

extension PKDrawing {
    /// PencilKit 그림을 캔버스 크기 기준으로 정규화한 Domain `Sketch`로 바꾼다.
    /// - Parameter canvasSize: 캔버스 크기(포인트). 좌표를 0...1로 나누는 기준.
    func sketch(canvasSize: CGSize) -> Sketch {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return .empty }
        let strokes = strokes.map { stroke -> [SketchPoint] in
            stroke.path
                .interpolatedPoints(by: .distance(4))
                .map { point in
                    let location = point.location.applying(stroke.transform)
                    return SketchPoint(x: location.x / canvasSize.width, y: location.y / canvasSize.height)
                }
        }
        return Sketch(strokes: strokes.filter { !$0.isEmpty })
    }
}
