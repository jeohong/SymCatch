//
//  HubnessCorrection.swift
//  Domain
//
//  Created by Hongjeongmin on 10/12/26.
//

import Foundation

/// "만능 닮은꼴" 보정(CSLS, cross-domain similarity local scaling).
///
/// 둥근 사각형·마름모 같은 심볼은 어떤 그림과 비교해도 점수가 높게 나와 정답을 밀어내고
/// 엉뚱한 뱃지를 만든다(2026-10-12 실기기 평가). 그래서 점수에서 "평소에 얼마나 닮는 편인지"를 뺀다.
///
///     보정 점수 = 코사인 − 세기 × (r(그림) + r(심볼)) / 2
///
/// 세기 1이 원래 CSLS(2×코사인 − r(그림) − r(심볼))와 순위가 같다. 1로 하면 `arrow.down`·`heart`처럼
/// 모양이 단순한 인기 심볼까지 깎여 순위가 나빠졌다(같은 날 평가). 그래서 세기를 조절할 수 있게 둔다.
///
/// - r(심볼): 인덱스를 만들 때 잰, 그 심볼과 가장 닮은 다른 심볼 k개의 평균 코사인(`ScoredSymbol.hubness`)
/// - r(그림): 이 그림과 가장 닮은 심볼 k개의 평균 코사인. 순위에는 영향이 없고, 그림마다 점수의 기준선을 맞춘다.
public enum HubnessCorrection {
    /// 이웃 수 k
    public static let neighborCount = 10

    /// 보정한 점수. 세기가 0이거나 하나라도 `hubness`가 없으면(엔진이 지원하지 않음) 그대로 돌려준다.
    /// - Parameter weight: 보정 세기 0...1
    public static func corrected(_ scored: [ScoredSymbol], weight: Double = 1, neighborCount k: Int = neighborCount) -> [ScoredSymbol] {
        guard weight > 0, !scored.isEmpty, k > 0, scored.allSatisfy({ $0.hubness != nil }) else { return scored }
        let top = scored.map(\.score).sorted(by: >).prefix(k)
        let queryHubness = top.reduce(0, +) / Double(top.count)
        return scored.map { symbol in
            symbol.withScore(symbol.score - weight * (queryHubness + (symbol.hubness ?? 0)) / 2)
        }
    }
}
