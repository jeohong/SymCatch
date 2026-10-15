//
//  ProgressEntityModels.swift
//  Storage
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import SwiftData

/// 저장 형식 1판. 필드를 바꿀 때는 `ProgressSchemaV2`를 만들고 `ProgressMigrationPlan`에 단계를 추가한다.
/// @Model은 Storage 밖으로 나가지 않는다. 밖으로는 `ProgressMappers`로 Domain 값으로 바꿔 내보낸다.
public enum ProgressSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [FoundRecordEntityModel.self, SymbolBadgeEntityModel.self, AchievementEntityModel.self, UserStatsEntityModel.self]
    }

    /// 최근 찾은 심볼 한 건
    @Model
    public final class FoundRecordEntityModel {
        @Attribute(.unique) public var id: UUID
        /// 심볼당 1건은 저장소가 지킨다(iOS 17에는 `#Unique`가 없어 저장 전에 같은 이름을 찾아 지운다).
        public var symbolName: String
        /// `Sketch`를 JSON으로 저장한다(획 좌표).
        public var sketchData: Data
        public var similarity: Int
        public var foundAt: Date

        init(id: UUID, symbolName: String, sketchData: Data, similarity: Int, foundAt: Date) {
            self.id = id
            self.symbolName = symbolName
            self.sketchData = sketchData
            self.similarity = similarity
            self.foundAt = foundAt
        }
    }

    /// 심볼 뱃지. 심볼 이름이 곧 식별자.
    @Model
    public final class SymbolBadgeEntityModel {
        @Attribute(.unique) public var symbolName: String
        /// `BadgeTier.rawValue`
        public var tierRawValue: Int
        public var bestSimilarity: Int
        public var bestSketchData: Data
        public var earnedAt: Date
        public var upgradedAt: Date?

        init(symbolName: String, tierRawValue: Int, bestSimilarity: Int, bestSketchData: Data, earnedAt: Date, upgradedAt: Date?) {
            self.symbolName = symbolName
            self.tierRawValue = tierRawValue
            self.bestSimilarity = bestSimilarity
            self.bestSketchData = bestSketchData
            self.earnedAt = earnedAt
            self.upgradedAt = upgradedAt
        }
    }

    /// 업적 진행 상황
    @Model
    public final class AchievementEntityModel {
        /// `AchievementID.rawValue`
        @Attribute(.unique) public var achievementID: String
        public var progress: Int
        public var unlockedAt: Date?

        init(achievementID: String, progress: Int, unlockedAt: Date?) {
            self.achievementID = achievementID
            self.progress = progress
            self.unlockedAt = unlockedAt
        }
    }

    /// 누적 통계. 한 행만 둔다.
    @Model
    public final class UserStatsEntityModel {
        public var totalSelections: Int
        public var streakDays: Int
        public var lastActiveDay: Date?

        init(totalSelections: Int, streakDays: Int, lastActiveDay: Date?) {
            self.totalSelections = totalSelections
            self.streakDays = streakDays
            self.lastActiveDay = lastActiveDay
        }
    }
}

public typealias FoundRecordEntityModel = ProgressSchemaV1.FoundRecordEntityModel
public typealias SymbolBadgeEntityModel = ProgressSchemaV1.SymbolBadgeEntityModel
public typealias AchievementEntityModel = ProgressSchemaV1.AchievementEntityModel
public typealias UserStatsEntityModel = ProgressSchemaV1.UserStatsEntityModel

/// 저장 형식이 바뀔 때의 이전 단계. 지금은 1판뿐이다.
public enum ProgressMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [ProgressSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
