//
//  SymbolTextSearchTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation
import Testing
@testable import Domain

struct SymbolTextSearchTests {
    private let symbols = [
        meta("heart", categories: ["health"]), meta("heart.fill", categories: ["health"]),
        meta("heart.circle", categories: ["health"]), meta("heart.circle.fill", categories: ["health"]),
        meta("suit.heart", categories: ["gaming"]), meta("bolt.heart", categories: ["health"]),
        meta("hearts.two"), meta("star", categories: ["shapes"]),
        SymbolMeta(name: "cross.case", family: "cross.case", categories: ["health"], keywords: ["first aid", "Heart care"], minOS: "13.0"),
    ]

    @Test func 검색어는_앞뒤_공백을_빼고_소문자로() {
        #expect(SymbolTextSearch.normalize("  HeArT ") == "heart")
        #expect(SymbolTextSearch.normalize("   ") == nil)
    }

    @Test(arguments: [("heart", SymbolTextSearch.Rank.exact), ("heart.circle", .prefix), ("suit.heart", .componentPrefix),
                      ("hearts.two", .prefix), ("cross.case", .keyword)])
    func 순위(name: String, expected: SymbolTextSearch.Rank) {
        let symbol = symbols.first { $0.name == name }!
        #expect(SymbolTextSearch.rank(symbol, query: "heart") == expected)
    }

    @Test func 포함만_되면_contains() {
        #expect(SymbolTextSearch.rank(meta("sweetheart.symbol"), query: "heart") == .contains)
        #expect(SymbolTextSearch.rank(meta("star"), query: "heart") == nil)
    }

    @Test func 변형은_대표_한_칸으로_묶고_순위_길이_이름순() {
        let result = SymbolTextSearch.search(symbols, query: "Heart")
        #expect(result.map(\.symbol.name) == ["heart", "hearts.two", "heart.circle", "bolt.heart", "suit.heart", "cross.case"])
        #expect(result.first { $0.symbol.name == "heart" }?.variantCount == 2)
    }

    @Test func 변형_이름만_맞아도_대표로_보여_준다() {
        #expect(SymbolTextSearch.search(symbols, query: "circle.fill").map(\.symbol.name) == ["heart.circle"])
    }

    @Test func 빈_검색어면_결과가_없다() {
        #expect(SymbolTextSearch.search(symbols, query: " ").isEmpty)
    }
}

struct BrowseSymbolsUseCaseTests {
    private let catalog = ListCatalog(
        symbols: [meta("heart", categories: ["health"]), meta("heart.fill", categories: ["health"]),
                  meta("pills", categories: ["health"]), meta("suit.heart", categories: ["gaming"]), meta("leaf")],
        categoryList: [SymbolCategory(key: "health", label: "Health", icon: "heart"), SymbolCategory(key: "gaming", label: "Gaming", icon: "gamecontroller"),
                       SymbolCategory(key: "math", label: "Math", icon: "x.squareroot")]
    )

    @Test func 카테고리는_대표_수와_함께_빈_카테고리는_뺀다() async throws {
        let categories = try await DefaultBrowseSymbolsUseCase(catalog: catalog).categories()
        #expect(categories.map(\.category.key) == ["health", "gaming"])
        #expect(categories.map(\.count) == [2, 1])
    }

    @Test func 검색어가_없으면_카테고리_둘러보기() async throws {
        let useCase = DefaultBrowseSymbolsUseCase(catalog: catalog)
        #expect(try await useCase.execute(query: "", category: "health").map(\.symbol.name) == ["heart", "pills"])
        #expect(try await useCase.execute(query: "", category: nil).isEmpty)
    }

    @Test func 카테고리를_고르면_그_안에서만_찾는다() async throws {
        let useCase = DefaultBrowseSymbolsUseCase(catalog: catalog)
        #expect(try await useCase.execute(query: "heart", category: nil).map(\.symbol.name) == ["heart", "suit.heart"])
        #expect(try await useCase.execute(query: "heart", category: "gaming").map(\.symbol.name) == ["suit.heart"])
    }
}
