//
//  SymbolSearchViewModel.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation
import Domain

/// 심볼 검색 탭(S9): 이름·키워드로 찾기와 카테고리 둘러보기(기획서 6장 S9, 계획서 7장 결정 21).
/// 그리기와 별개라 기록·뱃지에는 영향이 없다.
@MainActor @Observable
final class SymbolSearchViewModel {
    enum State: Equatable {
        /// 검색어도 카테고리도 없음: 카테고리 둘러보기
        case browsing
        /// 결과(검색 또는 카테고리)
        case results([SymbolBrowseItem])
        /// 검색어에 맞는 심볼 없음
        case noMatches
        case failed(String)
    }

    /// 검색창 글자. 바뀌면 잠시 뒤 다시 찾는다.
    var query = "" {
        didSet { if query != oldValue { scheduleSearch() } }
    }
    private(set) var selectedCategory: SymbolCategory?
    private(set) var categories: [SymbolCategorySummary] = []
    private(set) var state: State = .browsing
    /// 받은 뱃지(family → 뱃지). 타일의 등급 점.
    private(set) var badgesByFamily: [String: SymbolBadge] = [:]
    /// 진행 중인 검색(테스트에서 끝나기를 기다릴 때 쓴다)
    private(set) var pendingSearch: Task<Void, Never>?

    private let browse: any BrowseSymbolsUseCase
    private let fetchBadges: any FetchBadgesUseCase
    private weak var navigator: (any SearchNavigating)?
    private let debounce: Duration

    init(browse: any BrowseSymbolsUseCase, fetchBadges: any FetchBadgesUseCase, navigator: (any SearchNavigating)?,
         debounce: Duration = .milliseconds(150)) {
        self.browse = browse
        self.fetchBadges = fetchBadges
        self.navigator = navigator
        self.debounce = debounce
    }

    /// 탭이 보일 때: 카테고리와 받은 뱃지를 읽는다(그리기에서 새 뱃지를 받았을 수 있음).
    func load() async {
        if categories.isEmpty {
            categories = (try? await browse.categories()) ?? []
        }
        let badges = (try? await fetchBadges.execute()) ?? [:]
        badgesByFamily = Dictionary(badges.values.map { (VariantGrouper.family(of: $0.symbolName), $0) },
                                    uniquingKeysWith: { first, _ in first })
    }

    func badge(for item: SymbolBrowseItem) -> SymbolBadge? {
        badgesByFamily[item.symbol.family]
    }

    // MARK: - 입력

    func selectCategory(_ category: SymbolCategory) {
        selectedCategory = category
        scheduleSearch(after: .zero)
    }

    func clearCategory() {
        selectedCategory = nil
        scheduleSearch(after: .zero)
    }

    func select(_ item: SymbolBrowseItem) {
        navigator?.showSearchDetail(SymbolDetailRequest(name: item.symbol.name, sketch: nil, similarity: nil))
    }

    func goDraw() {
        navigator?.showDrawTab()
    }

    // MARK: - 검색

    private func scheduleSearch(after delay: Duration? = nil) {
        pendingSearch?.cancel()
        let query = query, category = selectedCategory?.key, delay = delay ?? debounce
        pendingSearch = Task {
            if delay > .zero {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            await search(query: query, category: category)
        }
    }

    private func search(query: String, category: String?) async {
        guard SymbolTextSearch.normalize(query) != nil || category != nil else {
            state = .browsing
            return
        }
        do {
            let items = try await browse.execute(query: query, category: category)
            guard !Task.isCancelled else { return }
            state = items.isEmpty ? .noMatches : .results(items)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
