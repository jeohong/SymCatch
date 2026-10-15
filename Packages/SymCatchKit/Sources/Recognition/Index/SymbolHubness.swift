//
//  SymbolHubness.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/12/26.
//

import Accelerate
import Domain

/// 심볼마다 "다른 심볼들과 평소에 얼마나 닮는지"를 잰다(`HubnessCorrection`의 r(심볼)).
/// 같은 family(채움·테두리 변형)는 자기 자신과 다름없으므로 이웃에서 뺀다.
enum SymbolHubness {
    /// - Parameters:
    ///   - vectors: `families.count × dimension` 행렬(행 우선, 정규화 전이어도 된다)
    ///   - families: 행마다 family 키
    ///   - neighborCount: 이웃 수 k
    /// - Returns: 행마다 가장 닮은 다른 family 심볼 k개의 평균 코사인
    static func compute(vectors: [Float], dimension: Int, families: [String], neighborCount k: Int = HubnessCorrection.neighborCount) -> [Float] {
        let count = families.count
        guard count > 1, dimension > 0, vectors.count == count * dimension else { return [Float](repeating: 0, count: count) }

        // 행 정규화 후 (dimension × count) 전치 행렬을 만들어 두고, 행 묶음 단위로 곱한다.
        var unit = vectors
        for row in 0..<count {
            unit.withUnsafeMutableBufferPointer { buffer in
                let start = buffer.baseAddress! + row * dimension
                var length: Float = 0
                vDSP_svesq(start, 1, &length, vDSP_Length(dimension))
                length = sqrt(length)
                if length > 0 { vDSP_vsdiv(start, 1, &length, start, 1, vDSP_Length(dimension)) }
            }
        }
        var transposed = [Float](repeating: 0, count: count * dimension)
        vDSP_mtrans(unit, 1, &transposed, 1, vDSP_Length(dimension), vDSP_Length(count))

        let familyIDs = Self.familyIDs(families)
        let blockSize = 256
        var result = [Float](repeating: 0, count: count)
        var block = [Float](repeating: 0, count: blockSize * count)
        let neighbors = min(k, count - 1)

        for blockStart in stride(from: 0, to: count, by: blockSize) {
            let rows = min(blockSize, count - blockStart)
            unit.withUnsafeBufferPointer { unitBuffer in
                vDSP_mmul(unitBuffer.baseAddress! + blockStart * dimension, 1, transposed, 1, &block, 1,
                          vDSP_Length(rows), vDSP_Length(count), vDSP_Length(dimension))
            }
            block.withUnsafeBufferPointer { scores in
                familyIDs.withUnsafeBufferPointer { ids in
                    var top = [Float](repeating: -.infinity, count: max(neighbors, 1))
                    for local in 0..<rows {
                        let row = blockStart + local
                        let own = ids[row]
                        for index in top.indices { top[index] = -.infinity }
                        var minimum = -Float.infinity, minimumIndex = 0
                        let base = local * count
                        for column in 0..<count where ids[column] != own {
                            let score = scores[base + column]
                            guard score > minimum else { continue }
                            top[minimumIndex] = score
                            // 가장 작은 값을 다시 찾는다(k가 작아 선형 탐색이 빠르다).
                            minimum = top[0]; minimumIndex = 0
                            for index in 1..<top.count where top[index] < minimum {
                                minimum = top[index]; minimumIndex = index
                            }
                        }
                        let valid = top.filter { $0.isFinite }
                        result[row] = valid.isEmpty ? 0 : valid.reduce(0, +) / Float(valid.count)
                    }
                }
            }
        }
        return result
    }

    private static func familyIDs(_ families: [String]) -> [Int] {
        var ids: [String: Int] = [:]
        return families.map { family in
            if let id = ids[family] { return id }
            ids[family] = ids.count
            return ids.count - 1
        }
    }
}
