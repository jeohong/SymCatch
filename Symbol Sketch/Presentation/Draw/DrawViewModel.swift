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
    /// 홈 상단 최근 찾은 심볼(최대 5개)
    private(set) var recentRecords: [FoundRecord] = []
    /// 보유 뱃지(심볼 이름 → 뱃지). 결과 행의 "보유 중" 표시에 쓴다.
    private(set) var badges: [String: SymbolBadge] = [:]

    /// 진행 중인 자동 검색(테스트에서 끝나기를 기다릴 때 쓴다)
    private(set) var pendingSearch: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    /// 결과 탭 후 저장 중인 작업(테스트에서 끝나기를 기다릴 때 쓴다)
    private(set) var pendingSelection: Task<Void, Never>?

    private let prepareIndex: any PrepareSymbolIndexUseCase
    private let searchSymbols: any SearchSymbolsUseCase
    private let selectSymbol: any SelectSymbolUseCase
    private let fetchRecent: any FetchRecentRecordsUseCase
    private let fetchBadges: any FetchBadgesUseCase
    private weak var navigator: (any DrawNavigating)?
    private let now: () -> Date
    private let debounce: Duration
    private let skeletonDelay: Duration

    static let resultLimit = 10
    static let previewCount = 3
    static let recentCount = 5

    init(
        prepareIndex: any PrepareSymbolIndexUseCase,
        searchSymbols: any SearchSymbolsUseCase,
        selectSymbol: any SelectSymbolUseCase,
        fetchRecent: any FetchRecentRecordsUseCase,
        fetchBadges: any FetchBadgesUseCase,
        navigator: (any DrawNavigating)?,
        now: @escaping () -> Date = Date.init,
        debounce: Duration = .milliseconds(600),
        skeletonDelay: Duration = .milliseconds(300)
    ) {
        self.prepareIndex = prepareIndex
        self.searchSymbols = searchSymbols
        self.selectSymbol = selectSymbol
        self.fetchRecent = fetchRecent
        self.fetchBadges = fetchBadges
        self.navigator = navigator
        self.now = now
        self.debounce = debounce
        self.skeletonDelay = skeletonDelay
    }

    // MARK: - 표시용 값

    var isReady: Bool { preparation == .ready }
    var canSearch: Bool { isReady && !sketch.isEmpty }
    var previewMatches: [SymbolMatch] { Array(matches.prefix(Self.previewCount)) }

    /// 결과 행의 뱃지 안내. 이미 받은 등급 이상이면 "보유 중"(기획서 3.1).
    func badgeHint(for match: SymbolMatch) -> BadgeHint {
        BadgeHint.evaluate(match, owned: badges[match.name])
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

    // MARK: - 최근 기록·뱃지

    /// 화면이 보일 때마다: 다른 탭에서 기록을 지웠을 수 있으므로 다시 읽는다.
    func refreshProgress() async {
        do {
            recentRecords = try await fetchRecent.execute(limit: Self.recentCount)
            badges = try await fetchBadges.execute()
        } catch {
            // 표시용이라 실패해도 그리기는 계속할 수 있다. 다음에 화면이 보일 때 다시 읽는다.
        }
    }

    /// 상단 최근 칩을 탭: 당시 그림과 함께 상세로 간다.
    func selectRecent(_ record: FoundRecord) {
        navigator?.showSymbolDetail(SymbolDetailRequest(name: record.symbolName, sketch: record.sketch, similarity: record.similarity, isPastSketch: true))
    }

    // MARK: - 결과 선택·다시 그리기

    /// 결과 항목을 탭 = "찾았다"(기획서 2.2, 5.1-3).
    /// 상세로 바로 가고, 그 사이 기록을 저장한다. 새 뱃지·승급·업적이 있으면 상세 위에 축하 모달을 띄운다.
    func select(_ match: SymbolMatch) {
        let sketch = sketch
        navigator?.showSymbolDetail(SymbolDetailRequest(name: match.name, sketch: sketch, similarity: match.similarity))
        pendingSelection = Task {
            do {
                let outcome = try await selectSymbol.execute(match: match, sketch: sketch, now: now())
                if let celebration = Celebration(outcome: outcome, sketch: sketch) {
                    navigator?.showCelebration(celebration)
                }
            } catch {
                // 저장에 실패해도 상세 화면은 그대로 쓸 수 있다. 다음 선택 때 다시 저장된다.
            }
            await refreshProgress()
        }
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
