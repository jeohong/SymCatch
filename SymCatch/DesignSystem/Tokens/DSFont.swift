//
//  DSFont.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 글꼴 토큰. 시스템 텍스트 스타일만 쓴다(기획서 7.2). 심볼 이름·코드는 SF Mono.
/// 대응표: docs/design/DESIGN_NOTES.md 2.5
nonisolated enum DSFont {
    /// 유사도 숫자(22 Bold)
    static let similarity = Font.title2.bold().monospacedDigit()
    /// 상세 비교의 큰 유사도(28 Bold)
    static let similarityLarge = Font.title.bold().monospacedDigit()
    /// 결과 행 심볼 이름(SF Mono 15 Semibold)
    static let symbolName = Font.system(.subheadline, design: .monospaced).weight(.semibold)
    /// 카드·칩의 작은 심볼 이름
    static let symbolNameSmall = Font.system(.caption, design: .monospaced).weight(.semibold)
    /// 상세 화면 큰 심볼 이름(SF Mono 22 Bold)
    static let symbolNameLarge = Font.system(.title2, design: .monospaced).weight(.bold)
    /// 복사 행의 코드(SF Mono 13)
    static let code = Font.system(.footnote, design: .monospaced)
    /// 순위 숫자
    static let rank = Font.system(.footnote, design: .monospaced)
    static let rankSmall = Font.system(.caption2, design: .monospaced)
    /// 라벨 칩("뱃지 획득 가능" 등)
    static let chip = Font.caption2.bold()
    /// 섹션 헤더(13 Semibold)
    static let sectionHeader = Font.footnote.weight(.semibold)
}
