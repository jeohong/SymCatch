//
//  ProgressRepositories.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 최근 찾은 심볼
public protocol FoundRecordRepository: Sendable {
    /// 최신순
    func all() async throws -> [FoundRecord]
    func record(forSymbol name: String) async throws -> FoundRecord?
    /// 같은 id가 있으면 덮어쓴다.
    func save(_ record: FoundRecord) async throws
    func delete(ids: [UUID]) async throws
    func deleteAll() async throws
}

/// 심볼 뱃지
public protocol BadgeRepository: Sendable {
    func all() async throws -> [SymbolBadge]
    func badge(forSymbol name: String) async throws -> SymbolBadge?
    /// 같은 심볼이 있으면 덮어쓴다.
    func save(_ badge: SymbolBadge) async throws
    func deleteAll() async throws
}

/// 업적
public protocol AchievementRepository: Sendable {
    func all() async throws -> [Achievement]
    func save(_ achievements: [Achievement]) async throws
    func deleteAll() async throws
}

/// 누적 통계
public protocol UserStatsRepository: Sendable {
    func load() async throws -> UserStats
    func save(_ stats: UserStats) async throws
    func reset() async throws
}
