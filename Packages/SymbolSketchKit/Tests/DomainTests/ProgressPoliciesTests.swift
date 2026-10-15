//
//  ProgressPoliciesTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Domain

struct StreakCalculatorTests {
    private let calendar = Fixtures.utcCalendar

    @Test func 처음이면_하루() {
        let stats = StreakCalculator.update(.initial, now: Fixtures.date(), calendar: calendar)
        #expect(stats.streakDays == 1)
        #expect(stats.totalSelections == 1)
    }

    @Test func 같은_날_여러_번은_그대로() {
        var stats = StreakCalculator.update(.initial, now: Fixtures.date(), calendar: calendar)
        stats = StreakCalculator.update(stats, now: Fixtures.date(hours: 5), calendar: calendar)
        #expect(stats.streakDays == 1)
        #expect(stats.totalSelections == 2)
    }

    @Test func 다음_날이면_이어진다() {
        var stats = StreakCalculator.update(.initial, now: Fixtures.date(), calendar: calendar)
        stats = StreakCalculator.update(stats, now: Fixtures.date(days: 1), calendar: calendar)
        stats = StreakCalculator.update(stats, now: Fixtures.date(days: 2), calendar: calendar)
        #expect(stats.streakDays == 3)
    }

    @Test func 하루라도_빠지면_새로_시작() {
        var stats = StreakCalculator.update(.initial, now: Fixtures.date(), calendar: calendar)
        stats = StreakCalculator.update(stats, now: Fixtures.date(days: 1), calendar: calendar)
        stats = StreakCalculator.update(stats, now: Fixtures.date(days: 3), calendar: calendar)
        #expect(stats.streakDays == 1)
    }

    @Test func 자정을_넘기면_다음_날로_센다() {
        // 23시 → 다음 날 1시: 2시간 차이지만 날짜가 바뀌었으므로 이어진다.
        let late = Fixtures.date(hours: 11)          // 23:00 UTC
        let early = Fixtures.date(hours: 13)         // 다음 날 01:00 UTC
        var stats = StreakCalculator.update(.initial, now: late, calendar: calendar)
        stats = StreakCalculator.update(stats, now: early, calendar: calendar)
        #expect(stats.streakDays == 2)
    }
}

struct AchievementEvaluatorTests {
    private let now = Fixtures.date()

    private func badge(_ name: String, _ tier: BadgeTier = .bronze) -> SymbolBadge {
        SymbolBadge(symbolName: name, tier: tier, bestSimilarity: tier.minimumSimilarity, bestSketch: Fixtures.sketch, earnedAt: now)
    }

    private func badges(_ count: Int, tier: BadgeTier = .bronze) -> [SymbolBadge] {
        (0..<count).map { badge("s\($0)", tier) }
    }

    private func evaluate(_ current: [Achievement] = [], stats: UserStats = UserStats(totalSelections: 1),
                          badges: [SymbolBadge] = [], categories: [AchievementCategory] = [], oneStroke: Bool = false)
        -> (all: [Achievement], newlyUnlocked: [Achievement]) {
        AchievementEvaluator.evaluate(current: current,
                                      input: AchievementInput(stats: stats, badges: badges, categories: categories, completedOneStroke: oneStroke),
                                      now: now)
    }

    private func unlockedIDs(_ result: (all: [Achievement], newlyUnlocked: [Achievement])) -> Set<AchievementID> {
        Set(result.newlyUnlocked.map(\.id))
    }

    @Test func 첫_선택이면_첫_번째_획() {
        let result = evaluate()
        #expect(unlockedIDs(result) == [.firstStroke])
        #expect(result.all.map(\.id) == AchievementID.general)
    }

    @Test func 첫_뱃지면_명사수() {
        let current = [Achievement(id: .firstStroke, progress: 1, unlockedAt: Fixtures.date(days: -1))]
        let result = evaluate(current, stats: UserStats(totalSelections: 2), badges: badges(1))
        #expect(unlockedIDs(result) == [.sharpshooter])
        #expect(result.all.first { $0.id == .collector10 }?.progress == 1)
    }

    static let collectorCases: [(Int, Set<AchievementID>)] = [
        (9, []), (10, [.collector10]), (49, [.collector10]), (50, [.collector10, .collector50]),
        (100, [.collector10, .collector50, .collector100]),
    ]

    @Test(arguments: collectorCases)
    func 수집가는_뱃지_수로(count: Int, expected: Set<AchievementID>) {
        let current = [Achievement(id: .firstStroke, progress: 1, unlockedAt: now), Achievement(id: .sharpshooter, progress: 1, unlockedAt: now)]
        #expect(unlockedIDs(evaluate(current, badges: badges(count))) == expected)
    }

    @Test func 한_붓에는_이번_선택이_조건을_채웠을_때만() {
        #expect(!unlockedIDs(evaluate(oneStroke: false)).contains(.oneStroke))
        #expect(unlockedIDs(evaluate(oneStroke: true)).contains(.oneStroke))
    }

    @Test func 골드_핸드는_골드_이상_다섯_개() {
        let four = badges(4, tier: .gold) + badges(3, tier: .silver).map { badge("silver.\($0.symbolName)", .silver) }
        #expect(!unlockedIDs(evaluate(badges: four)).contains(.goldHand))
        let five = badges(4, tier: .gold) + [badge("legend", .legendary)]
        #expect(unlockedIDs(evaluate(badges: five)).contains(.goldHand))
    }

    @Test func 연속_출석_7일은_끊겨도_진행이_줄지_않는다() {
        #expect(unlockedIDs(evaluate(stats: UserStats(totalSelections: 7, streakDays: 7))).contains(.streak7))
        let partial = evaluate(stats: UserStats(totalSelections: 5, streakDays: 5)).all
        let afterBreak = evaluate(partial, stats: UserStats(totalSelections: 6, streakDays: 1)).all
        #expect(afterBreak.first { $0.id == .streak7 }?.progress == 5)
    }

    @Test func 카테고리_입문은_대표_10개_전설은_전부_변형은_하나로_센다() {
        let nature = AchievementCategory(key: "nature", families: Set((0..<12).map { "leaf\($0)" }))
        // leaf0과 leaf0.fill은 같은 family라 한 번만 센다.
        let nine = (0..<9).map { badge("leaf\($0)") } + [badge("leaf0.fill")]
        #expect(unlockedIDs(evaluate(badges: nine, categories: [nature])).isDisjoint(with: [.categoryStarter("nature")]))

        let ten = (0..<10).map { badge("leaf\($0)") }
        let tenResult = evaluate(badges: ten, categories: [nature])
        #expect(unlockedIDs(tenResult).contains(.categoryStarter("nature")))
        let master = tenResult.all.first { $0.id == .categoryMaster("nature") }
        #expect(master?.progress == 10)
        #expect(master?.goal == 12)

        let all = (0..<12).map { badge("leaf\($0).fill") }
        #expect(unlockedIDs(evaluate(badges: all, categories: [nature])).contains(.categoryMaster("nature")))
    }

    @Test func 작은_카테고리의_입문_목표는_카테고리_크기() {
        let shapes = AchievementCategory(key: "shapes", families: ["circle", "square", "triangle"])
        let result = evaluate(badges: [badge("circle"), badge("square"), badge("triangle")], categories: [shapes])
        #expect(result.all.first { $0.id == .categoryStarter("shapes") }?.goal == 3)
        #expect(unlockedIDs(result).isSuperset(of: [.categoryStarter("shapes"), .categoryMaster("shapes")]))
    }

    @Test func 전체_순서는_일반_다음_카테고리마다_입문과_전설() {
        let categories = [AchievementCategory(key: "a", families: ["x"]), AchievementCategory(key: "b", families: ["y"])]
        #expect(AchievementEvaluator.catalog(categories: categories).map(\.id)
                == AchievementID.general + [.categoryStarter("a"), .categoryMaster("a"), .categoryStarter("b"), .categoryMaster("b")])
    }

    @Test func 이미_달성한_업적은_다시_알리지_않고_날짜도_유지() {
        let earlier = Fixtures.date(days: -5)
        let current = AchievementID.general.map { Achievement(id: $0, progress: $0.fixedGoal ?? 1, unlockedAt: earlier) }
        let result = evaluate(current, stats: UserStats(totalSelections: 99, streakDays: 9), badges: badges(120, tier: .gold), oneStroke: true)
        #expect(result.newlyUnlocked.isEmpty)
        #expect(result.all.allSatisfy { $0.unlockedAt == earlier })
    }
}

struct AchievementIDTests {
    @Test(arguments: AchievementID.general + [.categoryStarter("nature"), .categoryMaster("privacyandsecurity")])
    func 저장_문자열로_되돌릴_수_있다(id: AchievementID) {
        #expect(AchievementID(rawValue: id.rawValue) == id)
    }

    @Test func 예전_저장값과_호환된다() {
        #expect(AchievementID(rawValue: "firstStroke") == .firstStroke)
        #expect(AchievementID(rawValue: "collector10") == .collector10)
        #expect(AchievementID(rawValue: "categoryStarter.") == nil)
        #expect(AchievementID(rawValue: "unknown") == nil)
    }
}

struct AchievementCategoryTests {
    @Test func 카테고리별_대표_family를_모으고_빈_카테고리는_뺀다() {
        let symbols = [meta("leaf", categories: ["nature"]), meta("leaf.fill", categories: ["nature"]),
                       meta("heart", categories: ["health", "nature"])]
        let categories = [SymbolCategory(key: "nature", label: "Nature", icon: "leaf"), SymbolCategory(key: "health", label: "Health", icon: "heart"),
                          SymbolCategory(key: "math", label: "Math", icon: "x.squareroot")]
        let result = AchievementCategory.make(symbols: symbols, categories: categories)
        #expect(result == [AchievementCategory(key: "nature", families: ["leaf", "heart"]), AchievementCategory(key: "health", families: ["heart"])])
    }
}

struct HistoryRetentionPolicyTests {
    @Test func 한도를_넘으면_오래된_것부터() {
        let records = (0..<5).map { FoundRecord(symbolName: "s\($0)", sketch: Fixtures.sketch, similarity: 50, foundAt: Fixtures.date(days: $0)) }
        let overflow = HistoryRetentionPolicy.overflow(records, limit: 3)
        #expect(Set(overflow.map(\.symbolName)) == ["s0", "s1"])
    }

    @Test func 한도_이하면_지우지_않는다() {
        let records = [FoundRecord(symbolName: "a", sketch: Fixtures.sketch, similarity: 1, foundAt: Fixtures.date())]
        #expect(HistoryRetentionPolicy.overflow(records).isEmpty)
    }
}

struct RecentGroupingPolicyTests {
    /// 일요일 시작 달력(한국 기본). 기준일 2026-10-11(일) 12:00 UTC → 이번 주는 10/11~10/17
    private var calendar: Calendar {
        var calendar = Fixtures.utcCalendar
        calendar.firstWeekday = 1
        return calendar
    }

    @Test func 오늘과_어제() {
        let now = Fixtures.date(days: 3)                                  // 10/14(수)
        #expect(RecentGroupingPolicy.group(of: Fixtures.date(days: 3, hours: -11), now: now, calendar: calendar) == .today)
        #expect(RecentGroupingPolicy.group(of: Fixtures.date(days: 2), now: now, calendar: calendar) == .yesterday)
    }

    @Test func 같은_달력_주면_이번_주_아니면_이전() {
        let now = Fixtures.date(days: 3)                                  // 10/14(수)
        #expect(RecentGroupingPolicy.group(of: Fixtures.date(), now: now, calendar: calendar) == .thisWeek)       // 10/11(일)
        #expect(RecentGroupingPolicy.group(of: Fixtures.date(days: -1), now: now, calendar: calendar) == .earlier) // 10/10(토)
    }

    @Test func 일요일의_어제는_지난_주여도_어제() {
        let sunday = Fixtures.date()
        #expect(RecentGroupingPolicy.group(of: Fixtures.date(days: -1), now: sunday, calendar: calendar) == .yesterday)
        #expect(RecentGroupingPolicy.group(of: Fixtures.date(days: -2), now: sunday, calendar: calendar) == .earlier)
    }

    @Test func 묶음은_고정_순서이고_빈_묶음은_빠진다() {
        let now = Fixtures.date(days: 3)
        let records = [Fixtures.date(days: -5), Fixtures.date(days: 3), Fixtures.date(days: 3, hours: -1)].enumerated().map {
            FoundRecord(symbolName: "s\($0.offset)", sketch: Fixtures.sketch, similarity: 50, foundAt: $0.element)
        }
        let grouped = RecentGroupingPolicy.grouped(records, now: now, calendar: calendar)
        #expect(grouped.map(\.group) == [.today, .earlier])
        #expect(grouped[0].records.map(\.symbolName) == ["s1", "s2"])
    }
}
