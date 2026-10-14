//
//  OnboardingViewModel.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import Foundation
import Domain

/// 온보딩(S0): 소개 3장 → 하트 연습 → 결과 탭 → 첫 번째 획 업적 → 그리기 홈(기획서 5장 1).
/// 심볼 준비는 그리기 화면과 같은 `SymbolIndexPreparation`을 쓴다. 온보딩을 보는 동안 뒤에서 진행된다.
@MainActor @Observable
final class OnboardingViewModel {
    enum Step: Equatable {
        /// 소개 장(0부터)
        case intro(Int)
        case practice
    }

    /// 연습 그리기 아래 영역 상태
    enum PracticePhase: Equatable {
        case idle
        /// 그렸지만 심볼 준비가 아직 안 끝남("심볼 준비가 끝나면 바로 찾을게요")
        case waitingForIndex
        /// 획을 뗀 뒤 자동 검색을 기다림
        case waiting
        case searching(showsSkeleton: Bool)
        case tooSmall
        case results
        case failed(String)
    }

    static let introCount = 3
    static let resultLimit = 3

    private(set) var step: Step = .intro(0)
    private(set) var phase: PracticePhase = .idle
    private(set) var matches: [SymbolMatch] = []
    private(set) var sketch: Sketch = .empty

    let indexPreparation: SymbolIndexPreparation
    /// 진행 중인 자동 검색·선택(테스트에서 끝나기를 기다릴 때 쓴다)
    private(set) var pendingSearch: Task<Void, Never>?
    private(set) var pendingSelection: Task<Void, Never>?

    private let searchSymbols: any SearchSymbolsUseCase
    private let selectSymbol: any SelectSymbolUseCase
    private weak var navigator: (any OnboardingNavigating)?
    private let now: () -> Date
    private let debounce: Duration
    private let skeletonDelay: Duration

    init(
        indexPreparation: SymbolIndexPreparation,
        searchSymbols: any SearchSymbolsUseCase,
        selectSymbol: any SelectSymbolUseCase,
        navigator: (any OnboardingNavigating)?,
        now: @escaping () -> Date = Date.init,
        debounce: Duration = .milliseconds(600),
        skeletonDelay: Duration = .milliseconds(300)
    ) {
        self.indexPreparation = indexPreparation
        self.searchSymbols = searchSymbols
        self.selectSymbol = selectSymbol
        self.navigator = navigator
        self.now = now
        self.debounce = debounce
        self.skeletonDelay = skeletonDelay
        // 준비 전에 그려 둔 그림은 준비가 끝나자마자 찾는다.
        indexPreparation.onReady { [weak self] in
            guard let self, self.step == .practice, !self.sketch.isEmpty else { return }
            self.scheduleSearch(after: .zero)
        }
    }

    // MARK: - 소개

    var introIndex: Int {
        if case .intro(let index) = step { index } else { Self.introCount - 1 }
    }

    var isLastIntro: Bool { introIndex == Self.introCount - 1 }

    /// 온보딩이 화면에 나타날 때: 심볼 준비를 시작한다(이미 준비됐으면 바로 끝남).
    func start() async {
        await indexPreparation.start()
    }

    /// 넘겨 보기(밀기)
    func showIntro(_ index: Int) {
        guard case .intro = step else { return }
        step = .intro(min(max(index, 0), Self.introCount - 1))
    }

    /// "다음" / 마지막 장 "연습해 보기"
    func next() {
        guard case .intro(let index) = step else { return }
        step = index + 1 < Self.introCount ? .intro(index + 1) : .practice
    }

    /// "건너뛰기" · "나중에 할게요"
    func skip() {
        pendingSearch?.cancel()
        navigator?.finishOnboarding(celebration: nil)
    }

    // MARK: - 연습 그리기

    func sketchDidChange(_ sketch: Sketch) {
        self.sketch = sketch
        pendingSearch?.cancel()
        guard !sketch.isEmpty else {
            matches = []
            phase = .idle
            return
        }
        guard indexPreparation.isReady else {
            phase = .waitingForIndex
            return
        }
        phase = .waiting
        scheduleSearch(after: debounce)
    }

    /// 결과를 탭: 기록을 저장하고(첫 번째 획 업적) 그리기 홈으로 간다.
    func select(_ match: SymbolMatch) {
        guard pendingSelection == nil else { return }
        let sketch = sketch
        pendingSelection = Task {
            let outcome = try? await selectSymbol.execute(match: match, sketch: sketch, now: now())
            navigator?.finishOnboarding(celebration: outcome.flatMap { Celebration(outcome: $0, sketch: sketch) })
        }
    }

    private func scheduleSearch(after delay: Duration) {
        pendingSearch?.cancel()
        pendingSearch = Task {
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    private func search() async {
        guard indexPreparation.isReady, !sketch.isEmpty else { return }
        phase = .searching(showsSkeleton: false)
        let skeleton = Task {
            try? await Task.sleep(for: skeletonDelay)
            if !Task.isCancelled, phase == .searching(showsSkeleton: false) {
                phase = .searching(showsSkeleton: true)
            }
        }
        defer { skeleton.cancel() }

        do {
            let outcome = try await searchSymbols.execute(sketch: sketch, limit: Self.resultLimit)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .empty:
                matches = []
                phase = .idle
            case .tooSmall:
                matches = []
                phase = .tooSmall
            case .results(let results):
                matches = results
                phase = results.isEmpty ? .idle : .results
            }
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }
}
