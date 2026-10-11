//
//  DistanceTransform.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 각 픽셀에서 가장 가까운 잉크 픽셀까지의 거리(픽셀 단위, 근사).
/// 가로·세로 1, 대각선 √2 가중치로 앞뒤 두 번 훑는 방식(chamfer 3-4 근사와 같은 계열).
enum DistanceTransform {
    static func compute(_ bitmap: GrayBitmap) -> [Float] {
        let width = bitmap.width, height = bitmap.height
        let far = Float(width + height)
        let threshold = GrayBitmap.inkThreshold
        var distance = bitmap.pixels.map { $0 < threshold ? 0 : far }
        let diagonal: Float = 1.41421356

        distance.withUnsafeMutableBufferPointer { d in
            // 왼쪽 위 → 오른쪽 아래
            for y in 0..<height {
                for x in 0..<width {
                    let i = y * width + x
                    var value = d[i]
                    if x > 0 { value = min(value, d[i - 1] + 1) }
                    if y > 0 {
                        value = min(value, d[i - width] + 1)
                        if x > 0 { value = min(value, d[i - width - 1] + diagonal) }
                        if x < width - 1 { value = min(value, d[i - width + 1] + diagonal) }
                    }
                    d[i] = value
                }
            }
            // 오른쪽 아래 → 왼쪽 위
            for y in stride(from: height - 1, through: 0, by: -1) {
                for x in stride(from: width - 1, through: 0, by: -1) {
                    let i = y * width + x
                    var value = d[i]
                    if x < width - 1 { value = min(value, d[i + 1] + 1) }
                    if y < height - 1 {
                        value = min(value, d[i + width] + 1)
                        if x < width - 1 { value = min(value, d[i + width + 1] + diagonal) }
                        if x > 0 { value = min(value, d[i + width - 1] + diagonal) }
                    }
                    d[i] = value
                }
            }
        }
        return distance
    }
}
