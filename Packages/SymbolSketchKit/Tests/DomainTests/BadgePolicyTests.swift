//
//  BadgePolicyTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Domain

struct BadgeTierPolicyTests {
    @Test func 기준_숫자와_다음_등급() {
        #expect(BadgeTierPolicy.threshold == 85)
        #expect(BadgeTier.allCases.map(\.minimumSimilarity) == [85, 90, 95])
        #expect(BadgeTier.bronze.next == .silver && BadgeTier.gold.next == nil)
    }

    @Test(arguments: [
        (84, nil), (85, BadgeTier.bronze), (89, .bronze),
        (90, .silver), (94, .silver),
        (95, .gold), (100, .gold),
    ] as [(Int, BadgeTier?)])
    func 등급_경계값(similarity: Int, expected: BadgeTier?) {
        #expect(BadgeTierPolicy.tier(for: similarity) == expected)
    }
}

struct BadgeAwardPolicyTests {
    private let now = Fixtures.date()

    private func evaluate(existing: SymbolBadge? = nil, similarity: Int, eligible: Bool = true) -> BadgeAward {
        BadgeAwardPolicy.evaluate(existing: existing, symbolName: "heart", similarity: similarity,
                                  sketch: Fixtures.sketch, isEligible: eligible, now: now)
    }

    private func badge(_ tier: BadgeTier, best: Int) -> SymbolBadge {
        SymbolBadge(symbolName: "heart", tier: tier, bestSimilarity: best, bestSketch: Fixtures.otherSketch, earnedAt: Fixtures.date(days: -3))
    }

    @Test func 기준_미만이면_뱃지_없음() {
        #expect(evaluate(similarity: 84) == .none)
    }

    @Test func 처음_기준_이상이면_새_뱃지와_축하() {
        let award = evaluate(similarity: 87)
        guard case .newBadge(let badge) = award else {
            Issue.record("새 뱃지여야 한다: \(award)")
            return
        }
        #expect(badge.tier == .bronze)
        #expect(badge.bestSimilarity == 87)
        #expect(badge.earnedAt == now)
        #expect(award.celebrates)
    }

    @Test func 단순_심볼은_구십_이상이어도_뱃지_없음() {
        #expect(evaluate(similarity: 99, eligible: false) == .none)
    }

    @Test func 더_높은_등급이면_승급과_축하() {
        let award = evaluate(existing: badge(.bronze, best: 87), similarity: 92)
        guard case .upgraded(let from, let upgraded) = award else {
            Issue.record("승급이어야 한다: \(award)")
            return
        }
        #expect(from == .bronze)
        #expect(upgraded.tier == .silver)
        #expect(upgraded.bestSimilarity == 92)
        #expect(upgraded.bestSketch == Fixtures.sketch)
        #expect(upgraded.upgradedAt == now)
        #expect(upgraded.earnedAt == Fixtures.date(days: -3))
        #expect(award.celebrates)
    }

    @Test func 같은_등급에서_점수만_오르면_조용히_기록만_갱신() {
        let award = evaluate(existing: badge(.bronze, best: 86), similarity: 88)
        guard case .silentUpdate(let updated) = award else {
            Issue.record("조용한 갱신이어야 한다: \(award)")
            return
        }
        #expect(updated.tier == .bronze)
        #expect(updated.bestSimilarity == 88)
        #expect(updated.upgradedAt == nil)
        #expect(!award.celebrates)
    }

    @Test func 기존_최고보다_낮거나_같으면_변화_없음() {
        #expect(evaluate(existing: badge(.silver, best: 93), similarity: 93) == .none)
        #expect(evaluate(existing: badge(.silver, best: 93), similarity: 90) == .none)
    }
}

struct BadgeHintTests {
    private func match(_ similarity: Int, eligible: Bool = true) -> SymbolMatch {
        SymbolMatch(name: "heart", variants: [], similarity: similarity, isBadgeEligible: eligible)
    }

    private func owned(_ tier: BadgeTier) -> SymbolBadge {
        SymbolBadge(symbolName: "heart", tier: tier, bestSimilarity: 90, bestSketch: Fixtures.sketch, earnedAt: Fixtures.date())
    }

    @Test func 보유하지_않았고_기준_이상이면_획득_가능() {
        #expect(BadgeHint.evaluate(match(87), owned: nil) == .eligible(.bronze))
        #expect(BadgeHint.evaluate(match(84), owned: nil) == .none)
    }

    @Test func 더_높은_등급이면_승급_가능() {
        #expect(BadgeHint.evaluate(match(92), owned: owned(.bronze)) == .eligible(.silver))
        #expect(BadgeHint.evaluate(match(99), owned: owned(.silver)) == .eligible(.gold))
    }

    @Test func 같거나_낮은_등급이면_보유_중() {
        #expect(BadgeHint.evaluate(match(88), owned: owned(.bronze)) == .owned(.bronze))
        #expect(BadgeHint.evaluate(match(70), owned: owned(.gold)) == .owned(.gold))
    }

    @Test func 단순_심볼은_제외() {
        #expect(BadgeHint.evaluate(match(99, eligible: false), owned: nil) == .excluded)
    }
}
