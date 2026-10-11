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

/// 업적 진행 상황 갱신(MVP 3종)
public enum AchievementEvaluator {
    /// - Parameters:
    ///   - current: 저장된 업적들(없는 업적은 진행 0으로 본다)
    ///   - stats: 이번 선택까지 반영한 통계
    ///   - badgeCount: 이번 선택까지 반영한 심볼 뱃지 수
    /// - Returns: 모든 업적의 새 상태와, 이번에 새로 달성한 업적
    public static func evaluate(
        current: [Achievement],
        stats: UserStats,
        badgeCount: Int,
        now: Date
    ) -> (all: [Achievement], newlyUnlocked: [Achievement]) {
        let byID = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var all: [Achievement] = []
        var unlocked: [Achievement] = []

        for id in AchievementID.allCases {
            var achievement = byID[id] ?? Achievement(id: id)
            let progress = switch id {
            case .firstStroke: min(stats.totalSelections, id.goal)
            case .sharpshooter, .collector10: min(badgeCount, id.goal)
            }
            achievement.progress = max(achievement.progress, progress)
            if !achievement.isUnlocked, achievement.progress >= achievement.goal {
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
