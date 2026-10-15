//
//  SymCatchApp.swift
//  SymCatch
//
//  Created by jeongmin hong on 10/11/26.
//

import SwiftUI

@main
struct SymCatchApp: App {
    private let container = AppContainer.live()
    /// 설정(S8)의 테마. 시스템이면 기기 설정을 따른다.
    @AppStorage(AppPreferenceKey.theme) private var theme = AppTheme.system

    var body: some Scene {
        WindowGroup {
            RootTabView(container: container)
                .preferredColorScheme(theme.colorScheme)
        }
    }
}
