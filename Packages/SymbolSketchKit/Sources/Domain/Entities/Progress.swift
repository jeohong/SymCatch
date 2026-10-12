//
//  Progress.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 뱃지 등급(기획서 3.1, 10.3). 순서가 곧 높낮이다.
public enum BadgeTier: Int, Sendable, Hashable, Codable, Comparable, CaseIterable {
    case bronze
    case silver
    case gold

    public static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 이 등급이 되는 최소 유사도(%). 기준 숫자는 여기 한 곳에만 둔다(화면 문구도 이 값을 쓴다).
    /// 2026-10-12: 90/95/98 → 85/90/95(계획서 7장 결정 15)
    public var minimumSimilarity: Int {
        switch self {
        case .bronze: 85
        case .silver: 90
        case .gold: 95
        }
    }

    /// 다음 등급(골드면 nil)
    public var next: BadgeTier? {
        BadgeTier(rawValue: rawValue + 1)
    }
}

/// 최근 찾은 심볼 한 건. 심볼당 1건(기획서 2.4).
public struct FoundRecord: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let symbolName: String
    /// 최고 유사도를 낸 그림
    public var sketch: Sketch
    /// 지금까지의 최고 유사도
    public var similarity: Int
    /// 마지막으로 찾은 때
    public var foundAt: Date

    public init(id: UUID = UUID(), symbolName: String, sketch: Sketch, similarity: Int, foundAt: Date) {
        self.id = id
        self.symbolName = symbolName
        self.sketch = sketch
        self.similarity = similarity
        self.foundAt = foundAt
    }
}

/// 심볼 뱃지. 심볼당 하나, 더 높은 등급을 달성하면 승급한다(기획서 3.1).
public struct SymbolBadge: Sendable, Hashable, Codable, Identifiable {
    public let symbolName: String
    public var tier: BadgeTier
    public var bestSimilarity: Int
    /// 최고 기록을 낸 그림
    public var bestSketch: Sketch
    public let earnedAt: Date
    /// 마지막 승급 시각(승급한 적 없으면 nil)
    public var upgradedAt: Date?

    public var id: String { symbolName }

    public init(symbolName: String, tier: BadgeTier, bestSimilarity: Int, bestSketch: Sketch, earnedAt: Date, upgradedAt: Date? = nil) {
        self.symbolName = symbolName
        self.tier = tier
        self.bestSimilarity = bestSimilarity
        self.bestSketch = bestSketch
        self.earnedAt = earnedAt
        self.upgradedAt = upgradedAt
    }
}

/// 업적 종류. MVP는 앞의 3개(기획서 12.1), 나머지는 출시 후.
public enum AchievementID: String, Sendable, Hashable, Codable, CaseIterable {
    /// 첫 번째 획: 처음으로 결과를 골랐을 때
    case firstStroke
    /// 명사수: 심볼 뱃지 1개
    case sharpshooter
    /// 수집가 10: 심볼 뱃지 10개
    case collector10

    /// 달성에 필요한 값
    public var goal: Int {
        switch self {
        case .firstStroke: 1
        case .sharpshooter: 1
        case .collector10: 10
        }
    }
}

/// 업적 진행 상황
public struct Achievement: Sendable, Hashable, Codable, Identifiable {
    public let id: AchievementID
    public var progress: Int
    public var unlockedAt: Date?

    public var goal: Int { id.goal }
    public var isUnlocked: Bool { unlockedAt != nil }

    public init(id: AchievementID, progress: Int = 0, unlockedAt: Date? = nil) {
        self.id = id
        self.progress = progress
        self.unlockedAt = unlockedAt
    }
}

/// 누적 통계(연속 출석 계산용)
public struct UserStats: Sendable, Hashable, Codable {
    /// 결과를 고른 횟수
    public var totalSelections: Int
    /// 연속으로 결과를 고른 날 수
    public var streakDays: Int
    /// 마지막으로 결과를 고른 날(기기 시간대 기준 그날 0시)
    public var lastActiveDay: Date?

    public init(totalSelections: Int = 0, streakDays: Int = 0, lastActiveDay: Date? = nil) {
        self.totalSelections = totalSelections
        self.streakDays = streakDays
        self.lastActiveDay = lastActiveDay
    }

    public static let initial = UserStats()
}
