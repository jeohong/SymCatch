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
    private let catalog = ListCatalog(
        symbols: [meta("heart", categories: ["health"]), meta("star", categories: ["shapes"])],
        categoryList: [SymbolCategory(key: "health", label: "Health", icon: "heart"), SymbolCategory(key: "shapes", label: "Shapes", icon: "star")]
    )

    private var useCase: DefaultSelectSymbolUseCase {
        DefaultSelectSymbolUseCase(records: records, badges: badges, achievements: achievements, stats: stats,
                                   catalog: catalog, calendar: Fixtures.utcCalendar)
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
        _ = try await useCase.execute(match: match("star", 50), sketch: Fixtures.twoStrokes, now: Fixtures.date())
        let outcome = try await useCase.execute(match: match("heart", 87), sketch: Fixtures.twoStrokes, now: Fixtures.date(hours: 1))

        guard case .newBadge(let badge) = outcome.badgeAward else {
            Issue.record("새 뱃지여야 한다: \(outcome.badgeAward)")
            return
        }
        #expect(badge.tier == .bronze)
        // 건강 카테고리는 대표가 heart 하나라 입문·전설도 함께 달성된다.
        #expect(outcome.newAchievements.map(\.id) == [.sharpshooter, .categoryStarter("health"), .categoryMaster("health")])
        #expect(try await badges.all().count == 1)
    }

    @Test func 한_획으로_기준_이상을_고르면_한_붓에() async throws {
        let outcome = try await useCase.execute(match: match("heart", 86), sketch: Fixtures.sketch, now: Fixtures.date())
        #expect(outcome.newAchievements.map(\.id).contains(.oneStroke))
    }

    @Test(arguments: [(Fixtures.twoStrokes, 90, true), (Fixtures.sketch, 84, true), (Fixtures.sketch, 95, false)])
    func 두_획이거나_기준_미만이거나_뱃지_대상이_아니면_한_붓에가_아니다(sketch: Sketch, similarity: Int, eligible: Bool) async throws {
        let outcome = try await useCase.execute(match: match("heart", similarity, eligible: eligible), sketch: sketch, now: Fixtures.date())
        #expect(!outcome.newAchievements.map(\.id).contains(.oneStroke))
    }

    @Test func 같은_등급_재도전은_축하_없이_기록만() async throws {
        _ = try await useCase.execute(match: match("heart", 91), sketch: Fixtures.sketch, now: Fixtures.date())
        let outcome = try await useCase.execute(match: match("heart", 93), sketch: Fixtures.otherSketch, now: Fixtures.date(hours: 1))

        #expect(!outcome.hasCelebration)
        #expect(try await badges.badge(forSymbol: "heart")?.bestSimilarity == 93)
    }

    @Test func 저장된_뱃지_등급을_맞춘다() async throws {
        try await badges.save(SymbolBadge(symbolName: "heart", tier: .gold, bestSimilarity: 100, bestSketch: Fixtures.sketch, earnedAt: Fixtures.date()))
        try await badges.save(SymbolBadge(symbolName: "star", tier: .bronze, bestSimilarity: 86, bestSketch: Fixtures.sketch, earnedAt: Fixtures.date()))

        let changed = try await DefaultReconcileBadgeTiersUseCase(badges: badges).execute(now: Fixtures.date(days: 1))

        #expect(changed == 1)
        #expect(try await badges.badge(forSymbol: "heart")?.tier == .legendary)
        #expect(try await badges.badge(forSymbol: "star")?.tier == .bronze)
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

struct ReconcileAchievementsUseCaseTests {
    @Test func 업데이트_전에_받은_뱃지로_채운_업적을_조용히_달성한다() async throws {
        let badges = InMemoryBadges(), achievements = InMemoryAchievements(), stats = InMemoryStats()
        for name in ["heart", "star"] {
            try await badges.save(SymbolBadge(symbolName: name, tier: .gold, bestSimilarity: 96, bestSketch: Fixtures.sketch, earnedAt: Fixtures.date()))
        }
        // 예전 버전이 저장한 업적: 첫 번째 획·명사수만
        try await achievements.save([Achievement(id: .firstStroke, progress: 1, unlockedAt: Fixtures.date()),
                                     Achievement(id: .sharpshooter, progress: 1, unlockedAt: Fixtures.date())])
        let catalog = ListCatalog(symbols: [meta("heart", categories: ["health"]), meta("leaf", categories: ["health"])],
                                  categoryList: [SymbolCategory(key: "health", label: "Health", icon: "heart")])

        try await DefaultReconcileAchievementsUseCase(achievements: achievements, badges: badges, stats: stats, catalog: catalog)
            .execute(now: Fixtures.date(days: 3))

        let saved = Dictionary(uniqueKeysWithValues: try await achievements.all().map { ($0.id, $0) })
        #expect(saved[.firstStroke]?.unlockedAt == Fixtures.date())        // 기존 달성 날짜 유지
        // 건강 대표는 heart·leaf 2개, 그중 heart만 있다 → 입문(목표 2)은 진행 1, 아직 미달성
        #expect(saved[.categoryStarter("health")]?.progress == 1)
        #expect(saved[.categoryStarter("health")]?.isUnlocked == false)

        // leaf까지 받은 상태로 다시 맞추면 입문·전설을 조용히 달성한다.
        try await badges.save(SymbolBadge(symbolName: "leaf.fill", tier: .bronze, bestSimilarity: 86, bestSketch: Fixtures.sketch, earnedAt: Fixtures.date(days: 4)))
        try await DefaultReconcileAchievementsUseCase(achievements: achievements, badges: badges, stats: stats, catalog: catalog)
            .execute(now: Fixtures.date(days: 5))
        let after = Dictionary(uniqueKeysWithValues: try await achievements.all().map { ($0.id, $0) })
        #expect(after[.categoryStarter("health")]?.unlockedAt == Fixtures.date(days: 5))
        #expect(after[.categoryMaster("health")]?.unlockedAt == Fixtures.date(days: 5))
    }
}
