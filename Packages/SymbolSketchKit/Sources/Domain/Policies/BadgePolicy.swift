//
//  BadgePolicy.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 정수 유사도 → 뱃지 등급(기획서 10.3). 85 ≤ % < 90 브론즈, 90 ≤ % < 95 실버, 95 ≤ % < 100 골드, 100 레전더리.
public enum BadgeTierPolicy {
    /// 뱃지를 받는 최소 유사도(브론즈 기준)
    public static let threshold = BadgeTier.bronze.minimumSimilarity

    public static func tier(for similarity: Int) -> BadgeTier? {
        BadgeTier.allCases.last { similarity >= $0.minimumSimilarity }
    }

    /// 저장된 뱃지의 등급을 최고 유사도에 맞춰 올린다(내리지는 않는다).
    /// 등급 기준이 바뀌면(90/95/98 → 85/90/95/100, 2026-10-12) 예전에 받은 뱃지가 낮은 등급으로 남아 있기 때문이다.
    /// - Returns: 등급이 바뀐 뱃지만
    public static func reconciled(_ badges: [SymbolBadge], now: Date) -> [SymbolBadge] {
        badges.compactMap { badge in
            guard let deserved = tier(for: badge.bestSimilarity), deserved > badge.tier else { return nil }
            var updated = badge
            updated.tier = deserved
            updated.upgradedAt = now
            return updated
        }
    }
}

/// 결과를 탭했을 때 뱃지를 어떻게 할지(기획서 3.1, 10.3)
public enum BadgeAward: Sendable, Hashable {
    /// 뱃지와 관계없음(기준 미만이거나 뱃지 대상이 아닌 단순 심볼)
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
        let isNewBest = similarity > badge.bestSimilarity
        if isNewBest {
            badge.bestSimilarity = similarity
            badge.bestSketch = sketch
        }
        // 등급은 점수가 최고 기록과 같거나 낮아도 오를 수 있다(등급 기준이 바뀌었거나 새 등급이 생긴 경우).
        // 예: 예전 골드 100% → 레전더리가 생긴 뒤 다시 100%를 그리면 승급.
        if tier > badge.tier {
            let previous = badge.tier
            badge.tier = tier
            badge.upgradedAt = now
            return .upgraded(from: previous, to: badge)
        }
        return isNewBest ? .silentUpdate(badge) : .none
    }
}

/// 결과 행에 붙일 뱃지 안내(디자인 S1·S2 행 라벨)
public enum BadgeHint: Sendable, Hashable {
    /// 표시 없음(기준 미만이고 보유하지도 않음)
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
