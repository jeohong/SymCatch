//
//  ProgressMappers.swift
//  Storage
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 저장 중 값이 깨졌을 때(알 수 없는 등급·업적, 읽을 수 없는 그림)
public enum ProgressStorageError: Error, Equatable {
    case corrupted(String)
}

/// @Model ↔ Domain 값 변환
enum ProgressMappers {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encode(_ sketch: Sketch) throws -> Data {
        try encoder.encode(sketch)
    }

    static func decodeSketch(_ data: Data) throws -> Sketch {
        do {
            return try decoder.decode(Sketch.self, from: data)
        } catch {
            throw ProgressStorageError.corrupted("sketch")
        }
    }

    // MARK: 최근 기록

    static func toDomain(_ model: FoundRecordEntityModel) throws -> FoundRecord {
        FoundRecord(id: model.id, symbolName: model.symbolName, sketch: try decodeSketch(model.sketchData),
                    similarity: model.similarity, foundAt: model.foundAt)
    }

    static func makeModel(_ record: FoundRecord) throws -> FoundRecordEntityModel {
        FoundRecordEntityModel(id: record.id, symbolName: record.symbolName, sketchData: try encode(record.sketch),
                               similarity: record.similarity, foundAt: record.foundAt)
    }

    static func apply(_ record: FoundRecord, to model: FoundRecordEntityModel) throws {
        model.symbolName = record.symbolName
        model.sketchData = try encode(record.sketch)
        model.similarity = record.similarity
        model.foundAt = record.foundAt
    }

    // MARK: 뱃지

    static func toDomain(_ model: SymbolBadgeEntityModel) throws -> SymbolBadge {
        guard let tier = BadgeTier(rawValue: model.tierRawValue) else {
            throw ProgressStorageError.corrupted("tier \(model.tierRawValue)")
        }
        return SymbolBadge(symbolName: model.symbolName, tier: tier, bestSimilarity: model.bestSimilarity,
                           bestSketch: try decodeSketch(model.bestSketchData), earnedAt: model.earnedAt,
                           upgradedAt: model.upgradedAt)
    }

    static func makeModel(_ badge: SymbolBadge) throws -> SymbolBadgeEntityModel {
        SymbolBadgeEntityModel(symbolName: badge.symbolName, tierRawValue: badge.tier.rawValue,
                               bestSimilarity: badge.bestSimilarity, bestSketchData: try encode(badge.bestSketch),
                               earnedAt: badge.earnedAt, upgradedAt: badge.upgradedAt)
    }

    static func apply(_ badge: SymbolBadge, to model: SymbolBadgeEntityModel) throws {
        model.tierRawValue = badge.tier.rawValue
        model.bestSimilarity = badge.bestSimilarity
        model.bestSketchData = try encode(badge.bestSketch)
        model.earnedAt = badge.earnedAt
        model.upgradedAt = badge.upgradedAt
    }

    // MARK: 업적

    /// 앞으로 없어진 업적이 저장돼 있을 수 있으므로 모르는 id는 건너뛴다(nil).
    static func toDomain(_ model: AchievementEntityModel) -> Achievement? {
        AchievementID(rawValue: model.achievementID).map {
            Achievement(id: $0, progress: model.progress, unlockedAt: model.unlockedAt)
        }
    }

    // MARK: 통계

    static func toDomain(_ model: UserStatsEntityModel) -> UserStats {
        UserStats(totalSelections: model.totalSelections, streakDays: model.streakDays, lastActiveDay: model.lastActiveDay)
    }
}
