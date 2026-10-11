//
//  DrawViewModel.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 그리기 화면(S1)과 결과 시트(S2)의 상태.
/// 획을 떼고 0.6초 뒤 자동 검색, 0.3초가 넘으면 스켈레톤, 그림 부족이면 검색하지 않는다(기획서 2.1, 6장).
@MainActor @Observable
final class DrawViewModel {
    /// 심볼 인덱스 준비 상태
    enum Preparation: Equatable {
        case checking
        case preparing(progress: Double)
        case ready
        case failed(String)
    }

    /// 검색 진행 상태. 결과(`matches`)와 따로 두어, 새로 찾는 동안 이전 결과를 계속 보여 준다.
    enum Phase: Equatable {
        case idle
        /// 획을 뗀 뒤 자동 검색을 기다리는 중("곧 찾아요")
        case waiting
        /// 검색 중. 0.3초가 넘으면 `showsSkeleton`
        case searching(showsSkeleton: Bool)
        case tooSmall
        case failed(String)
    }

    private(set) var preparation: Preparation = .checking
    private(set) var phase: Phase = .idle
    private(set) var matches: [SymbolMatch] = []
    /// 결과 시트를 펼쳤는지(Top 3 ↔ Top 10)
    var isSheetExpanded = false
    /// 값이 바뀌면 화면이 캔버스를 비운다.
    private(set) var canvasResetCount = 0
    private(set) var sketch: Sketch = .empty

    /// 진행 중인 자동 검색(테스트에서 끝나기를 기다릴 때 쓴다)
    private(set) var pendingSearch: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?

    private let prepareIndex: any PrepareSymbolIndexUseCase
    private let searchSymbols: any SearchSymbolsUseCase
    private weak var navigator: (any DrawNavigating)?
    private let debounce: Duration
    private let skeletonDelay: Duration

    static let resultLimit = 10
    static let previewCount = 3

    init(
        prepareIndex: any PrepareSymbolIndexUseCase,
        searchSymbols: any SearchSymbolsUseCase,
        navigator: (any DrawNavigating)?,
        debounce: Duration = .milliseconds(600),
        skeletonDelay: Duration = .milliseconds(300)
    ) {
        self.prepareIndex = prepareIndex
        self.searchSymbols = searchSymbols
        self.navigator = navigator
        self.debounce = debounce
        self.skeletonDelay = skeletonDelay
    }

    // MARK: - 표시용 값

    var isReady: Bool { preparation == .ready }
    var canSearch: Bool { isReady && !sketch.isEmpty }
    var previewMatches: [SymbolMatch] { Array(matches.prefix(Self.previewCount)) }

    /// 90% 이상이면 탭해서 뱃지를 받을 수 있다(기획서 3.1). 보유 여부는 M2에서 반영한다.
    func isBadgeEligible(_ match: SymbolMatch) -> Bool {
        match.similarity >= 90
    }

    // MARK: - 인덱스 준비

    /// 화면이 처음 나타날 때. 인덱스가 없으면 바로 만들기 시작한다.
    func start() async {
        guard preparationTask == nil, preparation != .ready else { return }
        if case .ready = await prepareIndex.status() {
            preparation = .ready
        } else {
            beginPreparation()
        }
    }

    /// 오류 상태의 "다시 준비하기"
    func retryPreparation() {
        beginPreparation()
    }

    private func beginPreparation() {
        guard preparationTask == nil else { return }
        preparation = .preparing(progress: 0)
        preparationTask = Task {
            do {
                for try await progress in prepareIndex.execute() {
                    preparation = .preparing(progress: progress)
                }
                preparation = .ready
                if !sketch.isEmpty { scheduleSearch(after: .zero) }
            } catch {
                preparation = .failed(error.localizedDescription)
            }
            preparationTask = nil
        }
    }

    // MARK: - 그리기·검색

    func sketchDidChange(_ sketch: Sketch) {
        self.sketch = sketch
        guard !sketch.isEmpty else {
            pendingSearch?.cancel()
            matches = []
            phase = .idle
            return
        }
        guard isReady else { return }
        phase = .waiting
        scheduleSearch(after: debounce)
    }

    /// "찾기" 버튼: 기다리지 않고 바로 찾는다.
    func searchNow() {
        guard canSearch else { return }
        scheduleSearch(after: .zero)
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
        guard canSearch else { return }
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
                phase = .idle
            }
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - 결과 선택·다시 그리기

    /// 결과 항목을 탭: 심볼 상세로 간다. (최근 기록 저장·뱃지 판정은 M2에서 이 자리에 붙는다)
    func select(_ match: SymbolMatch) {
        navigator?.showSymbolDetail(SymbolDetailRequest(name: match.name, sketch: sketch, similarity: match.similarity))
    }

    /// "다시 그리기": 캔버스를 비우고 시트를 접는다.
    func redraw() {
        clearCanvas()
        isSheetExpanded = false
    }

    /// 상세에서 뒤로 돌아오면 캔버스가 비워져 있다(기획서 5.1-4).
    func returnedFromDetail() {
        clearCanvas()
        isSheetExpanded = false
    }

    private func clearCanvas() {
        pendingSearch?.cancel()
        sketch = .empty
        matches = []
        phase = .idle
        canvasResetCount += 1
    }
}
