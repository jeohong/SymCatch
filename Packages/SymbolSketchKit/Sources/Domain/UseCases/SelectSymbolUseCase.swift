//
//  SelectSymbolUseCase.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 결과를 탭한 뒤 일어난 일. 축하 모달(S4)에 보여 줄 카드를 정한다.
public struct SelectionOutcome: Sendable, Hashable {
    public let record: FoundRecord
    public let badgeAward: BadgeAward
    /// 이번에 새로 달성한 업적(뱃지 카드 다음 장으로 보여 줌)
    public let newAchievements: [Achievement]

    public init(record: FoundRecord, badgeAward: BadgeAward, newAchievements: [Achievement]) {
        self.record = record
        self.badgeAward = badgeAward
        self.newAchievements = newAchievements
    }

    /// 축하 모달을 띄울지
    public var hasCelebration: Bool {
        badgeAward.celebrates || !newAchievements.isEmpty
    }
}

public protocol SelectSymbolUseCase: Sendable {
    func execute(match: SymbolMatch, sketch: Sketch, now: Date) async throws -> SelectionOutcome
}

/// 결과 탭 = "찾았다"는 신호(기획서 2.2, 5장).
/// 1) 최근 찾은 심볼 저장(심볼당 1건, 최고 기록 유지, 200건 초과분 삭제)
/// 2) 뱃지 판정(탭 시점에만, 기획서 10.3)
/// 3) 연속 출석·업적 갱신
public struct DefaultSelectSymbolUseCase: SelectSymbolUseCase {
    private let records: any FoundRecordRepository
    private let badges: any BadgeRepository
    private let achievements: any AchievementRepository
    private let stats: any UserStatsRepository
    private let calendar: Calendar

    public init(
        records: any FoundRecordRepository,
        badges: any BadgeRepository,
        achievements: any AchievementRepository,
        stats: any UserStatsRepository,
        calendar: Calendar = .current
    ) {
        self.records = records
        self.badges = badges
        self.achievements = achievements
        self.stats = stats
        self.calendar = calendar
    }

    public func execute(match: SymbolMatch, sketch: Sketch, now: Date) async throws -> SelectionOutcome {
        // 1) 최근 기록
        var record: FoundRecord
        if var existing = try await records.record(forSymbol: match.name) {
            existing.foundAt = now
            if match.similarity > existing.similarity {
                existing.similarity = match.similarity
                existing.sketch = sketch
            }
            record = existing
        } else {
            record = FoundRecord(symbolName: match.name, sketch: sketch, similarity: match.similarity, foundAt: now)
        }
        try await records.save(record)
        let overflow = HistoryRetentionPolicy.overflow(try await records.all())
        if !overflow.isEmpty {
            try await records.delete(ids: overflow.map(\.id))
        }

        // 2) 뱃지
        let award = BadgeAwardPolicy.evaluate(
            existing: try await badges.badge(forSymbol: match.name),
            symbolName: match.name,
            similarity: match.similarity,
            sketch: sketch,
            isEligible: match.isBadgeEligible,
            now: now
        )
        if let badge = award.badgeToSave {
            try await badges.save(badge)
        }

        // 3) 연속 출석·업적
        let updatedStats = StreakCalculator.update(try await stats.load(), now: now, calendar: calendar)
        try await stats.save(updatedStats)
        let evaluation = AchievementEvaluator.evaluate(
            current: try await achievements.all(),
            stats: updatedStats,
            badgeCount: try await badges.all().count,
            now: now
        )
        try await achievements.save(evaluation.all)

        record = try await records.record(forSymbol: match.name) ?? record
        return SelectionOutcome(record: record, badgeAward: award, newAchievements: evaluation.newlyUnlocked)
    }
}
