//
//  AppRouter.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

enum AppTab: Hashable {
    case draw
    case recent
    case collection
}

/// 탭 선택과 탭별 내비게이션 경로를 가진다. 실제 경로 조작은 여기서만 한다.
@MainActor @Observable
final class AppRouter: DrawNavigating {
    var selectedTab: AppTab = .draw
    var drawPath: [DrawRoute] = []

    func showSymbolDetail(_ request: SymbolDetailRequest) {
        drawPath.append(.symbolDetail(request))
    }
}
