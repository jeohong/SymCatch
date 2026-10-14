//
//  AppPreferences.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import SwiftUI

/// 설정에 저장하는 사용자 선택(`@AppStorage` 키). 기기 안에만 저장된다.
enum AppPreferenceKey {
    static let theme = "theme"
    static let haptics = "haptics"
}

/// 화면 테마(S8): 시스템 · 라이트 · 다크
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "시스템")
        case .light: String(localized: "라이트")
        case .dark: String(localized: "다크")
        }
    }

    /// 루트에 걸 `.preferredColorScheme`. 시스템이면 nil.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
