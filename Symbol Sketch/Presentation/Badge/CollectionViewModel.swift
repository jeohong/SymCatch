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
    private(set) var badgesByFamily: [String: SymbolBadge] = [:]

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
        badgesByFamily[VariantGrouper.family(of: name)]
    }

    /// 카테고리 안에서 얻은 뱃지 수
    func earnedCount(in category: CategorySymbols) -> Int {
        category.names.filter { badge(for: $0) != nil }.count
    }

    // MARK: - 업적(기획서 3.2)

    /// 콜렉션 "업적" 줄: 일반 업적만. 아직 못 받은 것을 진행률 높은 순으로 앞에, 받은 것은 뒤에(최근 달성순).
    var featuredAchievements: [Achievement] {
        let general = summary?.achievements.filter { $0.id.categoryKey == nil } ?? []
        let locked = general.filter { !$0.isUnlocked }
            .sorted { Double($0.progress) / Double(max($0.goal, 1)) > Double($1.progress) / Double(max($1.goal, 1)) }
        let unlocked = general.filter(\.isUnlocked).sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
        return locked + unlocked
    }

    /// 일반 업적(업적 전체 보기 순서)
    var generalAchievements: [Achievement] {
        summary?.achievements.filter { $0.id.categoryKey == nil } ?? []
    }

    /// 카테고리의 입문·전설 업적("기타"처럼 업적이 없는 카테고리는 빈 배열)
    func categoryAchievements(for key: String) -> [Achievement] {
        summary?.achievements.filter { $0.id.categoryKey == key } ?? []
    }

    var unlockedAchievementCount: Int { summary?.achievements.filter(\.isUnlocked).count ?? 0 }
    var achievementCount: Int { summary?.achievements.count ?? 0 }

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
            // 격자는 대표 이름(기본 모양)으로 찾으므로 family로 맞춘다(heart.fill 뱃지 → heart 칸, 카테고리 업적과 같은 기준).
            badgesByFamily = Dictionary(summary.badges.map { (VariantGrouper.family(of: $0.symbolName), $0) },
                                        uniquingKeysWith: { first, _ in first })
            loadState = .loaded(summary)
        } catch {
            if summary == nil { loadState = .failed(error.localizedDescription) }
        }
    }

    func select(symbolName: String) {
        navigator?.showBadgeDetail(symbolName: symbolName)
    }

    /// 업적 "전체 보기"
    func openAchievements() {
        navigator?.showAchievements()
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
