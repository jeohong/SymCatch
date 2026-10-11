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
    @Test(arguments: [
        (89, nil), (90, BadgeTier.bronze), (94, .bronze),
        (95, .silver), (97, .silver),
        (98, .gold), (100, .gold),
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

    @Test func 구십_미만이면_뱃지_없음() {
        #expect(evaluate(similarity: 89) == .none)
    }

    @Test func 처음_구십_이상이면_새_뱃지와_축하() {
        let award = evaluate(similarity: 92)
        guard case .newBadge(let badge) = award else {
            Issue.record("새 뱃지여야 한다: \(award)")
            return
        }
        #expect(badge.tier == .bronze)
        #expect(badge.bestSimilarity == 92)
        #expect(badge.earnedAt == now)
        #expect(award.celebrates)
    }

    @Test func 단순_심볼은_구십_이상이어도_뱃지_없음() {
        #expect(evaluate(similarity: 99, eligible: false) == .none)
    }

    @Test func 더_높은_등급이면_승급과_축하() {
        let award = evaluate(existing: badge(.bronze, best: 93), similarity: 96)
        guard case .upgraded(let from, let upgraded) = award else {
            Issue.record("승급이어야 한다: \(award)")
            return
        }
        #expect(from == .bronze)
        #expect(upgraded.tier == .silver)
        #expect(upgraded.bestSimilarity == 96)
        #expect(upgraded.bestSketch == Fixtures.sketch)
        #expect(upgraded.upgradedAt == now)
        #expect(upgraded.earnedAt == Fixtures.date(days: -3))
        #expect(award.celebrates)
    }

    @Test func 같은_등급에서_점수만_오르면_조용히_기록만_갱신() {
        let award = evaluate(existing: badge(.bronze, best: 91), similarity: 94)
        guard case .silentUpdate(let updated) = award else {
            Issue.record("조용한 갱신이어야 한다: \(award)")
            return
        }
        #expect(updated.tier == .bronze)
        #expect(updated.bestSimilarity == 94)
        #expect(updated.upgradedAt == nil)
        #expect(!award.celebrates)
    }

    @Test func 기존_최고보다_낮거나_같으면_변화_없음() {
        #expect(evaluate(existing: badge(.silver, best: 96), similarity: 96) == .none)
        #expect(evaluate(existing: badge(.silver, best: 96), similarity: 92) == .none)
    }
}
