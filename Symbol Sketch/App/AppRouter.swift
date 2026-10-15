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
    /// 심볼 검색(S9, 2026-10-15 추가)
    case search
}

/// 탭 선택과 탭별 내비게이션 경로를 가진다. 실제 경로 조작은 여기서만 한다.
@MainActor @Observable
final class AppRouter: DrawNavigating, RecentNavigating, CollectionNavigating, SettingsNavigating, OnboardingNavigating, SearchNavigating {
    var selectedTab: AppTab = .draw
    var drawPath: [DrawRoute] = []
    var recentPath: [RecentRoute] = []
    var collectionPath: [CollectionRoute] = []
    var searchPath: [SearchRoute] = []
    /// 넓은 창(regular)에서 최근·콜렉션을 분할 화면(목록 + 상세)으로 보여 주는지(기획서 8A.1).
    /// RootTabView가 크기 클래스로 정한다. 좁은 창은 지금처럼 경로에 쌓는다.
    var isSplitLayout = false
    /// 분할 화면 오른쪽에 보여 줄 최근 기록 상세(S3)
    var recentSelection: SymbolDetailRequest?
    /// 분할 화면 오른쪽에 보여 줄 콜렉션 상세(S7 또는 S8)와 그 안에서 이어지는 경로
    var collectionSelection: CollectionRoute?
    var collectionDetailPath: [CollectionRoute] = []
    /// 그리기 화면에 넘길 도전 목표(그리기 화면이 받아 가면 비운다)
    var pendingChallenge: String?
    /// 설정에서 "심볼 다시 준비하기"를 누름(그리기 화면이 받아 가면 비운다)
    var pendingIndexRebuild = false
    /// 떠 있는 축하 모달(S4). 탭 바까지 덮는다.
    var celebration: Celebration?
    /// 온보딩(S0)을 띄울지. 첫 실행에만 켜져 있고, 끝내면 다시 뜨지 않는다.
    var isOnboardingPresented: Bool

    private let defaults: UserDefaults
    static let onboardingCompletedKey = "onboardingCompleted"

    init(showsOnboarding: Bool? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOnboardingPresented = showsOnboarding ?? !defaults.bool(forKey: Self.onboardingCompletedKey)
    }

    func finishOnboarding(celebration: Celebration?) {
        defaults.set(true, forKey: Self.onboardingCompletedKey)
        selectedTab = .draw
        drawPath = []
        isOnboardingPresented = false
        // 연습에서 받은 첫 번째 획 업적 등은 그리기 홈 위에 띄운다(기획서 5장 1).
        if let celebration { self.celebration = celebration }
    }

    func showSymbolDetail(_ request: SymbolDetailRequest) {
        drawPath.append(.symbolDetail(request))
    }

    func showRecentDetail(_ request: SymbolDetailRequest) {
        if isSplitLayout {
            recentSelection = request
        } else {
            recentPath.append(.symbolDetail(request))
        }
    }

    func showDrawTab() {
        selectedTab = .draw
    }

    func showSearchDetail(_ request: SymbolDetailRequest) {
        searchPath.append(.symbolDetail(request))
    }

    func showBadgeDetail(symbolName: String) {
        showCollectionDetail(.badgeDetail(symbolName: symbolName))
    }

    func showCollectionSymbolDetail(_ request: SymbolDetailRequest) {
        if isSplitLayout {
            collectionDetailPath.append(.symbolDetail(request))
        } else {
            collectionPath.append(.symbolDetail(request))
        }
    }

    func showSettings() {
        showCollectionDetail(.settings)
    }

    func showAchievements() {
        showCollectionDetail(.achievements)
    }

    /// 분할 화면이면 오른쪽 상세를 바꾸고(이어진 경로는 비움), 아니면 경로에 쌓는다.
    private func showCollectionDetail(_ route: CollectionRoute) {
        if isSplitLayout {
            collectionSelection = route
            collectionDetailPath = []
        } else {
            collectionPath.append(route)
        }
    }

    func rebuildSymbolIndex() {
        drawPath = []
        selectedTab = .draw
        pendingIndexRebuild = true
    }

    func startChallenge(symbolName: String) {
        drawPath = []
        selectedTab = .draw
        pendingChallenge = symbolName
    }

    func showCelebration(_ celebration: Celebration) {
        self.celebration = celebration
    }

    func dismissCelebration() {
        celebration = nil
    }
}
