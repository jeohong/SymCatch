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
final class AppRouter: DrawNavigating, RecentNavigating {
    var selectedTab: AppTab = .draw
    var drawPath: [DrawRoute] = []
    var recentPath: [RecentRoute] = []
    /// 떠 있는 축하 모달(S4). 탭 바까지 덮는다.
    var celebration: Celebration?

    func showSymbolDetail(_ request: SymbolDetailRequest) {
        drawPath.append(.symbolDetail(request))
    }

    func showRecentDetail(_ request: SymbolDetailRequest) {
        recentPath.append(.symbolDetail(request))
    }

    func showDrawTab() {
        selectedTab = .draw
    }

    func showCelebration(_ celebration: Celebration) {
        self.celebration = celebration
    }

    func dismissCelebration() {
        celebration = nil
    }
}
