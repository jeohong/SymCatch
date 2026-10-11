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

    public var id: String { name }

    public init(name: String, variants: [String], similarity: Int, score: Double = 0) {
        self.name = name
        self.variants = variants
        self.similarity = similarity
        self.score = score
    }
}

/// 인식 엔진이 내놓는 원시 점수. 묶기·보정 전 단계.
public struct ScoredSymbol: Sendable, Hashable {
    public let name: String
    public let family: String
    /// 코사인 유사도 등 엔진 고유의 점수. 클수록 비슷하다.
    public let score: Double

    public init(name: String, family: String, score: Double) {
        self.name = name
        self.family = family
        self.score = score
    }
}
