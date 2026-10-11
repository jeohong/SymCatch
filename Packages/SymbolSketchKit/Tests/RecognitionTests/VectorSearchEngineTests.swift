//
//  VectorSearchEngineTests.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Recognition

struct VectorSearchEngineTests {
    // 행 0: x축, 행 1: y축, 행 2: 45도, 행 3: 반대 방향
    private let engine = VectorSearchEngine(vectors: [
        1, 0,
        0, 3,
        2, 2,
        -1, 0,
    ], dimension: 2)

    @Test func 코사인_유사도를_계산한다() {
        let scores = engine.scores(for: [5, 0])
        #expect(abs(scores[0] - 1) < 1e-6)
        #expect(abs(scores[1]) < 1e-6)
        #expect(abs(scores[2] - Float(sqrt(0.5))) < 1e-6)
        #expect(abs(scores[3] + 1) < 1e-6)
    }

    @Test func 유사도_높은_순으로_상위_limit개() {
        let top = engine.topMatches(for: [1, 0.1], limit: 2)
        #expect(top.map(\.index) == [0, 2])
    }

    @Test func 쿼리_길이는_결과에_영향이_없다() {
        let short = engine.scores(for: [0.001, 0.002])
        let long = engine.scores(for: [100, 200])
        #expect(zip(short, long).allSatisfy { abs($0 - $1) < 1e-6 })
    }

    @Test func 무작위_벡터에서도_단순_계산과_같다() {
        let dimension = 64, count = 200
        var generator = SystemRandomNumberGenerator()
        let vectors = (0..<count * dimension).map { _ in Float.random(in: -1...1, using: &generator) }
        let query = (0..<dimension).map { _ in Float.random(in: -1...1, using: &generator) }
        let scores = VectorSearchEngine(vectors: vectors, dimension: dimension).scores(for: query)

        let queryLength = sqrt(query.reduce(0) { $0 + $1 * $1 })
        for row in [0, 57, 199] {
            let vector = vectors[row * dimension..<(row + 1) * dimension]
            let dot = zip(vector, query).reduce(0) { $0 + $1.0 * $1.1 }
            let length = sqrt(vector.reduce(0) { $0 + $1 * $1 })
            #expect(abs(scores[row] - dot / (length * queryLength)) < 1e-4)
        }
    }
}
