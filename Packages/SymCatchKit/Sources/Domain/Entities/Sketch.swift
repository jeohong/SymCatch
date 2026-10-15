//
//  Sketch.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 캔버스 기준으로 정규화된 점. 캔버스 왼쪽 위가 (0, 0), 오른쪽 아래가 (1, 1)이다.
public struct SketchPoint: Sendable, Hashable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// 사용자가 그린 그림. 기기·캔버스 크기·테마와 무관한 획 좌표만 담는다.
/// 래스터화(이미지 변환)는 Recognition 레이어가 맡는다.
public struct Sketch: Sendable, Hashable, Codable {
    public var strokes: [[SketchPoint]]

    public init(strokes: [[SketchPoint]]) {
        self.strokes = strokes
    }

    public static let empty = Sketch(strokes: [])

    /// 점이 하나 이상 있는 획의 수.
    public var strokeCount: Int {
        strokes.filter { !$0.isEmpty }.count
    }

    public var isEmpty: Bool {
        strokeCount == 0
    }

    /// 모든 점을 감싸는 사각형. 점이 없으면 nil.
    public var bounds: SketchBounds? {
        var minX = Double.infinity, minY = Double.infinity
        var maxX = -Double.infinity, maxY = -Double.infinity
        for point in strokes.joined() {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        guard minX.isFinite else { return nil }
        return SketchBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }

    /// 모든 획 길이의 합(정규화 좌표 기준).
    public var totalLength: Double {
        strokes.reduce(0) { total, stroke in
            zip(stroke, stroke.dropFirst()).reduce(total) { sum, pair in
                sum + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
            }
        }
    }
}

public struct SketchBounds: Sendable, Hashable {
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var longestSide: Double { max(width, height) }
}
