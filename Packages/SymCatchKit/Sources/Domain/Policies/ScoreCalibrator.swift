//
//  ScoreCalibrator.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 엔진의 원시 점수(코사인 유사도 등)를 사람이 읽는 0~100 정수로 바꾼다.
///
/// 유사도 % = (s − sLow) ÷ (sHigh − sLow) × 100 을 0...100으로 자르고 반올림한다.
/// - `sLow`: 관계없는 심볼과 비교한 점수의 중앙값 → 0%
/// - `sHigh`: 정답 심볼과 비교한 점수의 중앙값 → 100%
/// 두 값은 평가셋으로 정하며 엔진(modelVersion)마다 다르다.
public struct ScoreCalibrator: Sendable, Hashable {
    public let sLow: Double
    public let sHigh: Double

    public init(sLow: Double, sHigh: Double) {
        precondition(sHigh > sLow, "sHigh는 sLow보다 커야 한다")
        self.sLow = sLow
        self.sHigh = sHigh
    }

    public func percent(for score: Double) -> Int {
        let ratio = (score - sLow) / (sHigh - sLow) * 100
        let clamped = min(max(ratio, 0), 100)
        return Int(clamped.rounded(.toNearestOrAwayFromZero))
    }
}
