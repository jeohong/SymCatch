//
//  DrawLayoutResolver.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/14/26.
//

import SwiftUI

/// 그리기 화면(S1) 배치. 기획서 8장(iPhone Duo)·8A장(iPad).
nonisolated enum DrawLayout: Equatable {
    /// 위 최근 · 캔버스 · 도구 바 · 하단 결과 시트(일반 iPhone, Duo 닫힘·펼침, iPad 좁은 창)
    case compact
    /// 왼쪽 캔버스 · 세로 도구 열 + 오른쪽 최근·Top 10(결정 23). 가로가 긴 compact 컨테이너(iPhone 가로, Duo 바깥 화면 가로)와
    /// 높이가 낮은 regular 가로 컨테이너(Pro Max·Plus 가로)에서 쓴다.
    case compactLandscape
    /// 왼쪽 캔버스 + 오른쪽 Top 10(가로가 긴 regular 컨테이너)
    case regularLandscape
    /// 위 캔버스 + 아래 Top 10 2열 격자(세로가 긴 regular 컨테이너)
    case regularPortrait
    /// Duo 반쯤 접힘 + 가로 접힘선: 위(`top`)에 결과, 아래(`bottom`)에 캔버스·도구. 접힘 영역은 비운다.
    case duoHalfFolded(top: CGRect, bottom: CGRect)
}

/// 컨테이너 크기·크기 클래스·접힘 영역으로 배치를 고르는 순수 함수(CLAUDE.md 4장).
/// 기기 종류나 화면 크기(`UIScreen`)로는 나누지 않는다.
nonisolated enum DrawLayoutResolver {
    /// 접힘 위·아래 영역이 이보다 낮으면 나눠 쓰기 어려워 기본 배치를 쓴다.
    static let minimumFoldedPaneHeight: CGFloat = 120
    /// `compactLandscape`에서 오른쪽 최근·결과 열의 최소 폭
    static let minimumSideColumnWidth: CGFloat = 240
    /// 가로 컨테이너에서 옆으로 나눴을 때 캔버스가 이 크기 이상 나와야 `compactLandscape`를 쓴다.
    /// 예: Duo 바깥 화면 가로 594×432 → 246(폭에 맞춤), iPhone 17 가로 750×276 → 260(높이에 맞춤)
    static let minimumLandscapeCanvasSide: CGFloat = 200
    /// `compactLandscape` 가로 여백 합(좌우 여백 + 캔버스·도구 열·결과 열 사이 간격)
    static let landscapeHorizontalChrome: CGFloat = Spacing.l * 4 + Metrics.toolButton

    /// `compactLandscape`의 캔버스 한 변: 높이에 맞춘 정사각형이되 오른쪽 열이 `minimumSideColumnWidth`보다 좁아지지 않게
    static func landscapeCanvasSide(in size: CGSize) -> CGFloat {
        min(size.height - Spacing.s * 2, size.width - landscapeHorizontalChrome - minimumSideColumnWidth)
    }
    /// regular 가로 컨테이너가 이보다 낮으면 위아래로 최근 줄·도구 바를 쌓을 자리가 없어 `compactLandscape`를 쓴다.
    static let minimumRegularLandscapeHeight: CGFloat = 500

    /// - Parameters:
    ///   - size: 그리기 화면 컨테이너 크기
    ///   - horizontalSizeClass: 가로 크기 클래스(nil이면 compact로 본다)
    ///   - fold: 활성 접힘 영역(컨테이너 좌표). 없으면 nil
    static func resolve(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?, fold: CGRect?) -> DrawLayout {
        if let fold, let panes = halfFoldedPanes(size: size, fold: fold) {
            return .duoHalfFolded(top: panes.top, bottom: panes.bottom)
        }
        guard horizontalSizeClass == .regular else {
            // 세로 접힘선이 있으면 가운데를 가로지르지 않도록 기존 배치를 쓴다(기획서 8.1).
            guard horizontalSizeClass == .compact, fold == nil, size.width > size.height,
                  landscapeCanvasSide(in: size) >= minimumLandscapeCanvasSide else { return .compact }
            return .compactLandscape
        }
        guard size.width > size.height else { return .regularPortrait }
        return size.height < minimumRegularLandscapeHeight ? .compactLandscape : .regularLandscape
    }

    /// 가로로 긴 접힘선이 컨테이너를 위·아래로 충분히 나눌 때만 두 영역을 돌려준다.
    /// 세로 접힘선(폭 ≤ 높이)이나 컨테이너 밖 접힘은 무시한다(기존 배치).
    private static func halfFoldedPanes(size: CGSize, fold: CGRect) -> (top: CGRect, bottom: CGRect)? {
        guard fold.width > fold.height, fold.minY >= 0, fold.maxY <= size.height else { return nil }
        let top = CGRect(x: 0, y: 0, width: size.width, height: fold.minY)
        let bottom = CGRect(x: 0, y: fold.maxY, width: size.width, height: size.height - fold.maxY)
        guard top.height >= minimumFoldedPaneHeight, bottom.height >= minimumFoldedPaneHeight else { return nil }
        return (top, bottom)
    }
}
