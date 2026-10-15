//
//  SymbolTextSearch.swift
//  Domain
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation

/// 심볼 검색 탭(S9) 결과 한 칸: family 대표(기본 모양)와 변형 수
public struct SymbolBrowseItem: Sendable, Hashable, Identifiable {
    public let symbol: SymbolMeta
    /// 대표를 포함한 같은 family 심볼 수
    public let variantCount: Int

    public var id: String { symbol.name }

    public init(symbol: SymbolMeta, variantCount: Int) {
        self.symbol = symbol
        self.variantCount = variantCount
    }
}

/// 글자로 심볼 찾기(기획서 6장 S9). 대소문자 무시, 같은 family는 한 칸.
public enum SymbolTextSearch {
    /// 일치 순위. 작을수록 위.
    public enum Rank: Int, Sendable, Comparable {
        /// 이름이 같음
        case exact
        /// 이름이 검색어로 시작
        case prefix
        /// 이름의 한 구성요소(점으로 나눈 단어)가 검색어로 시작. 예: "heart" → `suit.heart`
        case componentPrefix
        /// 이름 어딘가에 포함
        case contains
        /// 이름에는 없고 키워드에만 있음
        case keyword

        public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// 검색어를 비교용으로 다듬는다(앞뒤 공백 제거, 소문자). 비어 있으면 nil.
    public static func normalize(_ query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 심볼 하나의 순위. 맞지 않으면 nil. `query`는 `normalize`를 거친 값.
    public static func rank(_ symbol: SymbolMeta, query: String) -> Rank? {
        let name = symbol.name.lowercased()
        if name == query { return .exact }
        if name.hasPrefix(query) { return .prefix }
        if name.split(separator: ".").contains(where: { $0.hasPrefix(query) }) { return .componentPrefix }
        if name.contains(query) { return .contains }
        if symbol.keywords.contains(where: { $0.lowercased().contains(query) }) { return .keyword }
        return nil
    }

    /// 검색: family마다 변형 중 가장 좋은 순위로 묶어 대표 한 칸만 남긴다.
    /// 정렬 = 순위 → 대표 이름 길이(짧은 것 먼저) → 이름순.
    public static func search(_ symbols: [SymbolMeta], query: String) -> [SymbolBrowseItem] {
        guard let query = normalize(query) else { return [] }
        let families = Dictionary(grouping: symbols, by: \.family)
        let ranked: [(item: SymbolBrowseItem, rank: Rank)] = families.values.compactMap { members in
            guard let best = members.compactMap({ rank($0, query: query) }).min(),
                  let representative = VariantGrouper.representatives(of: members).first else { return nil }
            return (SymbolBrowseItem(symbol: representative, variantCount: members.count), best)
        }
        return ranked.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            let (left, right) = (lhs.item.symbol.name, rhs.item.symbol.name)
            return left.count != right.count ? left.count < right.count : left < right
        }.map(\.item)
    }

    /// 카테고리 둘러보기: 그 카테고리의 대표 심볼을 이름순으로
    public static func browse(_ symbols: [SymbolMeta], category: String) -> [SymbolBrowseItem] {
        let families = Dictionary(grouping: symbols, by: \.family)
        return VariantGrouper.representatives(of: symbols)
            .filter { $0.categories.contains(category) }
            .sorted { $0.name < $1.name }
            .map { SymbolBrowseItem(symbol: $0, variantCount: families[$0.family]?.count ?? 1) }
    }
}
