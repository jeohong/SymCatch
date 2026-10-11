//
//  VariantGrouper.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 같은 family(채움·테두리 변형)를 한 항목으로 묶는다. Top N이 같은 모양으로 채워지는 것을 막기 위한 규칙.
///
/// - 묶음의 점수 = 변형 중 가장 높은 점수
/// - 대표 = **채우지 않은 기본 모양**(`fill`이 가장 적은 이름). 손그림으로는 속을 칠했는지 구분할 수 없고,
///   윤곽선 비교에서는 `heart`와 `heart.fill`의 점수가 거의 같아 우연히 `.fill`이 대표가 되기 때문이다.
///   `fill` 수가 같으면 점수가 높은 쪽. 나머지 변형은 상세 화면의 변형 칩으로 고른다(기획서 2.2).
public enum VariantGrouper {
    public struct Group: Sendable, Hashable {
        public let representative: ScoredSymbol
        /// 대표를 뺀 나머지 변형 이름(점수 내림차순)
        public let variants: [String]
        /// 묶음 점수(변형 중 최고점)
        public let score: Double
    }

    /// - Returns: 묶음 점수 내림차순으로 정렬한 상위 `limit`개. 점수가 같으면 대표 이름 오름차순.
    public static func group(_ candidates: [ScoredSymbol], limit: Int) -> [Group] {
        guard limit > 0 else { return [] }

        let byFamily = Dictionary(grouping: candidates, by: \.family)
        let groups = byFamily.values.map { members -> Group in
            let representative = members.min { lhs, rhs in
                let (left, right) = (fillCount(lhs.name), fillCount(rhs.name))
                return left != right ? left < right : isRankedHigher(lhs, rhs)
            }!
            let others = members.filter { $0.name != representative.name }.sorted(by: isRankedHigher)
            return Group(representative: representative, variants: others.map(\.name), score: members.map(\.score).max()!)
        }
        return Array(groups.sorted { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.representative.name < rhs.representative.name
        }.prefix(limit))
    }

    private static func isRankedHigher(_ lhs: ScoredSymbol, _ rhs: ScoredSymbol) -> Bool {
        lhs.score != rhs.score ? lhs.score > rhs.score : lhs.name < rhs.name
    }

    private static func fillCount(_ name: String) -> Int {
        name.split(separator: ".").filter { $0 == "fill" }.count
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
