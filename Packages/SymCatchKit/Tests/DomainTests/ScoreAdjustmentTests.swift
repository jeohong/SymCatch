//
//  ScoreAdjustmentTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/12/26.
//

import Foundation
import Testing
@testable import Domain

struct ScoreAdjustmentTests {
    private func symbol(_ name: String, _ score: Double, layout: Double?) -> ScoredSymbol {
        ScoredSymbol(name: name, family: name, score: score, hubness: 0.5, layout: layout)
    }

    @Test func 방향이_맞는_쪽이_앞선다() {
        // Vision 점수는 ←가 조금 높지만, 잉크 배치는 →가 훨씬 비슷하다.
        let scored = [symbol("arrow.left", 0.768, layout: 0.2), symbol("arrow.right", 0.758, layout: 0.9)]
        let adjusted = ScoreAdjustment.adjusted(scored, weights: ScoreWeights(layout: 0.05))
        #expect(adjusted[1].score > adjusted[0].score)
        #expect(abs(adjusted[1].score - (0.758 + 0.05 * 0.9)) < 1e-9)
    }

    @Test func 닮은꼴_보정을_먼저_하고_방향을_더한다() {
        let scored = [symbol("a", 0.8, layout: 0.4), symbol("b", 0.7, layout: -0.2)]
        let expected = HubnessCorrection.corrected(scored, weight: 0.25).map { $0.score + 0.1 * ($0.layout ?? 0) }
        #expect(ScoreAdjustment.adjusted(scored, weights: ScoreWeights(hubness: 0.25, layout: 0.1)).map(\.score) == expected)
    }

    @Test func 세기가_0이거나_배치가_없으면_방향은_그대로() {
        let scored = [symbol("a", 0.8, layout: nil), symbol("b", 0.7, layout: 0.3)]
        #expect(ScoreAdjustment.adjusted(scored, weights: ScoreWeights(layout: 0.1)) == scored)
        #expect(ScoreAdjustment.adjusted(scored, weights: .none) == scored)
    }
}
