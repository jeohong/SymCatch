//
//  SymbolAvailabilityTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Domain

private struct ListCatalog: SymbolCatalogRepository {
    let symbols: [SymbolMeta]
    var categoryList: [SymbolCategory] = []

    func allSymbols() async throws -> [SymbolMeta] { symbols }
    func categories() async throws -> [SymbolCategory] { categoryList }
    func symbol(named name: String) async throws -> SymbolMeta? { symbols.first { $0.name == name } }
    func symbols(inFamily family: String) async throws -> [SymbolMeta] { symbols.filter { $0.family == family } }
}

private func meta(_ name: String, minOS: String = "13.0", categories: [String] = []) -> SymbolMeta {
    SymbolMeta(name: name, family: VariantGrouper.family(of: name), categories: categories, keywords: [], minOS: minOS)
}

struct OSVersionTests {
    @Test func 문자열을_읽고_비교한다() {
        #expect(OSVersion("17.0") == OSVersion(major: 17))
        #expect(OSVersion("26") == OSVersion(major: 26))
        #expect(OSVersion("18.4")! > OSVersion("18.0")!)
        #expect(OSVersion("26.0")! > OSVersion("18.4")!)
        #expect(OSVersion("") == nil)
        #expect(OSVersion("abc") == nil)
    }

    @Test func 기기_버전_이하에서_나온_심볼만_쓸_수_있다() {
        let os = OSVersion(major: 26)
        #expect(meta("a", minOS: "26.0").isAvailable(on: os))
        #expect(!meta("b", minOS: "27.0").isAvailable(on: os))
        #expect(meta("c", minOS: "?").isAvailable(on: os))
    }
}

struct AvailableSymbolCatalogTests {
    private let base = ListCatalog(symbols: [meta("heart"), meta("heart.fill"), meta("heart.new", minOS: "27.0"), meta("bolt.new", minOS: "27.0")])

    @Test func iOS26에서는_27_심볼이_보이지_않는다() async throws {
        let catalog = AvailableSymbolCatalog(base: base, os: OSVersion(major: 26))
        #expect(try await catalog.allSymbols().map(\.name) == ["heart", "heart.fill"])
        #expect(try await catalog.symbol(named: "bolt.new") == nil)
        #expect(try await catalog.symbols(inFamily: "heart").map(\.name) == ["heart", "heart.fill"])
    }

    @Test func iOS27에서는_모두_보인다() async throws {
        let catalog = AvailableSymbolCatalog(base: base, os: OSVersion(major: 27))
        #expect(try await catalog.allSymbols().count == 4)
    }
}

struct FetchCollectionUseCaseTests {
    private let categories = [SymbolCategory(key: "health", label: "Health", icon: "heart"), SymbolCategory(key: "nature", label: "Nature", icon: "leaf")]

    private func useCase(_ symbols: [SymbolMeta], badges: InMemoryBadges = InMemoryBadges(), achievements: InMemoryAchievements = InMemoryAchievements()) -> DefaultFetchCollectionUseCase {
        DefaultFetchCollectionUseCase(badges: badges, achievements: achievements, catalog: ListCatalog(symbols: symbols, categoryList: categories))
    }

    @Test func 변형은_기본_모양_하나로_세고_분모는_대표_수() async throws {
        let summary = try await useCase([
            meta("heart", categories: ["health"]), meta("heart.fill", categories: ["health"]),
            meta("leaf", categories: ["nature", "health"]), meta("target"),
        ]).execute()

        #expect(summary.totalSymbolCount == 3)
        #expect(summary.categories.map(\.category.key) == ["health", "nature", "uncategorized"])
        #expect(summary.categories[0].names == ["heart", "leaf"])
        #expect(summary.categories[2].names == ["target"])
    }

    @Test func 뱃지는_최근_획득순이고_업적은_세_개_모두() async throws {
        let badges = InMemoryBadges()
        try await badges.save(SymbolBadge(symbolName: "heart", tier: .gold, bestSimilarity: 99, bestSketch: Fixtures.sketch, earnedAt: Fixtures.date()))
        try await badges.save(SymbolBadge(symbolName: "leaf", tier: .bronze, bestSimilarity: 91, bestSketch: Fixtures.sketch, earnedAt: Fixtures.date(days: 1)))

        let summary = try await useCase([meta("heart"), meta("leaf")], badges: badges).execute()

        #expect(summary.badges.map(\.symbolName) == ["leaf", "heart"])
        #expect(summary.count(of: .gold) == 1 && summary.count(of: .silver) == 0)
        #expect(summary.achievements.map(\.id) == AchievementID.allCases)
    }

    @Test func 예전_OS에서는_분모에서_새_심볼이_빠진다() async throws {
        let symbols = [meta("heart"), meta("bolt.new", minOS: "27.0")]
        let catalog = AvailableSymbolCatalog(base: ListCatalog(symbols: symbols, categoryList: categories), os: OSVersion(major: 26))
        let summary = try await DefaultFetchCollectionUseCase(badges: InMemoryBadges(), achievements: InMemoryAchievements(), catalog: catalog).execute()
        #expect(summary.totalSymbolCount == 1)
    }
}
