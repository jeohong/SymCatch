//
//  HubnessCorrectionTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/12/26.
//

import Foundation
import Testing
@testable import Domain

struct HubnessCorrectionTests {
    private func symbol(_ name: String, _ score: Double, hubness: Double?) -> ScoredSymbol {
        ScoredSymbol(name: name, family: name, score: score, hubness: hubness)
    }

    @Test func 만능_닮은꼴은_점수가_깎여_정답이_앞선다() {
        // 원래는 hub(0.82)가 정답(0.80)보다 높다.
        let scored = [symbol("hub", 0.82, hubness: 0.9), symbol("heart", 0.80, hubness: 0.6), symbol("other", 0.5, hubness: 0.6)]
        let corrected = HubnessCorrection.corrected(scored, neighborCount: 2)
        let byName = Dictionary(uniqueKeysWithValues: corrected.map { ($0.name, $0.score) })

        // r(그림) = (0.82 + 0.80) / 2 = 0.81, 세기 1: 코사인 − (0.81 + r(심볼)) / 2
        #expect(abs(byName["hub"]! - (0.82 - (0.81 + 0.9) / 2)) < 1e-9)
        #expect(abs(byName["heart"]! - (0.80 - (0.81 + 0.6) / 2)) < 1e-9)
        #expect(byName["heart"]! > byName["hub"]!)
    }

    @Test func 세기가_약하면_덜_깎이고_0이면_그대로() {
        let scored = [symbol("hub", 0.82, hubness: 0.9), symbol("heart", 0.80, hubness: 0.6)]
        let weak = HubnessCorrection.corrected(scored, weight: 0.1, neighborCount: 2)
        #expect(weak[0].score > weak[1].score)                       // 약하면 원래 순위 유지
        #expect(HubnessCorrection.corrected(scored, weight: 0) == scored)
    }

    @Test func 이웃_정보가_없으면_그대로() {
        let scored = [symbol("a", 0.8, hubness: 0.5), symbol("b", 0.7, hubness: nil)]
        #expect(HubnessCorrection.corrected(scored) == scored)
        #expect(HubnessCorrection.corrected([]).isEmpty)
    }

    @Test func 복잡도와_이름은_유지한다() {
        let scored = [ScoredSymbol(name: "heart.fill", family: "heart", score: 0.8, complexity: 0.1, hubness: 0.5)]
        let corrected = HubnessCorrection.corrected(scored)
        #expect(corrected[0].name == "heart.fill" && corrected[0].family == "heart" && corrected[0].complexity == 0.1)
    }
}
