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

// MARK: - 보유 뱃지(결과 행·상세의 "보유 중" 표시)

public protocol FetchBadgesUseCase: Sendable {
    /// 심볼 이름 → 뱃지
    func execute() async throws -> [String: SymbolBadge]
}

public struct DefaultFetchBadgesUseCase: FetchBadgesUseCase {
    private let badges: any BadgeRepository
    public init(badges: any BadgeRepository) { self.badges = badges }

    public func execute() async throws -> [String: SymbolBadge] {
        Dictionary(try await badges.all().map { ($0.symbolName, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

// MARK: - 기록 초기화(S8)

public protocol ResetProgressUseCase: Sendable {
    /// 최근 찾은 심볼, 뱃지, 업적, 통계를 모두 지운다. 되돌릴 수 없다.
    func execute() async throws
}

public struct DefaultResetProgressUseCase: ResetProgressUseCase {
    private let records: any FoundRecordRepository
    private let badges: any BadgeRepository
    private let achievements: any AchievementRepository
    private let stats: any UserStatsRepository

    public init(records: any FoundRecordRepository, badges: any BadgeRepository,
                achievements: any AchievementRepository, stats: any UserStatsRepository) {
        self.records = records
        self.badges = badges
        self.achievements = achievements
        self.stats = stats
    }

    public func execute() async throws {
        try await records.deleteAll()
        try await badges.deleteAll()
        try await achievements.deleteAll()
        try await stats.reset()
    }
}

// MARK: - 등급 맞추기(앱 시작 시)

public protocol ReconcileBadgeTiersUseCase: Sendable {
    /// 저장된 뱃지 등급을 최고 유사도에 맞춰 올린다. 바뀐 뱃지 수를 돌려준다.
    func execute(now: Date) async throws -> Int
}

public struct DefaultReconcileBadgeTiersUseCase: ReconcileBadgeTiersUseCase {
    private let badges: any BadgeRepository
    public init(badges: any BadgeRepository) { self.badges = badges }

    public func execute(now: Date) async throws -> Int {
        let updated = BadgeTierPolicy.reconciled(try await badges.all(), now: now)
        for badge in updated { try await badges.save(badge) }
        return updated.count
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

// MARK: - 업적 맞추기(앱 시작 시)

public protocol ReconcileAchievementsUseCase: Sendable {
    /// 지금 가진 뱃지·통계로 업적 진행을 다시 계산해 저장한다. 조건을 채운 업적은 조용히 달성 처리한다(축하 모달 없음).
    /// 업적이 늘어난 업데이트 뒤에 이미 받은 뱃지가 반영되도록 앱을 켤 때 부른다(기획서 3.2).
    func execute(now: Date) async throws
}

public struct DefaultReconcileAchievementsUseCase: ReconcileAchievementsUseCase {
    private let achievements: any AchievementRepository
    private let badges: any BadgeRepository
    private let stats: any UserStatsRepository
    private let catalog: any SymbolCatalogRepository

    public init(achievements: any AchievementRepository, badges: any BadgeRepository,
                stats: any UserStatsRepository, catalog: any SymbolCatalogRepository) {
        self.achievements = achievements
        self.badges = badges
        self.stats = stats
        self.catalog = catalog
    }

    public func execute(now: Date) async throws {
        let input = AchievementInput(
            stats: try await stats.load(),
            badges: try await badges.all(),
            categories: AchievementCategory.make(symbols: try await catalog.allSymbols(), categories: try await catalog.categories())
        )
        let evaluation = AchievementEvaluator.evaluate(current: try await achievements.all(), input: input, now: now)
        try await achievements.save(evaluation.all)
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
        // 같은 family는 대표(기본 모양) 하나만 격자에 둔다. 검색 결과 묶기·카테고리 업적과 같은 규칙.
        let representatives = VariantGrouper.representatives(of: symbols)
        var byCategory = categories.map { category in
            CategorySymbols(category: category, names: representatives.filter { $0.categories.contains(category.key) }.map(\.name).sorted())
        }.filter { !$0.names.isEmpty }
        // 카테고리가 없는 심볼도 분모에 들어가므로 격자 끝 "기타"에 모은다.
        let knownKeys = Set(categories.map(\.key))
        let uncategorized = representatives.filter { Set($0.categories).isDisjoint(with: knownKeys) }.map(\.name).sorted()
        if !uncategorized.isEmpty {
            byCategory.append(CategorySymbols(category: SymbolCategory.uncategorized, names: uncategorized))
        }

        let stored = try await achievements.all()
        let storedByID = Dictionary(stored.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // 전체 업적(일반 + 카테고리)에 목표값을 붙인다. 진행·달성은 저장된 값(앱 시작 때 맞춘다).
        let achievementCategories = AchievementCategory.make(symbols: symbols, categories: categories)
        let achievementList = AchievementEvaluator.catalog(categories: achievementCategories).map { id, goal in
            let saved = storedByID[id]
            return Achievement(id: id, progress: min(saved?.progress ?? 0, goal), unlockedAt: saved?.unlockedAt, goal: goal)
        }
        return CollectionSummary(
            badges: try await badges.all().sorted { $0.earnedAt > $1.earnedAt },
            achievements: achievementList,
            totalSymbolCount: representatives.count,
            categories: byCategory
        )
    }

}

extension SymbolCategory {
    /// 카테고리가 없는 심볼을 모으는 콜렉션 전용 묶음
    public static let uncategorized = SymbolCategory(key: "uncategorized", label: "Other", icon: "square.grid.2x2")
}
