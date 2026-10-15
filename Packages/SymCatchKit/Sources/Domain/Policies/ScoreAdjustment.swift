//
//  ScoreAdjustment.swift
//  Domain
//
//  Created by Hongjeongmin on 10/12/26.
//

import Foundation

/// 검색 점수 보정 세기 묶음(방식마다 하나, 평가 실행으로 정한다)
public struct ScoreWeights: Sendable, Hashable {
    /// 만능 닮은꼴 보정 세기(`HubnessCorrection`)
    public let hubness: Double
    /// 방향 보정 세기: 잉크 배치 유사도를 이만큼 더한다
    public let layout: Double

    public init(hubness: Double = 0, layout: Double = 0) {
        self.hubness = hubness
        self.layout = layout
    }

    public static let none = ScoreWeights()
}

/// 원시 점수에 보정을 차례로 적용한다.
///
///     최종 점수 = 닮은꼴 보정 점수 + 방향 세기 × 잉크 배치 유사도
///
/// 방향 보정: Vision 특징 벡터는 좌우가 반대인 짝(→/←, ▶/◀)을 거의 같은 점수로 본다(2026-10-12 실기기 평가).
/// 잉크 배치는 위치를 그대로 비교하므로, 같은 점수대에서 방향이 맞는 쪽을 앞으로 올린다.
public enum ScoreAdjustment {
    public static func adjusted(_ scored: [ScoredSymbol], weights: ScoreWeights) -> [ScoredSymbol] {
        let corrected = HubnessCorrection.corrected(scored, weight: weights.hubness)
        guard weights.layout > 0, !corrected.isEmpty, corrected.allSatisfy({ $0.layout != nil }) else { return corrected }
        return corrected.map { $0.withScore($0.score + weights.layout * ($0.layout ?? 0)) }
    }
}
