//
//  Morphology.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

extension GrayBitmap {
    /// 채운 모양을 두께 `thickness` 픽셀의 테두리만 남긴 선 그림으로 바꾼다.
    /// 원래 `thickness × 2`보다 가는 선은 그대로 남는다(이미 선 그림이므로).
    /// 손그림(선)과 채운 심볼을 비교할 때 쓰는 변환(기획서 9.5).
    public func outlined(thickness: Int) -> GrayBitmap {
        guard thickness > 0 else { return self }
        let ink = pixels.map { $0 < Self.inkThreshold }
        let eroded = Self.erode(ink, width: width, height: height, radius: thickness)
        var result = GrayBitmap.blank(width: width, height: height)
        for index in pixels.indices where ink[index] && !eroded[index] {
            result.pixels[index] = 0
        }
        return result
    }

    /// 정사각형 구조 요소로 침식한다. 이미지 바깥은 바탕(잉크 아님)으로 본다.
    static func erode(_ ink: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        // 가로 → 세로 순서로 나눠 계산한다(분리 가능한 최소값 필터).
        var horizontal = [Bool](repeating: false, count: ink.count)
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                guard x - radius >= 0, x + radius < width else { continue }
                horizontal[row + x] = (x - radius...x + radius).allSatisfy { ink[row + $0] }
            }
        }
        var result = [Bool](repeating: false, count: ink.count)
        for y in 0..<height {
            guard y - radius >= 0, y + radius < height else { continue }
            for x in 0..<width {
                result[y * width + x] = (y - radius...y + radius).allSatisfy { horizontal[$0 * width + x] }
            }
        }
        return result
    }
}
