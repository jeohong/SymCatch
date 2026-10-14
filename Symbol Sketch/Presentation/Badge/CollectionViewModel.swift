//
//  CollectionViewModel.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 콜렉션(S6): 달성률, 등급별 개수, 업적, 카테고리별 메달 격자(기획서 3.2, DESIGN_NOTES S6).
@MainActor @Observable
final class CollectionViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded(CollectionSummary)
        case failed(String)
    }

    private(set) var loadState: LoadState = .loading
    private(set) var badgesByName: [String: SymbolBadge] = [:]

    private let fetchCollection: any FetchCollectionUseCase
    private weak var navigator: (any CollectionNavigating)?

    init(fetchCollection: any FetchCollectionUseCase, navigator: (any CollectionNavigating)?) {
        self.fetchCollection = fetchCollection
        self.navigator = navigator
    }

    var summary: CollectionSummary? {
        if case .loaded(let summary) = loadState { summary } else { nil }
    }

    /// 진행 막대 비율. 하나라도 있으면 막대가 보이도록 최소 0.8%(디자인 S6).
    var progress: Double {
        guard let summary, summary.totalSymbolCount > 0, !summary.badges.isEmpty else { return 0 }
        return max(0.008, Double(summary.badges.count) / Double(summary.totalSymbolCount))
    }

    func badge(for name: String) -> SymbolBadge? {
        badgesByName[name]
    }

    /// 카테고리 안에서 얻은 뱃지 수
    func earnedCount(in category: CategorySymbols) -> Int {
        category.names.filter { badgesByName[$0] != nil }.count
    }

    /// 업적 카드 아래 상태: "2026. 9. 20. 달성" 또는 "9 / 10"
    func statusText(for achievement: Achievement) -> String {
        if let date = achievement.unlockedAt {
            return String(localized: "\(ProgressDateFormat.day(date)) 달성")
        }
        return "\(achievement.progress) / \(achievement.goal)"
    }

    // MARK: - 입력

    /// 화면이 보일 때마다 다시 읽는다(그리기에서 새 뱃지를 받았을 수 있음).
    func load() async {
        do {
            let summary = try await fetchCollection.execute()
            badgesByName = Dictionary(summary.badges.map { ($0.symbolName, $0) }, uniquingKeysWith: { first, _ in first })
            loadState = .loaded(summary)
        } catch {
            if summary == nil { loadState = .failed(error.localizedDescription) }
        }
    }

    func select(symbolName: String) {
        navigator?.showBadgeDetail(symbolName: symbolName)
    }

    /// 오른쪽 위 톱니
    func openSettings() {
        navigator?.showSettings()
    }

    /// 뱃지가 없을 때 안내의 "그리러 가기"
    func goDraw() {
        navigator?.showDrawTab()
    }
}
