//
//  OnboardingViewModelTests.swift
//  Symbol SketchTests
//
//  Created by Hongjeongmin on 10/14/26.
//

import Foundation
import Observation
import Testing
import Domain
@testable import Symbol_Sketch

/// 준비를 테스트가 직접 끝내는 가짜(온보딩을 보는 동안 준비가 진행되는 상황 재현)
private final class ControlledPrepare: PrepareSymbolIndexUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var ready = false
    private var continuation: AsyncThrowingStream<Double, Error>.Continuation?

    func status() async -> SymbolIndexStatus {
        lock.withLock { ready } ? .ready(symbolCount: 8_092) : .missing
    }

    func execute() -> AsyncThrowingStream<Double, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(0.3)
            lock.withLock { self.continuation = continuation }
        }
    }

    func finish() {
        let continuation = lock.withLock { ready = true; return self.continuation }
        continuation?.yield(1)
        continuation?.finish()
    }
}

private final class StubSearch: SearchSymbolsUseCase, @unchecked Sendable {
    var outcome: SearchOutcome
    init(outcome: SearchOutcome) { self.outcome = outcome }
    func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome { outcome }
}

private final class StubSelect: SelectSymbolUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var names: [String] = []
    var selected: [String] { lock.withLock { names } }
    func execute(match: SymbolMatch, sketch: Sketch, now: Date) async throws -> SelectionOutcome {
        lock.withLock { names.append(match.name) }
        return SelectionOutcome(record: FoundRecord(symbolName: match.name, sketch: sketch, similarity: match.similarity, foundAt: now),
                                badgeAward: .none, newAchievements: [Achievement(id: .firstStroke, progress: 1, unlockedAt: now)])
    }
}

@MainActor
private final class SpyOnboardingNavigator: OnboardingNavigating {
    var finished: [Celebration?] = []
    func finishOnboarding(celebration: Celebration?) { finished.append(celebration) }
}

@MainActor
struct OnboardingViewModelTests {
    private let heart = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])
    private let results = [SymbolMatch(name: "heart", variants: ["heart.fill"], similarity: 92),
                           SymbolMatch(name: "suit.heart", variants: [], similarity: 80)]

    private func makeViewModel(prepare: ControlledPrepare = ControlledPrepare(), search: StubSearch? = nil,
                               select: StubSelect = StubSelect(), navigator: SpyOnboardingNavigator? = nil) -> OnboardingViewModel {
        OnboardingViewModel(indexPreparation: SymbolIndexPreparation(prepareIndex: prepare),
                            searchSymbols: search ?? StubSearch(outcome: .results(results)), selectSymbol: select,
                            navigator: navigator, debounce: .zero, skeletonDelay: .seconds(10))
    }

    /// 조건이 맞을 때까지 최대 2초 기다린다.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func 소개_3장을_넘기면_연습으로() {
        let viewModel = makeViewModel()
        #expect(viewModel.step == .intro(0))
        viewModel.next()
        viewModel.next()
        #expect(viewModel.isLastIntro)
        viewModel.next()
        #expect(viewModel.step == .practice)

        let swiping = makeViewModel()
        swiping.showIntro(5)
        #expect(swiping.step == .intro(2))
    }

    @Test func 건너뛰면_축하_없이_끝난다() {
        let navigator = SpyOnboardingNavigator()
        makeViewModel(navigator: navigator).skip()
        #expect(navigator.finished.count == 1)
        #expect(navigator.finished.first! == nil)
    }

    @Test func 준비_전에_그리면_기다렸다가_준비가_끝나면_바로_찾는다() async {
        let prepare = ControlledPrepare()
        let viewModel = makeViewModel(prepare: prepare)
        await viewModel.start()
        for _ in 0..<3 { viewModel.next() }

        viewModel.sketchDidChange(heart)
        #expect(viewModel.phase == .waitingForIndex)

        // 준비가 실제로 시작된(진행률 30%를 받은) 뒤에 끝낸다.
        await waitUntil { viewModel.indexPreparation.state == .preparing(progress: 0.3) }
        prepare.finish()
        await waitUntil { viewModel.phase == .results }
        #expect(viewModel.phase == .results)
        #expect(viewModel.matches.map(\.name) == ["heart", "suit.heart"])
        #expect(viewModel.indexPreparation.symbolCount == 8_092)
    }

    @Test func 그림이_부족하면_안내하고_지우면_처음으로() async {
        let prepare = ControlledPrepare()
        prepare.finish()
        let viewModel = makeViewModel(prepare: prepare, search: StubSearch(outcome: .tooSmall))
        await viewModel.start()
        for _ in 0..<3 { viewModel.next() }

        viewModel.sketchDidChange(heart)
        await viewModel.pendingSearch?.value
        #expect(viewModel.phase == .tooSmall)

        viewModel.sketchDidChange(.empty)
        #expect(viewModel.phase == .idle)
    }

    @Test func 결과를_고르면_기록하고_첫_번째_획을_축하하며_끝난다() async {
        let prepare = ControlledPrepare()
        prepare.finish()
        let select = StubSelect()
        let navigator = SpyOnboardingNavigator()
        let viewModel = makeViewModel(prepare: prepare, select: select, navigator: navigator)
        await viewModel.start()
        for _ in 0..<3 { viewModel.next() }
        viewModel.sketchDidChange(heart)
        await viewModel.pendingSearch?.value

        viewModel.select(results[0])
        viewModel.select(results[1])          // 두 번 눌러도 한 번만
        await viewModel.pendingSelection?.value

        #expect(select.selected == ["heart"])
        #expect(navigator.finished.count == 1)
        let cards = navigator.finished.first??.cards ?? []
        #expect(cards.count == 1)
        guard case .achievement(let id, _) = cards.first else {
            Issue.record("첫 번째 획 업적 카드여야 한다: \(cards)")
            return
        }
        #expect(id == .firstStroke)
    }
}

@MainActor
struct AppRouterOnboardingTests {
    private func defaults() -> UserDefaults {
        let suite = "onboarding-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func 처음이면_온보딩을_띄우고_끝내면_다시_띄우지_않는다() {
        let store = defaults()
        let router = AppRouter(defaults: store)
        #expect(router.isOnboardingPresented)

        router.selectedTab = .collection
        router.finishOnboarding(celebration: nil)
        #expect(!router.isOnboardingPresented)
        #expect(router.selectedTab == .draw)
        #expect(!AppRouter(defaults: store).isOnboardingPresented)
    }

    @Test func 축하할_것이_있으면_그리기_홈_위에_띄운다() {
        let date = Date(timeIntervalSince1970: 1_791_720_000)
        let outcome = SelectionOutcome(record: FoundRecord(symbolName: "heart", sketch: .empty, similarity: 70, foundAt: date),
                                       badgeAward: .none, newAchievements: [Achievement(id: .firstStroke, progress: 1, unlockedAt: date)])
        let router = AppRouter(defaults: defaults())
        router.finishOnboarding(celebration: Celebration(outcome: outcome, sketch: .empty))
        #expect(router.celebration?.cards == [.achievement(.firstStroke, unlockedAt: date)])
    }

    @Test func 테스트_인자로_끄거나_켤_수_있다() {
        #expect(!AppRouter(showsOnboarding: false, defaults: defaults()).isOnboardingPresented)
        let store = defaults()
        store.set(true, forKey: AppRouter.onboardingCompletedKey)
        #expect(AppRouter(showsOnboarding: true, defaults: store).isOnboardingPresented)
    }
}

@MainActor
struct SymbolIndexPreparationTests {
    /// 테마를 바꾸면 앱이 멈췄던 문제(10-14)의 회귀 테스트: 화면이 준비 상태를 지켜보는 중에
    /// ViewModel이 "준비 끝나면 알려 줘"를 등록해도 화면 갱신이 일어나면 안 된다.
    @Test func 준비_완료_알림을_등록해도_화면_갱신이_일어나지_않는다() {
        let preparation = SymbolIndexPreparation(prepareIndex: ControlledPrepare())
        let changed = Box()
        withObservationTracking {
            _ = preparation.state
            preparation.onReady {}
        } onChange: {
            changed.value = true
        }
        preparation.onReady {}
        #expect(!changed.value)
    }

    /// 이미 준비된 인덱스여도, 상태를 확인하는 사이에 걸어 둔 "준비 끝나면" 알림은 불려야 한다.
    @Test func 이미_준비돼_있어도_준비_완료_알림을_보낸다() async {
        let prepare = ControlledPrepare()
        prepare.finish()   // 이미 준비된 상태
        let preparation = SymbolIndexPreparation(prepareIndex: prepare)
        let called = Box()
        preparation.onReady { called.value = true }

        await preparation.start()

        #expect(preparation.state == .ready)
        #expect(called.value)
    }
}

private final class Box: @unchecked Sendable {
    var value = false
}
