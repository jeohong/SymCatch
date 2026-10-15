//
//  DrawNavigation.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 심볼 상세(S3)를 열 때 넘기는 값
struct SymbolDetailRequest: Hashable {
    /// 결과에서 고른 대표 이름
    let name: String
    /// 그린 그림(그리기·최근에서 들어올 때). 비교 영역에 쓴다.
    let sketch: Sketch?
    /// 그 그림과의 유사도
    let similarity: Int?
    /// 지난 기록의 그림인지(비교 캡션 "내 그림" ↔ "당시 그림", 디자인 S3)
    var isPastSketch = false
}

enum DrawRoute: Hashable {
    case symbolDetail(SymbolDetailRequest)
}

/// 그리기 화면이 화면 이동 의도를 알리는 통로. ViewModel은 라우터 구현을 모른다.
@MainActor
protocol DrawNavigating: AnyObject {
    func showSymbolDetail(_ request: SymbolDetailRequest)
    /// 뱃지 획득 모달(S4)
    func showCelebration(_ celebration: Celebration)
}

enum RecentRoute: Hashable {
    case symbolDetail(SymbolDetailRequest)
}

/// 최근 화면(S5)이 화면 이동 의도를 알리는 통로
@MainActor
protocol RecentNavigating: AnyObject {
    func showRecentDetail(_ request: SymbolDetailRequest)
    /// 빈 상태의 "그리러 가기"
    func showDrawTab()
}

enum CollectionRoute: Hashable {
    case badgeDetail(symbolName: String)
    case symbolDetail(SymbolDetailRequest)
    case settings
    /// 업적 전체 보기(기획서 3.2)
    case achievements
}

/// 콜렉션(S6)·뱃지 상세(S7)가 화면 이동 의도를 알리는 통로
@MainActor
protocol CollectionNavigating: AnyObject {
    func showBadgeDetail(symbolName: String)
    func showCollectionSymbolDetail(_ request: SymbolDetailRequest)
    /// "더 높은 등급에 도전" / "그려서 도전하기": 그리기 탭으로 가서 목표 카드를 띄운다.
    func startChallenge(symbolName: String)
    func showDrawTab()
    /// 오른쪽 위 톱니(S8)
    func showSettings()
    /// 업적 "전체 보기"
    func showAchievements()
}

/// 온보딩(S0)이 끝났음을 알리는 통로
enum SearchRoute: Hashable {
    case symbolDetail(SymbolDetailRequest)
}

/// 심볼 검색 탭(S9)
@MainActor
protocol SearchNavigating: AnyObject {
    /// 타일을 누르면 심볼 상세(그림 비교 없음)
    func showSearchDetail(_ request: SymbolDetailRequest)
    /// 결과가 없을 때 "그려서 찾아보세요"
    func showDrawTab()
}

@MainActor
protocol OnboardingNavigating: AnyObject {
    /// 건너뛰기 · 나중에 할게요 · 연습에서 심볼을 고름. 축하할 것이 있으면 그리기 홈 위에 모달을 띄운다.
    func finishOnboarding(celebration: Celebration?)
}

/// 설정(S8)이 화면 이동 의도를 알리는 통로
@MainActor
protocol SettingsNavigating: AnyObject {
    /// "심볼 다시 준비하기": 그리기 탭으로 가서 준비 상태를 보여 준다.
    func rebuildSymbolIndex()
}
