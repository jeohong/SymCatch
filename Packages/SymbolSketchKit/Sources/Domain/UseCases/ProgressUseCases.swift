//
//  ProgressUseCases.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

// MARK: - 최근 찾은 심볼(S5)

public protocol FetchRecentRecordsUseCase: Sendable {
    /// 최신순. `limit`이 있으면 앞에서부터 그만큼(홈 상단 최근 5개).
    func execute(limit: Int?) async throws -> [FoundRecord]
}

public protocol DeleteRecordsUseCase: Sendable {
    func execute(ids: [UUID]) async throws
}

public protocol ClearHistoryUseCase: Sendable {
    /// 기록만 지운다. 뱃지는 그대로 남는다(디자인 S5 알림 문구).
    func execute() async throws
}

public struct DefaultFetchRecentRecordsUseCase: FetchRecentRecordsUseCase {
    private let records: any FoundRecordRepository
    public init(records: any FoundRecordRepository) { self.records = records }

    public func execute(limit: Int?) async throws -> [FoundRecord] {
        let all = try await records.all()
        return limit.map { Array(all.prefix($0)) } ?? all
    }
}

public struct DefaultDeleteRecordsUseCase: DeleteRecordsUseCase {
    private let records: any FoundRecordRepository
    public init(records: any FoundRecordRepository) { self.records = records }

    public func execute(ids: [UUID]) async throws {
        try await records.delete(ids: ids)
    }
}

public struct DefaultClearHistoryUseCase: ClearHistoryUseCase {
    private let records: any FoundRecordRepository
    public init(records: any FoundRecordRepository) { self.records = records }

    public func execute() async throws {
        try await records.deleteAll()
    }
}

// MARK: - 콜렉션(S6·S7)

/// 카테고리 하나와 그 안의 심볼 이름들(콜렉션 격자 한 줄)
public struct CategorySymbols: Sendable, Hashable {
    public let category: SymbolCategory
    public let names: [String]

    public init(category: SymbolCategory, names: [String]) {
        self.category = category
        self.names = names
    }
}

/// 콜렉션 화면에 필요한 값
public struct CollectionSummary: Sendable, Hashable {
    /// 얻은 심볼 뱃지(최근 획득순)
    public let badges: [SymbolBadge]
    public let achievements: [Achievement]
    /// 달성률 분모: 뱃지를 받을 수 있는 전체 심볼 수(계획서 7장 결정 5)
    public let totalSymbolCount: Int
    /// 카테고리별 심볼(격자·실루엣용). 카테고리 순서는 카탈로그 순서.
    public let categories: [CategorySymbols]

    public init(badges: [SymbolBadge], achievements: [Achievement], totalSymbolCount: Int, categories: [CategorySymbols]) {
        self.badges = badges
        self.achievements = achievements
        self.totalSymbolCount = totalSymbolCount
        self.categories = categories
    }

    public func count(of tier: BadgeTier) -> Int {
        badges.filter { $0.tier == tier }.count
    }
}

public protocol FetchCollectionUseCase: Sendable {
    func execute() async throws -> CollectionSummary
}

public struct DefaultFetchCollectionUseCase: FetchCollectionUseCase {
    private let badges: any BadgeRepository
    private let achievements: any AchievementRepository
    private let catalog: any SymbolCatalogRepository

    public init(badges: any BadgeRepository, achievements: any AchievementRepository, catalog: any SymbolCatalogRepository) {
        self.badges = badges
        self.achievements = achievements
        self.catalog = catalog
    }

    public func execute() async throws -> CollectionSummary {
        let symbols = try await catalog.allSymbols()
        let categories = try await catalog.categories()
        // 같은 family는 대표(기본 모양) 하나만 격자에 둔다. 검색 결과 묶기와 같은 규칙.
        let representatives = Dictionary(grouping: symbols, by: \.family).values.compactMap { members in
            members.min { fillCount($0.name) != fillCount($1.name) ? fillCount($0.name) < fillCount($1.name) : $0.name < $1.name }
        }
        let byCategory = categories.map { category in
            CategorySymbols(category: category, names: representatives.filter { $0.categories.contains(category.key) }.map(\.name).sorted())
        }.filter { !$0.names.isEmpty }

        let stored = try await achievements.all()
        let storedByID = Dictionary(stored.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return CollectionSummary(
            badges: try await badges.all().sorted { $0.earnedAt > $1.earnedAt },
            achievements: AchievementID.allCases.map { storedByID[$0] ?? Achievement(id: $0) },
            totalSymbolCount: representatives.count,
            categories: byCategory
        )
    }

    private func fillCount(_ name: String) -> Int {
        name.split(separator: ".").filter { $0 == "fill" }.count
    }
}
