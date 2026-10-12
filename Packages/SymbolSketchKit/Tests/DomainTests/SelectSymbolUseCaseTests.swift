//
//  SelectSymbolUseCaseTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Domain

struct SelectSymbolUseCaseTests {
    private let records = InMemoryFoundRecords()
    private let badges = InMemoryBadges()
    private let achievements = InMemoryAchievements()
    private let stats = InMemoryStats()

    private var useCase: DefaultSelectSymbolUseCase {
        DefaultSelectSymbolUseCase(records: records, badges: badges, achievements: achievements, stats: stats, calendar: Fixtures.utcCalendar)
    }

    private func match(_ name: String, _ similarity: Int, eligible: Bool = true) -> SymbolMatch {
        SymbolMatch(name: name, variants: [], similarity: similarity, isBadgeEligible: eligible)
    }

    @Test func 같은_심볼을_다시_찾으면_기록은_한_건이고_날짜와_최고_기록만_바뀐다() async throws {
        _ = try await useCase.execute(match: match("heart", 70), sketch: Fixtures.sketch, now: Fixtures.date())
        _ = try await useCase.execute(match: match("heart", 60), sketch: Fixtures.otherSketch, now: Fixtures.date(days: 1))

        let all = try await records.all()
        #expect(all.count == 1)
        #expect(all[0].foundAt == Fixtures.date(days: 1))
        #expect(all[0].similarity == 70)              // 낮아진 점수로 덮지 않는다
        #expect(all[0].sketch == Fixtures.sketch)     // 최고 기록의 그림 유지

        _ = try await useCase.execute(match: match("heart", 80), sketch: Fixtures.otherSketch, now: Fixtures.date(days: 2))
        let updated = try await records.all()
        #expect(updated.count == 1)
        #expect(updated[0].similarity == 80)
        #expect(updated[0].sketch == Fixtures.otherSketch)
    }

    @Test func 첫_선택은_첫_번째_획_업적만_축하() async throws {
        let outcome = try await useCase.execute(match: match("heart", 70), sketch: Fixtures.sketch, now: Fixtures.date())
        #expect(outcome.badgeAward == .none)
        #expect(outcome.newAchievements.map(\.id) == [.firstStroke])
        #expect(outcome.hasCelebration)
    }

    @Test func 기준_이상을_고르면_새_뱃지와_명사수() async throws {
        _ = try await useCase.execute(match: match("star", 50), sketch: Fixtures.sketch, now: Fixtures.date())
        let outcome = try await useCase.execute(match: match("heart", 87), sketch: Fixtures.sketch, now: Fixtures.date(hours: 1))

        guard case .newBadge(let badge) = outcome.badgeAward else {
            Issue.record("새 뱃지여야 한다: \(outcome.badgeAward)")
            return
        }
        #expect(badge.tier == .bronze)
        #expect(outcome.newAchievements.map(\.id) == [.sharpshooter])
        #expect(try await badges.all().count == 1)
    }

    @Test func 같은_등급_재도전은_축하_없이_기록만() async throws {
        _ = try await useCase.execute(match: match("heart", 91), sketch: Fixtures.sketch, now: Fixtures.date())
        let outcome = try await useCase.execute(match: match("heart", 93), sketch: Fixtures.otherSketch, now: Fixtures.date(hours: 1))

        #expect(!outcome.hasCelebration)
        #expect(try await badges.badge(forSymbol: "heart")?.bestSimilarity == 93)
    }

    @Test func 기록은_200건을_넘지_않는다() async throws {
        for index in 0..<(HistoryRetentionPolicy.limit + 3) {
            _ = try await useCase.execute(match: match("s\(index)", 10), sketch: Fixtures.sketch, now: Fixtures.date(hours: index))
        }
        let all = try await records.all()
        #expect(all.count == HistoryRetentionPolicy.limit)
        #expect(!all.contains { $0.symbolName == "s0" })
    }
}
