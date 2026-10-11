//
//  ScoreCalibratorTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Testing
@testable import Domain

struct ScoreCalibratorTests {
    let calibrator = ScoreCalibrator(sLow: 0.6, sHigh: 0.85)

    @Test func sLow는_0퍼센트_sHigh는_100퍼센트() {
        #expect(calibrator.percent(for: 0.6) == 0)
        #expect(calibrator.percent(for: 0.85) == 100)
    }

    @Test func 범위를_벗어나면_0과_100으로_자른다() {
        #expect(calibrator.percent(for: 0.1) == 0)
        #expect(calibrator.percent(for: 0.99) == 100)
    }

    @Test(arguments: [
        (0.725, 50),    // 정확히 가운데
        (0.82375, 90),  // 89.5 → 반올림 90
        (0.82374, 89),  // 89.496 → 89
        (0.8475, 99),
    ])
    func 선형으로_바꾸고_반올림한다(score: Double, expected: Int) {
        #expect(calibrator.percent(for: score) == expected)
    }
}
