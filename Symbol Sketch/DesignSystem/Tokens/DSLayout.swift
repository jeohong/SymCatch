//
//  DSLayout.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 간격 토큰. 4pt 단위(기획서 7.2). 화면 좌우 여백은 `screen`.
nonisolated enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// 화면 좌우 여백
    static let screen: CGFloat = 16
}

/// 모서리 반경 토큰(DESIGN_NOTES 2.4)
nonisolated enum Radius {
    /// 라벨 칩
    static let chip: CGFloat = 6
    /// 심볼 타일, 변형 칩
    static let tile: CGFloat = 10
    /// 버튼, 도구 버튼, 최근 칩
    static let button: CGFloat = 12
    /// 도구 묶음, 찾기 버튼
    static let toolGroup: CGFloat = 14
    /// 카드, 결과 행, 바텀시트 윗모서리
    static let card: CGFloat = 16
    /// iPad 결과 패널
    static let panel: CGFloat = 20
    /// 캔버스, 상세 미리보기
    static let canvas: CGFloat = 24
}

/// 크기 토큰. 글리프 크기는 Dynamic Type을 따르도록 화면에서 `@ScaledMetric`으로 감싸 쓴다.
nonisolated enum Metrics {
    /// 최소 탭 영역(기획서 6장 접근성)
    static let minTapTarget: CGFloat = 44
    /// 도구 버튼
    static let toolButton: CGFloat = 44
    /// 찾기 버튼·주 버튼 높이
    static let primaryButtonHeight: CGFloat = 48
    static let largeButtonHeight: CGFloat = 50
    /// 결과 행 심볼 타일 / 글리프
    static let rowTile: CGFloat = 44
    static let rowGlyph: CGFloat = 28
    /// Top 3 카드 글리프
    static let cardGlyph: CGFloat = 32
    /// 유사도 막대
    static let barWidth: CGFloat = 64
    static let barHeight: CGFloat = 4
    /// 캔버스 점 격자 간격·점 지름
    static let dotSpacing: CGFloat = 24
    static let dotDiameter: CGFloat = 2.4
    /// 상세 미리보기 영역 높이·글리프
    static let previewHeight: CGFloat = 230
    static let previewGlyph: CGFloat = 132
    static let compareGlyph: CGFloat = 96
    /// 바텀시트 손잡이
    static let grabberWidth: CGFloat = 36
    static let grabberHeight: CGFloat = 5
}
