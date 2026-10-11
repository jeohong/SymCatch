//
//  VariantGrouper.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 같은 family(채움·테두리 변형)를 한 항목으로 묶고, 점수가 가장 높은 변형을 대표로 고른다.
/// Top N이 같은 모양으로 채워지는 것을 막기 위한 규칙.
public enum VariantGrouper {
    public struct Group: Sendable, Hashable {
        public let representative: ScoredSymbol
        /// 대표를 뺀 나머지 변형 이름(점수 내림차순)
        public let variants: [String]
    }

    /// - Returns: 대표 점수 내림차순으로 정렬한 상위 `limit`개 묶음.
    ///   점수가 같으면 이름 오름차순으로 순서를 고정한다.
    public static func group(_ candidates: [ScoredSymbol], limit: Int) -> [Group] {
        guard limit > 0 else { return [] }

        let byFamily = Dictionary(grouping: candidates, by: \.family)
        let groups = byFamily.values.map { members -> Group in
            let sorted = members.sorted(by: isRankedHigher)
            return Group(representative: sorted[0], variants: sorted.dropFirst().map(\.name))
        }
        return Array(groups.sorted { isRankedHigher($0.representative, $1.representative) }.prefix(limit))
    }

    private static func isRankedHigher(_ lhs: ScoredSymbol, _ rhs: ScoredSymbol) -> Bool {
        lhs.score != rhs.score ? lhs.score > rhs.score : lhs.name < rhs.name
    }
}

public extension VariantGrouper {
    /// 심볼 이름에서 `fill` 구성요소를 빼서 family 키를 만든다.
    /// 예: `heart.fill` → `heart`, `heart.circle.fill` → `heart.circle`, `square.fill.on.square` → `square.on.square`
    static func family(of name: String) -> String {
        let parts = name.split(separator: ".").filter { $0 != "fill" }
        return parts.isEmpty ? name : parts.joined(separator: ".")
    }
}
