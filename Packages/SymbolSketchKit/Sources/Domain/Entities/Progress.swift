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
    /// 100%(2026-10-12 추가). 저장값(rawValue 3)이 기존 등급 뒤라 이전 기록과 호환된다.
    case legendary

    public static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 이 등급이 되는 최소 유사도(%). 기준 숫자는 여기 한 곳에만 둔다(화면 문구도 이 값을 쓴다).
    /// 2026-10-12: 90/95/98 → 85/90/95(계획서 7장 결정 15), 100 레전더리 추가(결정 17)
    public var minimumSimilarity: Int {
        switch self {
        case .bronze: 85
        case .silver: 90
        case .gold: 95
        case .legendary: 100
        }
    }

    /// 다음 등급(최고 등급이면 nil)
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

/// 업적 종류(기획서 3.2, 계획서 7장 결정 20): 일반 8개 + 카테고리마다 입문(10개)·전설(전부).
/// 저장할 때는 `rawValue` 문자열을 쓴다. 일반 업적은 이전 저장값("firstStroke" 등)과 같고,
/// 카테고리 업적은 "categoryStarter.nature"처럼 카테고리 키를 붙인다.
public enum AchievementID: Sendable, Hashable {
    /// 첫 번째 획: 처음으로 결과를 골랐을 때
    case firstStroke
    /// 명사수: 심볼 뱃지 1개
    case sharpshooter
    /// 수집가 10 / 50 / 100: 심볼 뱃지 수
    case collector10
    case collector50
    case collector100
    /// 한 붓에: 획 1개로 그려서 뱃지 기준 이상인 결과를 고름
    case oneStroke
    /// 골드 핸드: 골드 이상 뱃지 5개
    case goldHand
    /// 연속 출석 7일
    case streak7
    /// 카테고리 입문: 그 카테고리 대표 심볼 10개 뱃지
    case categoryStarter(String)
    /// 카테고리 전설: 그 카테고리 대표 심볼 뱃지 전부
    case categoryMaster(String)

    /// 일반 업적(화면 순서)
    public static let general: [AchievementID] = [
        .firstStroke, .sharpshooter, .collector10, .collector50, .collector100, .oneStroke, .goldHand, .streak7,
    ]
    /// 카테고리 입문에 필요한 뱃지 수
    public static let categoryStarterGoal = 10

    /// 고정된 목표값. 카테고리 업적은 카테고리 크기에 따라 달라 nil(판정할 때 정한다).
    public var fixedGoal: Int? {
        switch self {
        case .firstStroke, .sharpshooter, .oneStroke: 1
        case .collector10: 10
        case .collector50: 50
        case .collector100: 100
        case .goldHand: 5
        case .streak7: 7
        case .categoryStarter, .categoryMaster: nil
        }
    }

    /// 카테고리 업적이면 카테고리 키
    public var categoryKey: String? {
        switch self {
        case .categoryStarter(let key), .categoryMaster(let key): key
        default: nil
        }
    }

    private static let starterPrefix = "categoryStarter."
    private static let masterPrefix = "categoryMaster."
    private static let generalByRawValue = Dictionary(uniqueKeysWithValues: general.map { ($0.rawValue, $0) })

    public var rawValue: String {
        switch self {
        case .firstStroke: "firstStroke"
        case .sharpshooter: "sharpshooter"
        case .collector10: "collector10"
        case .collector50: "collector50"
        case .collector100: "collector100"
        case .oneStroke: "oneStroke"
        case .goldHand: "goldHand"
        case .streak7: "streak7"
        case .categoryStarter(let key): Self.starterPrefix + key
        case .categoryMaster(let key): Self.masterPrefix + key
        }
    }

    public init?(rawValue: String) {
        if let general = Self.generalByRawValue[rawValue] {
            self = general
        } else if rawValue.hasPrefix(Self.starterPrefix), rawValue.count > Self.starterPrefix.count {
            self = .categoryStarter(String(rawValue.dropFirst(Self.starterPrefix.count)))
        } else if rawValue.hasPrefix(Self.masterPrefix), rawValue.count > Self.masterPrefix.count {
            self = .categoryMaster(String(rawValue.dropFirst(Self.masterPrefix.count)))
        } else {
            return nil
        }
    }
}

extension AchievementID: Codable {
    public init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        guard let id = AchievementID(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "알 수 없는 업적: \(rawValue)"))
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// 업적 진행 상황
public struct Achievement: Sendable, Hashable, Codable, Identifiable {
    public let id: AchievementID
    public var progress: Int
    public var unlockedAt: Date?
    /// 달성에 필요한 값. 카테고리 업적은 카테고리 크기로 정해진다(저장하지 않고 판정·조회 때 붙인다).
    public var goal: Int

    public var isUnlocked: Bool { unlockedAt != nil }

    public init(id: AchievementID, progress: Int = 0, unlockedAt: Date? = nil, goal: Int? = nil) {
        self.id = id
        self.progress = progress
        self.unlockedAt = unlockedAt
        self.goal = goal ?? id.fixedGoal ?? 1
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
