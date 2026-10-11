//
//  RecentViewModelTests.swift
//  Symbol SketchTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import Symbol_Sketch

/// 기록 저장소를 흉내 내는 가짜. 삭제·전체 삭제가 실제로 목록에서 빠지게 한다.
private final class FakeHistory: FetchRecentRecordsUseCase, DeleteRecordsUseCase, ClearHistoryUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [FoundRecord]
    var failure: Error?

    init(_ records: [FoundRecord]) { stored = records }

    var records: [FoundRecord] { lock.withLock { stored } }

    func execute(limit: Int?) async throws -> [FoundRecord] { records }

    func execute(ids: [UUID]) async throws {
        if let failure { throw failure }
        lock.withLock { stored.removeAll { ids.contains($0.id) } }
    }

    func execute() async throws {
        if let failure { throw failure }
        lock.withLock { stored = [] }
    }
}

private struct StubBadges: FetchBadgesUseCase {
    var badges: [String: SymbolBadge] = [:]
    func execute() async throws -> [String: SymbolBadge] { badges }
}

@MainActor
private final class SpyRecentNavigator: RecentNavigating {
    var shown: [SymbolDetailRequest] = []
    var wentToDraw = 0
    func showRecentDetail(_ request: SymbolDetailRequest) { shown.append(request) }
    func showDrawTab() { wentToDraw += 1 }
}

private struct SaveFailed: Error {}

@MainActor
struct RecentViewModelTests {
    /// 2026-10-14(수) 12:00 UTC
    private let now = Date(timeIntervalSince1970: 1_791_720_000 + 3 * 86_400)
    private let sketch = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private func record(_ name: String, daysAgo: Double) -> FoundRecord {
        FoundRecord(symbolName: name, sketch: sketch, similarity: 80, foundAt: now.addingTimeInterval(-daysAgo * 86_400))
    }

    private func makeViewModel(_ history: FakeHistory, badges: StubBadges = StubBadges(), navigator: SpyRecentNavigator? = nil) -> RecentViewModel {
        RecentViewModel(fetchRecent: history, deleteRecords: history, clearHistory: history, fetchBadges: badges,
                        navigator: navigator, now: { now }, calendar: calendar)
    }

    @Test func 날짜별로_묶는다() async {
        let viewModel = makeViewModel(FakeHistory([
            record("heart", daysAgo: 0), record("star", daysAgo: 1), record("bolt", daysAgo: 2), record("cloud", daysAgo: 10),
        ]))
        await viewModel.load()

        #expect(viewModel.sections.map(\.group) == [.today, .yesterday, .thisWeek, .earlier])
        #expect(viewModel.sections.map { $0.records.map(\.symbolName) } == [["heart"], ["star"], ["bolt"], ["cloud"]])
    }

    @Test func 이름으로_검색한다() async {
        let viewModel = makeViewModel(FakeHistory([record("heart.fill", daysAgo: 0), record("star", daysAgo: 0)]))
        await viewModel.load()

        viewModel.query = "HEART"
        #expect(viewModel.sections.flatMap(\.records).map(\.symbolName) == ["heart.fill"])

        viewModel.query = "zzz"
        #expect(viewModel.hasNoSearchResults)
        #expect(!viewModel.hasNoHistory)
    }

    @Test func 밀어서_삭제하면_목록과_저장소에서_빠진다() async {
        let heart = record("heart", daysAgo: 0)
        let history = FakeHistory([heart, record("star", daysAgo: 0)])
        let viewModel = makeViewModel(history)
        await viewModel.load()

        await viewModel.delete(heart)

        #expect(viewModel.records.map(\.symbolName) == ["star"])
        #expect(history.records.map(\.symbolName) == ["star"])
    }

    @Test func 삭제에_실패하면_다시_읽어_되돌린다() async {
        let heart = record("heart", daysAgo: 0)
        let history = FakeHistory([heart])
        history.failure = SaveFailed()
        let viewModel = makeViewModel(history)
        await viewModel.load()

        await viewModel.delete(heart)

        #expect(viewModel.records.map(\.symbolName) == ["heart"])
    }

    @Test func 전체_삭제는_확인_후에만_지우고_빈_상태가_된다() async {
        let history = FakeHistory([record("heart", daysAgo: 0)])
        let viewModel = makeViewModel(history)
        await viewModel.load()

        viewModel.requestClearAll()
        #expect(viewModel.isConfirmingClear)
        #expect(history.records.count == 1)

        await viewModel.confirmClearAll()
        #expect(!viewModel.isConfirmingClear)
        #expect(history.records.isEmpty)
        #expect(viewModel.hasNoHistory)
    }

    @Test func 행을_고르면_당시_그림으로_상세를_열고_빈_상태에서는_그리기로() async {
        let navigator = SpyRecentNavigator()
        let heart = record("heart", daysAgo: 0)
        let viewModel = makeViewModel(FakeHistory([heart]), navigator: navigator)

        viewModel.select(heart)
        viewModel.goDraw()

        #expect(navigator.shown == [SymbolDetailRequest(name: "heart", sketch: sketch, similarity: 80, isPastSketch: true)])
        #expect(navigator.wentToDraw == 1)
    }

    @Test func 뱃지가_있으면_행에_등급을_보여준다() async {
        let badge = SymbolBadge(symbolName: "heart", tier: .gold, bestSimilarity: 99, bestSketch: sketch, earnedAt: now)
        let viewModel = makeViewModel(FakeHistory([record("heart", daysAgo: 0), record("star", daysAgo: 0)]), badges: StubBadges(badges: ["heart": badge]))
        await viewModel.load()

        #expect(viewModel.badge(for: viewModel.records[0])?.tier == .gold)
        #expect(viewModel.badge(for: viewModel.records[1]) == nil)
    }
}
