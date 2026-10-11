//
//  DrawViewModelTests.swift
//  Symbol SketchTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import Symbol_Sketch

private final class StubPrepare: PrepareSymbolIndexUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var ready: Bool
    var failure: Error?

    init(ready: Bool) { self.ready = ready }

    func status() async -> SymbolIndexStatus {
        lock.withLock { ready } ? .ready(symbolCount: 10) : .missing
    }

    func execute() -> AsyncThrowingStream<Double, Error> {
        AsyncThrowingStream { continuation in
            if let failure {
                continuation.finish(throwing: failure)
                return
            }
            continuation.yield(0.5)
            lock.withLock { ready = true }
            continuation.yield(1)
            continuation.finish()
        }
    }
}

private final class StubSearch: SearchSymbolsUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    var outcome: SearchOutcome
    var delay: Duration = .zero

    init(outcome: SearchOutcome) { self.outcome = outcome }

    var callCount: Int { lock.withLock { calls } }

    func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome {
        lock.withLock { calls += 1 }
        if delay > .zero { try await Task.sleep(for: delay) }
        return outcome
    }
}

private final class StubSelect: SelectSymbolUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var selected: [(SymbolMatch, Sketch)] = []
    var award: BadgeAward = .none
    var achievements: [Achievement] = []
    var failure: Error?

    var calls: [(SymbolMatch, Sketch)] { lock.withLock { selected } }

    func execute(match: SymbolMatch, sketch: Sketch, now: Date) async throws -> SelectionOutcome {
        lock.withLock { selected.append((match, sketch)) }
        if let failure { throw failure }
        return SelectionOutcome(record: FoundRecord(symbolName: match.name, sketch: sketch, similarity: match.similarity, foundAt: now),
                                badgeAward: award, newAchievements: achievements)
    }
}

private final class StubRecent: FetchRecentRecordsUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [FoundRecord] = []
    var records: [FoundRecord] {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
    func execute(limit: Int?) async throws -> [FoundRecord] {
        let all = records
        return limit.map { Array(all.prefix($0)) } ?? all
    }
}

private struct StubBadges: FetchBadgesUseCase {
    var badges: [String: SymbolBadge] = [:]
    func execute() async throws -> [String: SymbolBadge] { badges }
}

private final class MutableBadges: FetchBadgesUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String: SymbolBadge]
    init(_ badges: [String: SymbolBadge]) { stored = badges }
    var badges: [String: SymbolBadge] {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
    func execute() async throws -> [String: SymbolBadge] { badges }
}

@MainActor
private final class SpyNavigator: DrawNavigating {
    var shown: [SymbolDetailRequest] = []
    var celebrations: [Celebration] = []
    func showSymbolDetail(_ request: SymbolDetailRequest) { shown.append(request) }
    func showCelebration(_ celebration: Celebration) { celebrations.append(celebration) }
}

private struct PreparationFailed: Error {}

@MainActor
struct DrawViewModelTests {
    private let drawn = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])
    private let results = (1...12).map { SymbolMatch(name: "s\($0)", variants: [], similarity: 100 - $0) }

    private func makeViewModel(
        ready: Bool = true,
        search: StubSearch,
        navigator: SpyNavigator? = nil,
        select: StubSelect = StubSelect(),
        recent: StubRecent = StubRecent(),
        badges: StubBadges = StubBadges(),
        skeletonDelay: Duration = .milliseconds(300)
    ) -> DrawViewModel {
        DrawViewModel(prepareIndex: StubPrepare(ready: ready), searchSymbols: search, selectSymbol: select,
                      fetchRecent: recent, fetchBadges: badges, navigator: navigator,
                      now: { Date(timeIntervalSince1970: 1_791_720_000) }, debounce: .zero, skeletonDelay: skeletonDelay)
    }

    @Test func 인덱스가_있으면_바로_준비됨() async {
        let viewModel = makeViewModel(search: StubSearch(outcome: .results([])))
        await viewModel.start()
        #expect(viewModel.preparation == .ready)
    }

    @Test func 인덱스가_없으면_만들고_준비됨으로_바뀐다() async {
        let viewModel = makeViewModel(ready: false, search: StubSearch(outcome: .results([])))
        await viewModel.start()
        while viewModel.preparation != .ready {
            if case .failed = viewModel.preparation { break }
            await Task.yield()
        }
        #expect(viewModel.preparation == .ready)
    }

    @Test func 준비에_실패하면_오류를_보여주고_다시_준비할_수_있다() async {
        let prepare = StubPrepare(ready: false)
        prepare.failure = PreparationFailed()
        let viewModel = DrawViewModel(prepareIndex: prepare, searchSymbols: StubSearch(outcome: .results([])), selectSymbol: StubSelect(),
                                      fetchRecent: StubRecent(), fetchBadges: StubBadges(), navigator: nil, debounce: .zero)
        await viewModel.start()
        while case .preparing = viewModel.preparation { await Task.yield() }
        guard case .failed = viewModel.preparation else {
            Issue.record("실패 상태여야 한다: \(viewModel.preparation)")
            return
        }

        prepare.failure = nil
        viewModel.retryPreparation()
        while viewModel.preparation != .ready { await Task.yield() }
        #expect(viewModel.preparation == .ready)
    }

    @Test func 그리면_자동으로_찾고_Top3를_미리_보여준다() async {
        let search = StubSearch(outcome: .results(results))
        let viewModel = makeViewModel(search: search)
        await viewModel.start()

        viewModel.sketchDidChange(drawn)
        #expect(viewModel.phase == .waiting)
        await viewModel.pendingSearch?.value

        #expect(search.callCount == 1)
        #expect(viewModel.phase == .idle)
        #expect(viewModel.matches.count == 12)
        #expect(viewModel.previewMatches.map(\.name) == ["s1", "s2", "s3"])
    }

    @Test func 그림이_부족하면_안내한다() async {
        let viewModel = makeViewModel(search: StubSearch(outcome: .tooSmall))
        await viewModel.start()
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value
        #expect(viewModel.phase == .tooSmall)
        #expect(viewModel.matches.isEmpty)
    }

    @Test func 준비_전에는_검색하지_않는다() async {
        let search = StubSearch(outcome: .results(results))
        let viewModel = makeViewModel(ready: false, search: search)
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value
        #expect(search.callCount == 0)
        #expect(!viewModel.canSearch)
    }

    @Test func 검색이_오래_걸리면_스켈레톤을_보여준다() async throws {
        let search = StubSearch(outcome: .results(results))
        search.delay = .milliseconds(300)
        let viewModel = makeViewModel(search: search, skeletonDelay: .milliseconds(50))
        await viewModel.start()

        viewModel.searchNow()  // 그림이 없으면 무시된다
        viewModel.sketchDidChange(drawn)
        try await Task.sleep(for: .milliseconds(150))
        #expect(viewModel.phase == .searching(showsSkeleton: true))

        await viewModel.pendingSearch?.value
        #expect(viewModel.phase == .idle)
    }

    @Test func 결과를_고르면_그림과_유사도를_넘겨_상세로_간다() async {
        let navigator = SpyNavigator()
        let viewModel = makeViewModel(search: StubSearch(outcome: .results(results)), navigator: navigator)
        await viewModel.start()
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        viewModel.select(results[0])

        #expect(navigator.shown == [SymbolDetailRequest(name: "s1", sketch: drawn, similarity: 99)])
    }

    @Test func 다시_그리기와_상세에서_돌아오기는_캔버스를_비운다() async {
        let viewModel = makeViewModel(search: StubSearch(outcome: .results(results)))
        await viewModel.start()
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value
        viewModel.isSheetExpanded = true

        viewModel.redraw()
        #expect(viewModel.matches.isEmpty)
        #expect(!viewModel.isSheetExpanded)
        #expect(viewModel.canvasResetCount == 1)

        viewModel.returnedFromDetail()
        #expect(viewModel.canvasResetCount == 2)
    }

    @Test func 지우면_결과도_사라진다() async {
        let viewModel = makeViewModel(search: StubSearch(outcome: .results(results)))
        await viewModel.start()
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        viewModel.sketchDidChange(.empty)

        #expect(viewModel.matches.isEmpty)
        #expect(viewModel.phase == .idle)
    }

    @Test func 뱃지_표시는_90퍼센트_이상이고_보유_등급을_반영한다() async {
        let owned = SymbolBadge(symbolName: "owned", tier: .silver, bestSimilarity: 96, bestSketch: drawn, earnedAt: .now)
        let viewModel = makeViewModel(search: StubSearch(outcome: .results([])), badges: StubBadges(badges: ["owned": owned]))
        await viewModel.refreshProgress()

        #expect(viewModel.badgeHint(for: SymbolMatch(name: "a", variants: [], similarity: 90)) == .eligible(.bronze))
        #expect(viewModel.badgeHint(for: SymbolMatch(name: "a", variants: [], similarity: 89)) == .none)
        #expect(viewModel.badgeHint(for: SymbolMatch(name: "owned", variants: [], similarity: 92)) == .owned(.silver))
        #expect(viewModel.badgeHint(for: SymbolMatch(name: "owned", variants: [], similarity: 99)) == .eligible(.gold))
    }

    // MARK: - M2 결과 선택·최근 기록

    @Test func 결과를_고르면_그림과_함께_기록을_저장한다() async {
        let select = StubSelect()
        let viewModel = makeViewModel(search: StubSearch(outcome: .results(results)), select: select)
        await viewModel.start()
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        viewModel.select(results[1])
        await viewModel.pendingSelection?.value

        #expect(select.calls.map(\.0.name) == ["s2"])
        #expect(select.calls.first?.1 == drawn)
    }

    @Test func 새_뱃지와_업적이면_축하_모달을_띄운다() async {
        let select = StubSelect()
        let badge = SymbolBadge(symbolName: "s1", tier: .gold, bestSimilarity: 99, bestSketch: drawn, earnedAt: .now)
        select.award = .newBadge(badge)
        select.achievements = [Achievement(id: .sharpshooter, progress: 1, unlockedAt: .now)]
        let navigator = SpyNavigator()
        let viewModel = makeViewModel(search: StubSearch(outcome: .results(results)), navigator: navigator, select: select)
        await viewModel.start()
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        viewModel.select(results[0])
        await viewModel.pendingSelection?.value

        #expect(navigator.shown.map(\.name) == ["s1"])          // 상세는 바로 열린다
        #expect(navigator.celebrations.count == 1)
        guard case .badge(let name, let tier, let isUpgrade, _, _, _) = navigator.celebrations.first?.cards.first else {
            Issue.record("첫 장은 뱃지 카드여야 한다")
            return
        }
        #expect(name == "s1" && tier == .gold && !isUpgrade)
        #expect(navigator.celebrations.first?.cards.count == 2)
    }

    @Test func 축하할_것이_없으면_모달_없이_상세만() async {
        let select = StubSelect()
        select.award = .silentUpdate(SymbolBadge(symbolName: "s1", tier: .bronze, bestSimilarity: 93, bestSketch: drawn, earnedAt: .now))
        let navigator = SpyNavigator()
        let viewModel = makeViewModel(search: StubSearch(outcome: .results(results)), navigator: navigator, select: select)
        await viewModel.start()

        viewModel.select(results[0])
        await viewModel.pendingSelection?.value

        #expect(navigator.shown.count == 1)
        #expect(navigator.celebrations.isEmpty)
    }

    @Test func 저장에_실패해도_상세는_열린다() async {
        let select = StubSelect()
        select.failure = PreparationFailed()
        let navigator = SpyNavigator()
        let viewModel = makeViewModel(search: StubSearch(outcome: .results(results)), navigator: navigator, select: select)

        viewModel.select(results[0])
        await viewModel.pendingSelection?.value

        #expect(navigator.shown.count == 1)
        #expect(navigator.celebrations.isEmpty)
    }

    @Test func 고른_뒤_최근_목록이_갱신되고_최대_5개() async {
        let recent = StubRecent()
        let viewModel = makeViewModel(search: StubSearch(outcome: .results(results)), recent: recent)
        await viewModel.refreshProgress()
        #expect(viewModel.recentRecords.isEmpty)

        recent.records = (1...7).map { FoundRecord(symbolName: "r\($0)", sketch: drawn, similarity: 50, foundAt: .now) }
        viewModel.select(results[0])
        await viewModel.pendingSelection?.value

        #expect(viewModel.recentRecords.map(\.symbolName) == ["r1", "r2", "r3", "r4", "r5"])
    }

    // MARK: - 도전 모드

    @Test func 도전을_시작하면_캔버스를_비우고_목표를_띄운다() async {
        let viewModel = makeViewModel(search: StubSearch(outcome: .results(results)))
        await viewModel.start()
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        viewModel.startChallenge(symbolName: "heart")

        #expect(viewModel.challengeTarget == "heart")
        #expect(viewModel.matches.isEmpty)
        #expect(viewModel.canvasResetCount == 1)

        viewModel.endChallenge()
        #expect(viewModel.challengeTarget == nil)
    }

    @Test func 목표를_골드로_달성하면_목표가_내려간다() async {
        let silver = SymbolBadge(symbolName: "s1", tier: .silver, bestSimilarity: 96, bestSketch: drawn, earnedAt: .now)
        var gold = silver
        gold.tier = .gold
        let badges = MutableBadges(["s1": silver])
        let viewModel = DrawViewModel(prepareIndex: StubPrepare(ready: true), searchSymbols: StubSearch(outcome: .results(results)),
                                      selectSymbol: StubSelect(), fetchRecent: StubRecent(), fetchBadges: badges, navigator: nil, debounce: .zero)
        await viewModel.refreshProgress()
        viewModel.startChallenge(symbolName: "s1")
        #expect(viewModel.challengeBadge?.tier == .silver)

        // 실버 그대로면 목표 유지
        viewModel.select(results[0])
        await viewModel.pendingSelection?.value
        #expect(viewModel.challengeTarget == "s1")

        badges.badges = ["s1": gold]
        viewModel.select(results[0])
        await viewModel.pendingSelection?.value
        #expect(viewModel.challengeTarget == nil)
    }

    @Test func 최근_칩을_고르면_당시_그림으로_상세를_연다() {
        let navigator = SpyNavigator()
        let viewModel = makeViewModel(search: StubSearch(outcome: .results([])), navigator: navigator)
        let record = FoundRecord(symbolName: "heart", sketch: drawn, similarity: 88, foundAt: .now)

        viewModel.selectRecent(record)

        #expect(navigator.shown == [SymbolDetailRequest(name: "heart", sketch: drawn, similarity: 88, isPastSketch: true)])
    }
}
