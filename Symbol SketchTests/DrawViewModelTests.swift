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

@MainActor
private final class SpyNavigator: DrawNavigating {
    var shown: [SymbolDetailRequest] = []
    func showSymbolDetail(_ request: SymbolDetailRequest) { shown.append(request) }
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
        skeletonDelay: Duration = .milliseconds(300)
    ) -> DrawViewModel {
        DrawViewModel(prepareIndex: StubPrepare(ready: ready), searchSymbols: search, navigator: navigator,
                      debounce: .zero, skeletonDelay: skeletonDelay)
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
        let viewModel = DrawViewModel(prepareIndex: prepare, searchSymbols: StubSearch(outcome: .results([])), navigator: nil, debounce: .zero)
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

    @Test func 뱃지_표시는_90퍼센트_이상() {
        let viewModel = makeViewModel(search: StubSearch(outcome: .results([])))
        #expect(viewModel.isBadgeEligible(SymbolMatch(name: "a", variants: [], similarity: 90)))
        #expect(!viewModel.isBadgeEligible(SymbolMatch(name: "a", variants: [], similarity: 89)))
    }
}
