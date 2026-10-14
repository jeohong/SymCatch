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
final class AppRouter: DrawNavigating, RecentNavigating, CollectionNavigating, SettingsNavigating, OnboardingNavigating {
    var selectedTab: AppTab = .draw
    var drawPath: [DrawRoute] = []
    var recentPath: [RecentRoute] = []
    var collectionPath: [CollectionRoute] = []
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
        recentPath.append(.symbolDetail(request))
    }

    func showDrawTab() {
        selectedTab = .draw
    }

    func showBadgeDetail(symbolName: String) {
        collectionPath.append(.badgeDetail(symbolName: symbolName))
    }

    func showCollectionSymbolDetail(_ request: SymbolDetailRequest) {
        collectionPath.append(.symbolDetail(request))
    }

    func showSettings() {
        collectionPath.append(.settings)
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
