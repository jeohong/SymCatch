//
//  RecognitionLabViewModel.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 인식 실험에서 고를 수 있는 방식 하나. App이 Recognition 구현을 감싸 UseCase로 넘긴다.
struct RecognitionEngineOption: Identifiable {
    let id: String
    let title: String
    let detail: String
    let prepare: any PrepareSymbolIndexUseCase
    let search: any SearchSymbolsUseCase
    /// 보정 전 원시 점수(평가 실행용)
    let scorer: any SymbolScoring
    /// 지금 쓰는 보정값
    let calibrator: ScoreCalibrator
}

/// 개발용 인식 실험: 그리면 바로 Top 10을 보여 주고, 방식을 바꿔 가며 비교한다.
@MainActor @Observable
final class RecognitionLabViewModel {
    enum Preparation: Equatable {
        case unknown
        case notReady
        case preparing(progress: Double)
        case ready(seconds: Double?)
        case failed(String)
    }

    enum SearchState: Equatable {
        case idle
        case notPrepared
        case tooSmall
        case searching
        case results([SymbolMatch], milliseconds: Int)
        case failed(String)
    }

    let options: [RecognitionEngineOption]
    private(set) var selectedID: String
    private(set) var preparations: [String: Preparation] = [:]
    private(set) var searchState: SearchState = .idle
    /// 진행 중인 자동 검색(테스트에서 끝나기를 기다릴 때 쓴다)
    private(set) var pendingSearch: Task<Void, Never>?

    private var sketch: Sketch = .empty
    private var prepareTasks: [String: Task<Void, Never>] = [:]
    private let debounce: Duration
    private let clock = ContinuousClock()

    /// - Parameter debounce: 획을 뗀 뒤 자동 검색까지 기다리는 시간(기획서 2.1: 0.6초)
    init(options: [RecognitionEngineOption], debounce: Duration = .milliseconds(600)) {
        precondition(!options.isEmpty, "방식이 하나 이상 있어야 한다")
        self.options = options
        self.selectedID = options[0].id
        self.debounce = debounce
    }

    var selected: RecognitionEngineOption {
        options.first { $0.id == selectedID } ?? options[0]
    }

    var selectedPreparation: Preparation {
        preparations[selectedID] ?? .unknown
    }

    func load() async {
        for option in options {
            if case .preparing = preparations[option.id] { continue }
            preparations[option.id] = Self.preparation(for: await option.prepare.status())
        }
    }

    func select(_ id: String) {
        guard id != selectedID, options.contains(where: { $0.id == id }) else { return }
        selectedID = id
        scheduleSearch(after: .zero)
    }

    /// 선택한 방식의 인덱스를 만든다. 다른 방식을 고른 뒤에도 끝까지 진행된다.
    func prepareSelected() {
        let option = selected
        guard prepareTasks[option.id] == nil else { return }
        preparations[option.id] = .preparing(progress: 0)
        let started = clock.now
        prepareTasks[option.id] = Task {
            do {
                for try await progress in option.prepare.execute() {
                    preparations[option.id] = .preparing(progress: progress)
                }
                preparations[option.id] = .ready(seconds: started.duration(to: clock.now) / .seconds(1))
                if option.id == selectedID { scheduleSearch(after: .zero) }
            } catch {
                preparations[option.id] = .failed(error.localizedDescription)
            }
            prepareTasks[option.id] = nil
        }
    }

    func sketchDidChange(_ sketch: Sketch) {
        self.sketch = sketch
        scheduleSearch(after: debounce)
    }

    /// "찾기" 버튼: 기다리지 않고 바로 검색한다.
    func searchNow() {
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
        guard !sketch.isEmpty else {
            searchState = .idle
            return
        }
        guard case .ready = selectedPreparation else {
            searchState = .notPrepared
            return
        }
        searchState = .searching
        let started = clock.now
        do {
            let outcome = try await selected.search.execute(sketch: sketch, limit: 10)
            guard !Task.isCancelled else { return }
            let milliseconds = Int(started.duration(to: clock.now) / .milliseconds(1))
            switch outcome {
            case .empty: searchState = .idle
            case .tooSmall: searchState = .tooSmall
            case .results(let matches): searchState = .results(matches, milliseconds: milliseconds)
            }
        } catch {
            guard !Task.isCancelled else { return }
            searchState = .failed(error.localizedDescription)
        }
    }

    private static func preparation(for status: SymbolIndexStatus) -> Preparation {
        switch status {
        case .ready: .ready(seconds: nil)
        case .missing, .outdated, .corrupted: .notReady
        }
    }
}
