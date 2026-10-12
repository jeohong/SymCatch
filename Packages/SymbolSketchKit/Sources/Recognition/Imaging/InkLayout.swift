//
//  InkLayout.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/12/26.
//

import Accelerate

/// 이미지를 격자로 나눠 칸마다 잉크가 얼마나 있는지 잰 값(잉크 배치).
///
/// Vision 특징 벡터는 좌우가 반대인 모양을 거의 같게 본다(→를 그렸는데 ←가 더 높게 나옴, 2026-10-12).
/// 잉크 배치는 위치를 그대로 담으므로 좌우·상하가 반대면 값이 크게 달라진다. 검색 점수에 조금 더해 방향을 바로잡는다.
enum InkLayout {
    /// 한 변의 칸 수(8×8 = 64)
    static let grid = 8
    static var dimension: Int { grid * grid }

    /// 칸별 잉크 비율에서 평균을 빼고 길이 1로 맞춘 값. 두 값의 내적이 곧 코사인 유사도다.
    /// 잉크가 없거나 고르게 퍼져 있으면 모두 0.
    static func descriptor(_ bitmap: GrayBitmap, grid: Int = grid) -> [Float] {
        var cells = [Float](repeating: 0, count: grid * grid)
        guard bitmap.width > 0, bitmap.height > 0 else { return cells }
        let threshold = GrayBitmap.inkThreshold
        bitmap.pixels.withUnsafeBufferPointer { pixels in
            for y in 0..<bitmap.height {
                let row = min(grid - 1, y * grid / bitmap.height) * grid
                let base = y * bitmap.width
                for x in 0..<bitmap.width where pixels[base + x] < threshold {
                    cells[row + min(grid - 1, x * grid / bitmap.width)] += 1
                }
            }
        }
        let cellArea = Float(bitmap.width * bitmap.height) / Float(grid * grid)
        cells = vDSP.divide(cells, cellArea)
        let mean = vDSP.mean(cells)
        cells = vDSP.add(-mean, cells)
        let length = sqrt(vDSP.sumOfSquares(cells))
        return length > 1e-6 ? vDSP.divide(cells, length) : [Float](repeating: 0, count: grid * grid)
    }
}
