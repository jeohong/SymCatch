//
//  BadgePolicy.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 정수 유사도 → 뱃지 등급(기획서 10.3). 90 ≤ % < 95 브론즈, 95 ≤ % < 98 실버, % ≥ 98 골드.
public enum BadgeTierPolicy {
    public static let threshold = 90

    public static func tier(for similarity: Int) -> BadgeTier? {
        switch similarity {
        case 98...: .gold
        case 95..<98: .silver
        case 90..<95: .bronze
        default: nil
        }
    }
}

/// 결과를 탭했을 때 뱃지를 어떻게 할지(기획서 3.1, 10.3)
public enum BadgeAward: Sendable, Hashable {
    /// 뱃지와 관계없음(90% 미만이거나 뱃지 대상이 아닌 단순 심볼)
    case none
    /// 처음 받은 뱃지 → 축하 모달
    case newBadge(SymbolBadge)
    /// 더 높은 등급으로 승급 → 축하 모달
    case upgraded(from: BadgeTier, to: SymbolBadge)
    /// 같은 등급 안에서 최고 기록만 올랐음 → 조용히 저장, 모달 없음
    case silentUpdate(SymbolBadge)

    /// 축하 모달을 띄울지
    public var celebrates: Bool {
        switch self {
        case .newBadge, .upgraded: true
        case .none, .silentUpdate: false
        }
    }

    /// 저장해야 할 뱃지(변화가 없으면 nil)
    public var badgeToSave: SymbolBadge? {
        switch self {
        case .none: nil
        case .newBadge(let badge), .silentUpdate(let badge): badge
        case .upgraded(_, let badge): badge
        }
    }
}

public enum BadgeAwardPolicy {
    /// - Parameters:
    ///   - existing: 이미 가진 이 심볼의 뱃지
    ///   - similarity: 이번 유사도(정수)
    ///   - isEligible: 뱃지 대상 심볼인지(너무 단순한 심볼은 제외)
    public static func evaluate(
        existing: SymbolBadge?,
        symbolName: String,
        similarity: Int,
        sketch: Sketch,
        isEligible: Bool,
        now: Date
    ) -> BadgeAward {
        guard isEligible, let tier = BadgeTierPolicy.tier(for: similarity) else { return .none }

        guard var badge = existing else {
            return .newBadge(SymbolBadge(symbolName: symbolName, tier: tier, bestSimilarity: similarity, bestSketch: sketch, earnedAt: now))
        }
        guard similarity > badge.bestSimilarity else { return .none }

        badge.bestSimilarity = similarity
        badge.bestSketch = sketch
        if tier > badge.tier {
            let previous = badge.tier
            badge.tier = tier
            badge.upgradedAt = now
            return .upgraded(from: previous, to: badge)
        }
        return .silentUpdate(badge)
    }
}

/// 결과 행에 붙일 뱃지 안내(디자인 S1·S2 행 라벨)
public enum BadgeHint: Sendable, Hashable {
    /// 표시 없음(90% 미만이고 보유하지도 않음)
    case none
    /// 탭하면 이 등급을 새로 받거나 이 등급으로 승급한다("뱃지 획득 가능")
    case eligible(BadgeTier)
    /// 이미 이 등급 이상을 보유("보유 중 · {등급}")
    case owned(BadgeTier)
    /// 단순 심볼이라 뱃지 대상이 아님("단순 심볼 · 뱃지 제외")
    case excluded

    /// - Parameters:
    ///   - match: 검색 결과
    ///   - owned: 이 심볼로 이미 받은 뱃지
    public static func evaluate(_ match: SymbolMatch, owned: SymbolBadge?) -> BadgeHint {
        guard match.isBadgeEligible else { return .excluded }
        if let reachable = BadgeTierPolicy.tier(for: match.similarity), owned.map({ reachable > $0.tier }) ?? true {
            return .eligible(reachable)
        }
        return owned.map { .owned($0.tier) } ?? .none
    }

    /// 탭하면 축하 모달이 뜨는지
    public var isEligible: Bool {
        if case .eligible = self { true } else { false }
    }
}
