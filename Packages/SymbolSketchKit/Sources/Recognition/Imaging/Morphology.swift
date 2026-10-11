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
    /// 가로·세로로 나눠, 각 위치에서 "연속된 잉크 길이"를 세는 방식이라 반지름과 무관하게 픽셀 수에 비례한다.
    static func erode(_ ink: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        let window = 2 * radius + 1
        guard width >= window, height >= window else { return Array(repeating: false, count: ink.count) }

        // 1) 가로: 각 픽셀의 [x-r, x+r]가 모두 잉크인지
        var horizontal = [Bool](repeating: false, count: ink.count)
        ink.withUnsafeBufferPointer { source in
            horizontal.withUnsafeMutableBufferPointer { target in
                for y in 0..<height {
                    let row = y * width
                    var run = 0   // x에서 끝나는 연속 잉크 길이
                    for x in 0..<width {
                        run = source[row + x] ? run + 1 : 0
                        // [x-2r, x] 전체가 잉크면 가운데(x-r)는 가로 조건을 만족한다.
                        if run >= window { target[row + x - radius] = true }
                    }
                }
            }
        }
        // 2) 세로: 가로 결과에서 [y-r, y+r]가 모두 참인지
        var result = [Bool](repeating: false, count: ink.count)
        horizontal.withUnsafeBufferPointer { source in
            result.withUnsafeMutableBufferPointer { target in
                var runs = [Int](repeating: 0, count: width)
                for y in 0..<height {
                    let row = y * width
                    for x in 0..<width {
                        runs[x] = source[row + x] ? runs[x] + 1 : 0
                        if runs[x] >= window { target[(y - radius) * width + x] = true }
                    }
                }
            }
        }
        return result
    }
}
