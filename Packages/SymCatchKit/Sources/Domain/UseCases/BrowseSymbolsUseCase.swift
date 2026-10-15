//
//  BrowseSymbolsUseCase.swift
//  Domain
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation

/// 둘러보기 카테고리 한 칸: 카테고리와 대표 심볼 수
public struct SymbolCategorySummary: Sendable, Hashable, Identifiable {
    public let category: SymbolCategory
    public let count: Int

    public var id: String { category.key }

    public init(category: SymbolCategory, count: Int) {
        self.category = category
        self.count = count
    }
}

/// 심볼 검색 탭(S9): 글자로 찾기와 카테고리 둘러보기. 기록·뱃지에는 영향이 없다.
public protocol BrowseSymbolsUseCase: Sendable {
    /// 둘러보기 카테고리(카탈로그 순서, 심볼이 없는 카테고리는 뺀다)
    func categories() async throws -> [SymbolCategorySummary]
    /// 검색어가 있으면 찾기(카테고리를 고르면 그 안에서만), 없으면 그 카테고리 둘러보기. 둘 다 없으면 빈 배열.
    func execute(query: String, category: String?) async throws -> [SymbolBrowseItem]
}

/// 한국어 검색 사전을 읽는 저장소(기기 안 파일)
public protocol KoreanDictionaryRepository: Sendable {
    func dictionary() async throws -> KoreanSymbolDictionary
}

public struct DefaultBrowseSymbolsUseCase: BrowseSymbolsUseCase {
    private let catalog: any SymbolCatalogRepository
    private let dictionary: (any KoreanDictionaryRepository)?

    public init(catalog: any SymbolCatalogRepository, dictionary: (any KoreanDictionaryRepository)? = nil) {
        self.catalog = catalog
        self.dictionary = dictionary
    }

    public func categories() async throws -> [SymbolCategorySummary] {
        let representatives = VariantGrouper.representatives(of: try await catalog.allSymbols())
        return try await catalog.categories().compactMap { category in
            let count = representatives.filter { $0.categories.contains(category.key) }.count
            return count > 0 ? SymbolCategorySummary(category: category, count: count) : nil
        }
    }

    public func execute(query: String, category: String?) async throws -> [SymbolBrowseItem] {
        let all = try await catalog.allSymbols()
        // 카테고리를 고르면 그 카테고리에 속한 family만(대표 기준) 남긴다.
        let symbols: [SymbolMeta]
        if let category {
            let families = Set(VariantGrouper.representatives(of: all).filter { $0.categories.contains(category) }.map(\.family))
            symbols = all.filter { families.contains($0.family) }
        } else {
            symbols = all
        }
        if SymbolTextSearch.normalize(query) != nil {
            // 사전을 못 읽어도 영어 검색은 된다.
            let korean = (try? await dictionary?.dictionary()) ?? .empty
            return SymbolTextSearch.search(symbols, query: query, dictionary: korean)
        }
        guard let category else { return [] }
        return SymbolTextSearch.browse(symbols, category: category)
    }
}
