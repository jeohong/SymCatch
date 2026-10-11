//
//  RecognitionLabViewModelTests.swift
//  Symbol SketchTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import Symbol_Sketch

private final class FakePrepare: PrepareSymbolIndexUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var ready: Bool

    init(ready: Bool) { self.ready = ready }

    func status() async -> SymbolIndexStatus {
        lock.withLock { ready } ? .ready(symbolCount: 1) : .missing
    }

    func execute() -> AsyncThrowingStream<Double, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(0.5)
            lock.withLock { ready = true }
            continuation.yield(1)
            continuation.finish()
        }
    }
}

private final class FakeSearch: SearchSymbolsUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    let outcome: SearchOutcome

    init(outcome: SearchOutcome) { self.outcome = outcome }

    var callCount: Int { lock.withLock { calls } }

    func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome {
        lock.withLock { calls += 1 }
        return outcome
    }
}

@MainActor
struct RecognitionLabViewModelTests {
    private let drawn = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])
    private let heart = SymbolMatch(name: "heart", variants: [], similarity: 90, score: 0.9)

    private func option(_ id: String, ready: Bool, search: FakeSearch) -> RecognitionEngineOption {
        RecognitionEngineOption(id: id, title: id, detail: "", prepare: FakePrepare(ready: ready), search: search)
    }

    @Test func 준비되지_않은_방식은_검색하지_않고_안내한다() async {
        let search = FakeSearch(outcome: .results([heart]))
        let viewModel = RecognitionLabViewModel(options: [option("a", ready: false, search: search)], debounce: .zero)
        await viewModel.load()

        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        #expect(viewModel.selectedPreparation == .notReady)
        #expect(viewModel.searchState == .notPrepared)
        #expect(search.callCount == 0)
    }

    @Test func 준비된_방식은_그리면_자동으로_검색한다() async {
        let search = FakeSearch(outcome: .results([heart]))
        let viewModel = RecognitionLabViewModel(options: [option("a", ready: true, search: search)], debounce: .zero)
        await viewModel.load()

        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        guard case .results(let matches, _) = viewModel.searchState else {
            Issue.record("결과 상태여야 한다: \(viewModel.searchState)")
            return
        }
        #expect(matches == [heart])
    }

    @Test func 연달아_그리면_마지막_한_번만_검색한다() async {
        let search = FakeSearch(outcome: .results([heart]))
        let viewModel = RecognitionLabViewModel(options: [option("a", ready: true, search: search)], debounce: .milliseconds(200))
        await viewModel.load()

        viewModel.sketchDidChange(drawn)
        viewModel.sketchDidChange(drawn)
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        #expect(search.callCount == 1)
    }

    @Test func 준비하면_준비됨으로_바뀌고_그린_그림을_검색한다() async {
        let search = FakeSearch(outcome: .results([heart]))
        let viewModel = RecognitionLabViewModel(options: [option("a", ready: false, search: search)], debounce: .zero)
        await viewModel.load()
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        viewModel.prepareSelected()
        while case .preparing = viewModel.selectedPreparation { await Task.yield() }
        await viewModel.pendingSearch?.value

        guard case .ready = viewModel.selectedPreparation else {
            Issue.record("준비됨이어야 한다: \(viewModel.selectedPreparation)")
            return
        }
        #expect(search.callCount == 1)
    }

    @Test func 그림이_작으면_tooSmall() async {
        let search = FakeSearch(outcome: .tooSmall)
        let viewModel = RecognitionLabViewModel(options: [option("a", ready: true, search: search)], debounce: .zero)
        await viewModel.load()

        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        #expect(viewModel.searchState == .tooSmall)
    }

    @Test func 방식을_바꾸면_새_방식으로_다시_검색한다() async {
        let first = FakeSearch(outcome: .results([heart]))
        let second = FakeSearch(outcome: .results([]))
        let viewModel = RecognitionLabViewModel(
            options: [option("a", ready: true, search: first), option("b", ready: true, search: second)],
            debounce: .zero
        )
        await viewModel.load()
        viewModel.sketchDidChange(drawn)
        await viewModel.pendingSearch?.value

        viewModel.select("b")
        await viewModel.pendingSearch?.value

        #expect(viewModel.selectedID == "b")
        #expect(second.callCount == 1)
    }
}
