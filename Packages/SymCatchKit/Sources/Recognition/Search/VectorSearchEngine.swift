//
//  VectorSearchEngine.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Accelerate

/// 쿼리 벡터와 모든 심볼 벡터의 코사인 유사도를 한 번의 행렬 곱으로 계산한다.
/// 만들 때 모든 행을 정규화해 두므로, 검색은 정규화된 쿼리와의 내적만 하면 된다.
public struct VectorSearchEngine: Sendable {
    public let count: Int
    public let dimension: Int
    private let matrix: [Float]

    /// - Parameter vectors: `count × dimension` 행렬(행 우선). 각 행은 여기서 정규화된다.
    public init(vectors: [Float], dimension: Int) {
        precondition(dimension > 0 && vectors.count % dimension == 0, "vectors 크기가 dimension의 배수가 아니다")
        self.dimension = dimension
        self.count = vectors.count / dimension
        var normalized = vectors
        for row in 0..<count {
            let range = row * dimension..<(row + 1) * dimension
            normalized.replaceSubrange(range, with: Self.normalized(Array(vectors[range])))
        }
        self.matrix = normalized
    }

    public init(index: SymbolIndex) {
        self.init(vectors: index.vectors, dimension: index.dimension)
    }

    /// 모든 행의 코사인 유사도(-1...1). 결과 순서는 행 순서와 같다.
    public func scores(for query: [Float]) -> [Float] {
        precondition(query.count == dimension, "쿼리 차원이 인덱스와 다르다")
        guard count > 0 else { return [] }
        let unitQuery = Self.normalized(query)
        var result = [Float](repeating: 0, count: count)
        // (count × dimension) · (dimension × 1) = (count × 1)
        vDSP_mmul(matrix, 1, unitQuery, 1, &result, 1, vDSP_Length(count), 1, vDSP_Length(dimension))
        return result
    }

    /// 유사도가 높은 순으로 상위 `limit`개의 (행 번호, 유사도).
    public func topMatches(for query: [Float], limit: Int) -> [(index: Int, score: Float)] {
        let scores = scores(for: query)
        return scores.indices
            .sorted { scores[$0] != scores[$1] ? scores[$0] > scores[$1] : $0 < $1 }
            .prefix(max(0, limit))
            .map { ($0, scores[$0]) }
    }

    static func normalized(_ vector: [Float]) -> [Float] {
        let length = sqrt(vDSP.sumOfSquares(vector))
        guard length > 0 else { return vector }
        return vDSP.divide(vector, length)
    }
}
