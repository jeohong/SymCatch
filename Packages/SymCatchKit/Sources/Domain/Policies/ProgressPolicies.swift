//
//  ProgressPolicies.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 연속 출석: 결과를 고른 날을 기기 시간대 기준 날짜로 센다(기획서 10.3).
public enum StreakCalculator {
    public static func update(_ stats: UserStats, now: Date, calendar: Calendar) -> UserStats {
        var stats = stats
        stats.totalSelections += 1
        let today = calendar.startOfDay(for: now)

        if let last = stats.lastActiveDay {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day ?? 0
            switch days {
            case 0: break                               // 같은 날: 그대로
            case 1: stats.streakDays += 1               // 바로 다음 날: 이어짐
            default: stats.streakDays = 1               // 하루 이상 빠짐(또는 시계가 뒤로 감): 새로 시작
            }
        } else {
            stats.streakDays = 1
        }
        // (defer로 쓰면 안 된다: 반환값이 먼저 복사돼 날짜가 빠진다)
        stats.lastActiveDay = today
        return stats
    }
}

/// 카테고리 업적 판정용 묶음: 카테고리 키와 그 안의 대표 심볼 family(기획서 3.2).
public struct AchievementCategory: Sendable, Hashable {
    public let key: String
    public let families: Set<String>

    public init(key: String, families: Set<String>) {
        self.key = key
        self.families = families
    }

    /// 카탈로그에서 카테고리별 대표 심볼 family를 모은다. 콜렉션 격자와 같은 대표 규칙, "기타"는 제외.
    public static func make(symbols: [SymbolMeta], categories: [SymbolCategory]) -> [AchievementCategory] {
        let representatives = VariantGrouper.representatives(of: symbols)
        return categories.compactMap { category in
            let families = Set(representatives.filter { $0.categories.contains(category.key) }.map(\.family))
            return families.isEmpty ? nil : AchievementCategory(key: category.key, families: families)
        }
    }
}

/// 업적 판정에 넣는 값(이번 선택까지 반영한 상태)
public struct AchievementInput: Sendable {
    public var stats: UserStats
    public var badges: [SymbolBadge]
    public var categories: [AchievementCategory]
    /// 이번 선택이 "한 붓에" 조건(획 1개 · 뱃지 기준 이상 · 뱃지 대상)을 채웠는지
    public var completedOneStroke: Bool

    public init(stats: UserStats, badges: [SymbolBadge], categories: [AchievementCategory], completedOneStroke: Bool = false) {
        self.stats = stats
        self.badges = badges
        self.categories = categories
        self.completedOneStroke = completedOneStroke
    }
}

/// 업적 진행 상황 갱신(기획서 3.2, 계획서 7장 결정 20)
public enum AchievementEvaluator {
    /// 화면·저장 순서의 전체 업적과 목표값: 일반 8개, 그다음 카테고리마다 입문·전설.
    public static func catalog(categories: [AchievementCategory]) -> [(id: AchievementID, goal: Int)] {
        AchievementID.general.map { ($0, $0.fixedGoal ?? 1) } + categories.flatMap { category in
            [(AchievementID.categoryStarter(category.key), min(AchievementID.categoryStarterGoal, category.families.count)),
             (AchievementID.categoryMaster(category.key), category.families.count)]
        }
    }

    /// - Parameters:
    ///   - current: 저장된 업적들(없는 업적은 진행 0으로 본다)
    ///   - input: 이번 선택까지 반영한 통계·뱃지·카테고리
    /// - Returns: 모든 업적의 새 상태와, 이번에 새로 달성한 업적. 진행은 줄지 않는다(연속 출석이 끊겨도).
    public static func evaluate(current: [Achievement], input: AchievementInput, now: Date) -> (all: [Achievement], newlyUnlocked: [Achievement]) {
        let byID = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let earnedFamilies = Set(input.badges.map { VariantGrouper.family(of: $0.symbolName) })
        let goldOrBetter = input.badges.filter { $0.tier >= .gold }.count
        var all: [Achievement] = []
        var unlocked: [Achievement] = []

        for (id, goal) in catalog(categories: input.categories) {
            let measured: Int = switch id {
            case .firstStroke: input.stats.totalSelections
            case .sharpshooter, .collector10, .collector50, .collector100: input.badges.count
            case .oneStroke: input.completedOneStroke ? 1 : 0
            case .goldHand: goldOrBetter
            case .streak7: input.stats.streakDays
            case .categoryStarter(let key), .categoryMaster(let key):
                input.categories.first { $0.key == key }.map { $0.families.intersection(earnedFamilies).count } ?? 0
            }
            var achievement = byID[id] ?? Achievement(id: id)
            achievement.goal = goal
            achievement.progress = max(achievement.progress, min(measured, goal))
            if !achievement.isUnlocked, achievement.progress >= goal {
                achievement.unlockedAt = now
                unlocked.append(achievement)
            }
            all.append(achievement)
        }
        return (all, unlocked)
    }
}

/// 최근 찾은 심볼 보관 규칙: 최대 200건, 오래된 것부터 지운다(기획서 2.4).
public enum HistoryRetentionPolicy {
    public static let limit = 200

    /// 지워야 할 기록(오래된 순)
    public static func overflow(_ records: [FoundRecord], limit: Int = limit) -> [FoundRecord] {
        guard records.count > limit else { return [] }
        return Array(records.sorted { $0.foundAt > $1.foundAt }.dropFirst(limit))
    }
}

/// 최근 찾은 심볼의 날짜 묶음(기획서 2.4: 오늘, 어제, 이번 주, 이전). 순서는 선언 순서로 고정.
public enum RecentDateGroup: Int, Sendable, Hashable, CaseIterable, Comparable {
    case today
    case yesterday
    /// 달력 기준 이번 주(오늘·어제 제외)
    case thisWeek
    case earlier

    public static func < (lhs: RecentDateGroup, rhs: RecentDateGroup) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum RecentGroupingPolicy {
    public static func group(of date: Date, now: Date, calendar: Calendar) -> RecentDateGroup {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return .yesterday
        }
        if date < now, calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return .thisWeek }
        return .earlier
    }

    /// 기록(최신순)을 묶음별로 나눈다. 빈 묶음은 빠진다.
    public static func grouped(_ records: [FoundRecord], now: Date, calendar: Calendar) -> [(group: RecentDateGroup, records: [FoundRecord])] {
        let byGroup = Dictionary(grouping: records) { group(of: $0.foundAt, now: now, calendar: calendar) }
        return RecentDateGroup.allCases.compactMap { group in
            byGroup[group].map { (group, $0.sorted { $0.foundAt > $1.foundAt }) }
        }
    }
}
