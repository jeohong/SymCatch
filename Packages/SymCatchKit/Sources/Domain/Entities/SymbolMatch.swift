//
//  SymbolMatch.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 검색 결과 한 항목. 같은 family의 변형은 하나로 묶여 있다.
public struct SymbolMatch: Sendable, Hashable, Identifiable {
    /// 대표 변형 이름(묶음 안에서 점수가 가장 높은 것)
    public let name: String
    /// 같은 family의 나머지 변형 이름(점수 내림차순)
    public let variants: [String]
    /// 사람이 읽는 유사도 0...100
    public let similarity: Int
    /// 보정 전 엔진 원점수(코사인 유사도 등). 보정값을 정하거나 디버깅할 때 쓴다.
    public let score: Double
    /// 뱃지 대상인지. `circle`, `minus`처럼 너무 단순한 심볼은 대충 그려도 높은 점수가 나와 제외한다(기획서 9.5).
    public let isBadgeEligible: Bool

    public var id: String { name }

    public init(name: String, variants: [String], similarity: Int, score: Double = 0, isBadgeEligible: Bool = true) {
        self.name = name
        self.variants = variants
        self.similarity = similarity
        self.score = score
        self.isBadgeEligible = isBadgeEligible
    }
}

/// 인식 엔진이 내놓는 원시 점수. 묶기·보정 전 단계.
public struct ScoredSymbol: Sendable, Hashable {
    public let name: String
    public let family: String
    /// 코사인 유사도 등 엔진 고유의 점수. 클수록 비슷하다.
    public let score: Double
    /// 심볼 모양 복잡도(0...1). 엔진이 알 때만(단순 심볼 뱃지 제외 기준을 정할 때 쓴다).
    public let complexity: Double?
    /// 이 심볼이 다른 심볼들과 평소에 얼마나 닮는지(가까운 이웃과의 평균 점수). 엔진이 알 때만.
    /// 값이 크면 어떤 그림에도 높게 나오는 "만능 닮은꼴"이다(`HubnessCorrection`).
    public let hubness: Double?
    /// 그림과 이 심볼의 잉크 배치 유사도(-1...1). 좌우·상하가 반대면 낮다. 엔진이 알 때만(`ScoreAdjustment`).
    public let layout: Double?

    public init(name: String, family: String, score: Double, complexity: Double? = nil, hubness: Double? = nil, layout: Double? = nil) {
        self.name = name
        self.family = family
        self.score = score
        self.complexity = complexity
        self.hubness = hubness
        self.layout = layout
    }

    /// 점수만 바꾼 사본
    public func withScore(_ score: Double) -> ScoredSymbol {
        ScoredSymbol(name: name, family: family, score: score, complexity: complexity, hubness: hubness, layout: layout)
    }
}
