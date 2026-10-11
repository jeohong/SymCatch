//
//  DSColor.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 색 토큰. 값은 Asset Catalog(Resources/Assets.xcassets/Colors)에 라이트·다크 쌍으로 있다.
/// 화면 코드는 색 값을 직접 쓰지 않고 이 토큰만 쓴다. 출처: docs/design/DESIGN_NOTES.md 2.1
enum DSColor {
    // 배경
    static let bgPrimary = Color(.bgPrimary)
    /// 바텀시트, 칩, 타일 바탕, 도구 묶음
    static let bgSecondary = Color(.bgSecondary)
    /// 막대 바탕, 스켈레톤, 비활성 버튼
    static let bgTertiary = Color(.bgTertiary)
    /// 상세·콜렉션·설정 같은 그룹 화면 배경
    static let bgGrouped = Color(.bgGrouped)
    /// 그룹 카드
    static let cell = Color(.cell)
    /// 결과 행처럼 한 단계 떠 있는 카드
    static let cellElevated = Color(.cellElevated)
    /// 검색창·세그먼트 바탕·칩
    static let fill = Color(.controlFill)
    static let separator = Color(.lineSeparator)

    // 캔버스
    static let canvasBackground = Color(.canvasBackground)
    static let canvasInk = Color(.canvasInk)
    static let canvasDot = Color(.canvasDot)

    // 글자
    static let textPrimary = Color(.textPrimary)
    static let textSecondary = Color(.textSecondary)
    /// 미획득 뱃지 글리프
    static let lock = Color(.lock)

    // 강조
    static let accent = Color(.accent)
    static let accentHi = Color(.accentHi)
    /// accent 바탕 위 글자(라이트 흰색, 다크 검정)
    static let onAccent = Color(.onAccent)
    /// 뱃지 색 칩 위 글자(두 테마 모두 검정)
    static let onBadge = Color(.onBadge)
    static let danger = Color(.danger)

    // 뱃지 등급 (gold는 글자색으로 쓰지 않는다: 흰 바탕 대비 2.6:1)
    static let bronze = Color(.bronze)
    static let bronzeHi = Color(.bronzeHi)
    static let silver = Color(.silver)
    static let silverHi = Color(.silverHi)
    static let gold = Color(.gold)
    static let goldHi = Color(.goldHi)

    // 기타
    static let grab = Color(.grab)
    static let scrim = Color(.scrim)
    /// "곧 찾아요" 진행 채움
    static let pending = Color(.pending)

    /// 유사도 막대·테두리 색: 90% 이상 골드, 그 외 accent
    static func similarity(_ percent: Int) -> Color {
        percent >= 90 ? gold : accent
    }
}

extension UIColor {
    /// PencilKit은 라이트 기준 색을 받아 다크 모드에서 스스로 밝게 바꾼다. 그래서 라이트 값을 넘긴다.
    static var canvasInkForPencilKit: UIColor {
        UIColor(resource: .canvasInk).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    }
}
