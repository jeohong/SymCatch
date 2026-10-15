//
//  InMemoryRepositories.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
@testable import Domain

actor InMemoryFoundRecords: FoundRecordRepository {
    private var records: [UUID: FoundRecord] = [:]

    func all() async throws -> [FoundRecord] { records.values.sorted { $0.foundAt > $1.foundAt } }
    func record(forSymbol name: String) async throws -> FoundRecord? { records.values.first { $0.symbolName == name } }
    func save(_ record: FoundRecord) async throws { records[record.id] = record }
    func delete(ids: [UUID]) async throws { ids.forEach { records[$0] = nil } }
    func deleteAll() async throws { records = [:] }
}

actor InMemoryBadges: BadgeRepository {
    private var badges: [String: SymbolBadge] = [:]

    func all() async throws -> [SymbolBadge] { Array(badges.values) }
    func badge(forSymbol name: String) async throws -> SymbolBadge? { badges[name] }
    func save(_ badge: SymbolBadge) async throws { badges[badge.symbolName] = badge }
    func deleteAll() async throws { badges = [:] }
}

actor InMemoryAchievements: AchievementRepository {
    private var items: [Achievement] = []

    func all() async throws -> [Achievement] { items }
    func save(_ achievements: [Achievement]) async throws { items = achievements }
    func deleteAll() async throws { items = [] }
}

actor InMemoryStats: UserStatsRepository {
    private var stats = UserStats.initial

    func load() async throws -> UserStats { stats }
    func save(_ stats: UserStats) async throws { self.stats = stats }
    func reset() async throws { stats = .initial }
}

enum Fixtures {
    static let sketch = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])
    static let otherSketch = Sketch(strokes: [[SketchPoint(x: 0.2, y: 0.8), SketchPoint(x: 0.8, y: 0.2)]])
    /// 획 2개("한 붓에"가 아닌 그림)
    static let twoStrokes = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)],
                                             [SketchPoint(x: 0.9, y: 0.1), SketchPoint(x: 0.1, y: 0.9)]])

    /// 2026-10-11 12:00 (UTC) 기준으로 `days`일 뒤
    static func date(days: Int = 0, hours: Int = 0) -> Date {
        Date(timeIntervalSince1970: 1_791_720_000 + Double(days) * 86_400 + Double(hours) * 3_600)
    }

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}

/// 주어진 목록을 그대로 돌려주는 카탈로그
struct ListCatalog: SymbolCatalogRepository {
    let symbols: [SymbolMeta]
    var categoryList: [SymbolCategory] = []

    func allSymbols() async throws -> [SymbolMeta] { symbols }
    func categories() async throws -> [SymbolCategory] { categoryList }
    func symbol(named name: String) async throws -> SymbolMeta? { symbols.first { $0.name == name } }
    func symbols(inFamily family: String) async throws -> [SymbolMeta] { symbols.filter { $0.family == family } }
}

/// 이름으로 family를 정한 심볼 메타
func meta(_ name: String, minOS: String = "13.0", categories: [String] = []) -> SymbolMeta {
    SymbolMeta(name: name, family: VariantGrouper.family(of: name), categories: categories, keywords: [], minOS: minOS)
}
