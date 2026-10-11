//
//  SwiftDataProgressRepositories.swift
//  Storage
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import SwiftData
import Domain

// `ModelContext`는 Sendable이 아니므로 저장소마다 자기 context를 가진 actor로 접근한다(@ModelActor와 같은 구성).
// 매크로가 만드는 init은 public이 아니어서 직접 적는다.

/// 최근 찾은 심볼
public actor SwiftDataFoundRecordRepository: FoundRecordRepository, ModelActor {
    public nonisolated let modelExecutor: any ModelExecutor
    public nonisolated let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
    }

    public func all() async throws -> [FoundRecord] {
        let descriptor = FetchDescriptor<FoundRecordEntityModel>(sortBy: [SortDescriptor(\.foundAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(ProgressMappers.toDomain)
    }

    public func record(forSymbol name: String) async throws -> FoundRecord? {
        try models(named: name).first.map(ProgressMappers.toDomain)
    }

    public func save(_ record: FoundRecord) async throws {
        let id = record.id
        let existing = try modelContext.fetch(FetchDescriptor<FoundRecordEntityModel>(predicate: #Predicate { $0.id == id })).first
        // 심볼당 1건: id가 다른 같은 심볼 기록은 지운다.
        for duplicate in try models(named: record.symbolName) where duplicate.id != id {
            modelContext.delete(duplicate)
        }
        if let existing {
            try ProgressMappers.apply(record, to: existing)
        } else {
            modelContext.insert(try ProgressMappers.makeModel(record))
        }
        try modelContext.save()
    }

    public func delete(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try modelContext.delete(model: FoundRecordEntityModel.self, where: #Predicate { ids.contains($0.id) })
        try modelContext.save()
    }

    public func deleteAll() async throws {
        try modelContext.delete(model: FoundRecordEntityModel.self)
        try modelContext.save()
    }

    private func models(named name: String) throws -> [FoundRecordEntityModel] {
        try modelContext.fetch(FetchDescriptor<FoundRecordEntityModel>(predicate: #Predicate { $0.symbolName == name }))
    }
}

/// 심볼 뱃지
public actor SwiftDataBadgeRepository: BadgeRepository, ModelActor {
    public nonisolated let modelExecutor: any ModelExecutor
    public nonisolated let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
    }

    public func all() async throws -> [SymbolBadge] {
        try modelContext.fetch(FetchDescriptor<SymbolBadgeEntityModel>()).map(ProgressMappers.toDomain)
    }

    public func badge(forSymbol name: String) async throws -> SymbolBadge? {
        try model(named: name).map(ProgressMappers.toDomain)
    }

    public func save(_ badge: SymbolBadge) async throws {
        if let existing = try model(named: badge.symbolName) {
            try ProgressMappers.apply(badge, to: existing)
        } else {
            modelContext.insert(try ProgressMappers.makeModel(badge))
        }
        try modelContext.save()
    }

    public func deleteAll() async throws {
        try modelContext.delete(model: SymbolBadgeEntityModel.self)
        try modelContext.save()
    }

    private func model(named name: String) throws -> SymbolBadgeEntityModel? {
        var descriptor = FetchDescriptor<SymbolBadgeEntityModel>(predicate: #Predicate { $0.symbolName == name })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

/// 업적
public actor SwiftDataAchievementRepository: AchievementRepository, ModelActor {
    public nonisolated let modelExecutor: any ModelExecutor
    public nonisolated let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
    }

    /// `AchievementID` 선언 순서로 돌려준다.
    public func all() async throws -> [Achievement] {
        let order = Dictionary(uniqueKeysWithValues: AchievementID.allCases.enumerated().map { ($1, $0) })
        return try modelContext.fetch(FetchDescriptor<AchievementEntityModel>())
            .compactMap(ProgressMappers.toDomain)
            .sorted { order[$0.id, default: .max] < order[$1.id, default: .max] }
    }

    public func save(_ achievements: [Achievement]) async throws {
        let existing = Dictionary(
            try modelContext.fetch(FetchDescriptor<AchievementEntityModel>()).map { ($0.achievementID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for achievement in achievements {
            if let model = existing[achievement.id.rawValue] {
                model.progress = achievement.progress
                model.unlockedAt = achievement.unlockedAt
            } else {
                modelContext.insert(AchievementEntityModel(achievementID: achievement.id.rawValue,
                                                           progress: achievement.progress,
                                                           unlockedAt: achievement.unlockedAt))
            }
        }
        try modelContext.save()
    }

    public func deleteAll() async throws {
        try modelContext.delete(model: AchievementEntityModel.self)
        try modelContext.save()
    }
}

/// 누적 통계(한 행)
public actor SwiftDataUserStatsRepository: UserStatsRepository, ModelActor {
    public nonisolated let modelExecutor: any ModelExecutor
    public nonisolated let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
    }

    public func load() async throws -> UserStats {
        try currentModel().map(ProgressMappers.toDomain) ?? .initial
    }

    public func save(_ stats: UserStats) async throws {
        if let model = try currentModel() {
            model.totalSelections = stats.totalSelections
            model.streakDays = stats.streakDays
            model.lastActiveDay = stats.lastActiveDay
        } else {
            modelContext.insert(UserStatsEntityModel(totalSelections: stats.totalSelections,
                                                     streakDays: stats.streakDays,
                                                     lastActiveDay: stats.lastActiveDay))
        }
        try modelContext.save()
    }

    public func reset() async throws {
        try modelContext.delete(model: UserStatsEntityModel.self)
        try modelContext.save()
    }

    private func currentModel() throws -> UserStatsEntityModel? {
        var descriptor = FetchDescriptor<UserStatsEntityModel>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
