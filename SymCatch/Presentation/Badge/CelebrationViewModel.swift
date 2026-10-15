//
//  CelebrationViewModel.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 축하 모달(S4)에 보여 줄 카드 묶음. 뱃지 카드가 먼저, 업적 카드가 뒤에 온다(디자인 S4).
struct Celebration: Identifiable, Hashable {
    let id = UUID()
    let cards: [BadgeCardContent]

    /// 축하할 것이 없으면 nil
    init?(outcome: SelectionOutcome, sketch: Sketch) {
        var cards: [BadgeCardContent] = []
        switch outcome.badgeAward {
        case .newBadge(let badge):
            cards.append(.badge(symbolName: badge.symbolName, tier: badge.tier, isUpgrade: false,
                                similarity: badge.bestSimilarity, sketch: sketch, date: badge.earnedAt))
        case .upgraded(_, let badge):
            cards.append(.badge(symbolName: badge.symbolName, tier: badge.tier, isUpgrade: true,
                                similarity: badge.bestSimilarity, sketch: sketch, date: badge.upgradedAt ?? badge.earnedAt))
        case .none, .silentUpdate:
            break
        }
        cards += outcome.newAchievements.compactMap { achievement in
            achievement.unlockedAt.map { BadgeCardContent.achievement(achievement.id, unlockedAt: $0) }
        }
        guard !cards.isEmpty else { return nil }
        self.cards = cards
    }
}

/// 축하 모달: 카드 넘기기, 성공 햅틱
@MainActor @Observable
final class CelebrationViewModel {
    let celebration: Celebration
    private(set) var index = 0

    private let haptics: any HapticsClient
    private let onFinish: () -> Void

    init(celebration: Celebration, haptics: any HapticsClient, onFinish: @escaping () -> Void) {
        self.celebration = celebration
        self.haptics = haptics
        self.onFinish = onFinish
    }

    var current: BadgeCardContent { celebration.cards[index] }
    var pageCount: Int { celebration.cards.count }
    var isLastPage: Bool { index == pageCount - 1 }

    /// 모달이 나타날 때
    func appeared() {
        haptics.success()
    }

    /// "다음" / "확인"
    func advance() {
        if isLastPage {
            onFinish()
        } else {
            index += 1
        }
    }
}
