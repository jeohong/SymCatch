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

    @Test func 첫_선택이면_첫_번째_획() {
        let result = AchievementEvaluator.evaluate(current: [], stats: UserStats(totalSelections: 1), badgeCount: 0, now: now)
        #expect(result.newlyUnlocked.map(\.id) == [.firstStroke])
        #expect(result.all.count == AchievementID.allCases.count)
    }

    @Test func 첫_뱃지면_명사수() {
        let current = [Achievement(id: .firstStroke, progress: 1, unlockedAt: Fixtures.date(days: -1))]
        let result = AchievementEvaluator.evaluate(current: current, stats: UserStats(totalSelections: 2), badgeCount: 1, now: now)
        #expect(result.newlyUnlocked.map(\.id) == [.sharpshooter])
        #expect(result.all.first { $0.id == .collector10 }?.progress == 1)
    }

    @Test func 뱃지_열_개면_수집가_10() {
        let result = AchievementEvaluator.evaluate(current: [], stats: UserStats(totalSelections: 30), badgeCount: 10, now: now)
        #expect(Set(result.newlyUnlocked.map(\.id)) == [.firstStroke, .sharpshooter, .collector10])
    }

    @Test func 이미_달성한_업적은_다시_알리지_않고_날짜도_유지() {
        let earlier = Fixtures.date(days: -5)
        let current = AchievementID.allCases.map { Achievement(id: $0, progress: $0.goal, unlockedAt: earlier) }
        let result = AchievementEvaluator.evaluate(current: current, stats: UserStats(totalSelections: 99), badgeCount: 20, now: now)
        #expect(result.newlyUnlocked.isEmpty)
        #expect(result.all.allSatisfy { $0.unlockedAt == earlier })
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
