//
//  SymbolHubnessTests.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/12/26.
//

import Foundation
import Testing
@testable import Recognition

struct SymbolHubnessTests {
    @Test func 가장_닮은_다른_family_k개의_평균_코사인() {
        // a·b는 같은 방향(같은 family면 빠짐), c는 a와 직교, d는 a와 45°
        let vectors: [Float] = [1, 0,   2, 0,   0, 1,   1, 1]
        let families = ["a", "a", "c", "d"]
        let hubness = SymbolHubness.compute(vectors: vectors, dimension: 2, families: families, neighborCount: 1)

        let diagonal = Float(1 / 2.0.squareRoot())
        #expect(abs(hubness[0] - diagonal) < 1e-5)      // a의 이웃(같은 family b 제외): d
        #expect(abs(hubness[2] - diagonal) < 1e-5)      // c의 이웃: d
        #expect(abs(hubness[3] - diagonal) < 1e-5)      // d의 이웃: a·b·c 모두 45°
    }

    @Test func 여러_묶음에_걸친_큰_입력도_순서대로_계산한다() {
        // 블록(256행)을 넘는 크기: 모든 행이 같은 방향이면 이웃 평균은 1
        let count = 300
        let vectors: [Float] = (0..<count).flatMap { _ -> [Float] in [1, 2, 3] }
        let hubness = SymbolHubness.compute(vectors: vectors, dimension: 3, families: (0..<count).map { "f\($0)" }, neighborCount: 5)
        #expect(hubness.count == count)
        #expect(hubness.allSatisfy { abs($0 - 1) < 1e-4 })
    }
}
