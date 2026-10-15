//
//  SymbolSearchViewModelTests.swift
//  SymCatchTests
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation
import Testing
import Domain
@testable import SymCatch

private final class SpyBrowse: BrowseSymbolsUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [(String, String?)] = []
    var calls: [(String, String?)] { lock.withLock { _calls } }
    var items: [SymbolBrowseItem] = []

    func categories() async throws -> [SymbolCategorySummary] {
        [SymbolCategorySummary(category: SymbolCategory(key: "health", label: "Health", icon: "heart"), count: 2)]
    }

    func execute(query: String, category: String?) async throws -> [SymbolBrowseItem] {
        lock.withLock { _calls.append((query, category)) }
        return items
    }
}

private struct StubBadges: FetchBadgesUseCase {
    func execute() async throws -> [String: SymbolBadge] {
        ["heart.fill": SymbolBadge(symbolName: "heart.fill", tier: .silver, bestSimilarity: 91, bestSketch: .empty, earnedAt: .now)]
    }
}

@MainActor
private final class SpySearchNavigator: SearchNavigating {
    var details: [SymbolDetailRequest] = []
    var wentToDraw = 0
    func showSearchDetail(_ request: SymbolDetailRequest) { details.append(request) }
    func showDrawTab() { wentToDraw += 1 }
}

private func item(_ name: String) -> SymbolBrowseItem {
    SymbolBrowseItem(symbol: SymbolMeta(name: name, family: VariantGrouper.family(of: name), categories: [], keywords: [], minOS: "13.0"),
                     variantCount: 1)
}

@MainActor
struct SymbolSearchViewModelTests {
    private func makeViewModel(_ browse: SpyBrowse, navigator: SpySearchNavigator? = nil) -> SymbolSearchViewModel {
        SymbolSearchViewModel(browse: browse, fetchBadges: StubBadges(), navigator: navigator, debounce: .zero)
    }

    @Test func 처음에는_카테고리_둘러보기() async {
        let viewModel = makeViewModel(SpyBrowse())
        await viewModel.load()
        #expect(viewModel.state == .browsing)
        #expect(viewModel.categories.map(\.category.key) == ["health"])
    }

    @Test func 검색어를_넣으면_찾고_비우면_둘러보기로() async {
        let browse = SpyBrowse()
        browse.items = [item("heart"), item("suit.heart")]
        let viewModel = makeViewModel(browse)

        viewModel.query = "heart"
        await viewModel.pendingSearch?.value
        #expect(viewModel.state == .results(browse.items))

        viewModel.query = "  "
        await viewModel.pendingSearch?.value
        #expect(viewModel.state == .browsing)
    }

    @Test func 맞는_심볼이_없으면_안내() async {
        let viewModel = makeViewModel(SpyBrowse())
        viewModel.query = "zzz"
        await viewModel.pendingSearch?.value
        #expect(viewModel.state == .noMatches)
    }

    @Test func 카테고리를_고르면_그_안에서_찾고_해제하면_둘러보기() async {
        let browse = SpyBrowse()
        browse.items = [item("heart")]
        let viewModel = makeViewModel(browse)

        viewModel.selectCategory(SymbolCategory(key: "health", label: "Health", icon: "heart"))
        await viewModel.pendingSearch?.value
        #expect(browse.calls.last.map { $0.1 } == "health")
        #expect(viewModel.state == .results([item("heart")]))

        viewModel.clearCategory()
        await viewModel.pendingSearch?.value
        #expect(viewModel.selectedCategory == nil)
        #expect(viewModel.state == .browsing)
    }

    @Test func 받은_뱃지는_변형_이름이어도_대표_타일에_보인다() async {
        let viewModel = makeViewModel(SpyBrowse())
        await viewModel.load()
        #expect(viewModel.badge(for: item("heart"))?.tier == .silver)
        #expect(viewModel.badge(for: item("star")) == nil)
    }

    @Test func 타일을_누르면_그림_없이_상세로() {
        let navigator = SpySearchNavigator()
        let viewModel = makeViewModel(SpyBrowse(), navigator: navigator)
        viewModel.select(item("heart"))
        #expect(navigator.details == [SymbolDetailRequest(name: "heart", sketch: nil, similarity: nil)])
        viewModel.goDraw()
        #expect(navigator.wentToDraw == 1)
    }
}
