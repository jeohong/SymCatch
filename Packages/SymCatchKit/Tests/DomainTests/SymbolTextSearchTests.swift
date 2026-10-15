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

struct KoreanSymbolSearchTests {
    private let symbols = [
        meta("heart"), meta("heart.fill"), meta("heart.circle"), meta("suit.heart"),
        meta("car", categories: ["transportation"]), meta("car.side", categories: ["transportation"]),
        meta("bicycle", categories: ["transportation"]),
        SymbolMeta(name: "cross.case", family: "cross.case", categories: ["health"], keywords: ["first aid", "heart care"], minOS: "13.0"),
        meta("leaf", categories: ["nature"]),
    ]
    private let dictionary = KoreanSymbolDictionary(
        words: ["heart": ["하트", "심장"], "car": ["자동차", "차"], "suit": ["카드 무늬"], "circle": ["원", "동그라미"], "case": ["케이스"]],
        categories: ["nature": ["자연"], "transportation": ["교통"]]
    )

    @Test func 한글이_있으면_한국어_검색() {
        #expect(KoreanSymbolDictionary.containsHangul("하트"))
        #expect(KoreanSymbolDictionary.containsHangul("ㅎㅌ"))
        #expect(!KoreanSymbolDictionary.containsHangul("heart"))
    }

    @Test func 뜻이_같은_단어가_이름_앞에_있을수록_위() {
        let result = SymbolTextSearch.search(symbols, query: "하트", dictionary: dictionary).map(\.symbol.name)
        // 이름 전체 → 맨 앞 → 중간 → 키워드만
        #expect(result == ["heart", "heart.circle", "suit.heart", "cross.case"])
    }

    @Test func 뜻이_검색어로_시작만_해도_찾는다() {
        // "자동"은 "자동차"의 앞부분
        #expect(SymbolTextSearch.search(symbols, query: "자동", dictionary: dictionary).map(\.symbol.name) == ["car", "car.side"])
    }

    @Test func 카테고리_이름만_맞으면_맨_뒤() {
        let result = SymbolTextSearch.search(symbols, query: "교통", dictionary: dictionary).map(\.symbol.name)
        #expect(Set(result) == ["car", "car.side", "bicycle"])
        #expect(SymbolTextSearch.search(symbols, query: "자연", dictionary: dictionary).map(\.symbol.name) == ["leaf"])
    }

    @Test func 사전이_없으면_한국어는_결과가_없고_영어는_그대로() {
        #expect(SymbolTextSearch.search(symbols, query: "하트").isEmpty)
        #expect(SymbolTextSearch.search(symbols, query: "heart", dictionary: dictionary).first?.symbol.name == "heart")
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
