//
//  EvaluationCollectionViewModel.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 개발용 수집 모드: 심볼 이름을 보고 기억으로 그린 그림을 평가셋으로 모은다(기획서 9.4).
@MainActor @Observable
final class EvaluationCollectionViewModel {
    enum Feedback: Equatable {
        case saved
        case tooSmall
        /// 가져오기로 새로 추가한 그림 수
        case imported(Int)
        case failed(String)
    }

    /// 지금 그릴 심볼. 모두 다 그렸으면 nil.
    private(set) var target: String?
    private(set) var progress: EvaluationProgress = .empty
    private(set) var feedback: Feedback?
    private(set) var exportedFile: URL?
    private(set) var isBusy = false
    /// 값이 바뀌면 화면이 캔버스를 비운다.
    private(set) var canvasResetCount = 0
    /// 정답 심볼 모양을 보여 줄지(기본은 숨김: 기억으로 그리기)
    var isHintVisible = false

    private(set) var sketch: Sketch = .empty
    private var skipped: Set<String> = []

    private let loadProgress: any LoadEvaluationProgressUseCase
    private let saveSample: any SaveEvaluationSampleUseCase
    private let exportSamples: any ExportEvaluationSamplesUseCase
    private let importSamples: any ImportEvaluationSamplesUseCase
    private let now: () -> Date

    init(
        loadProgress: any LoadEvaluationProgressUseCase,
        saveSample: any SaveEvaluationSampleUseCase,
        exportSamples: any ExportEvaluationSamplesUseCase,
        importSamples: any ImportEvaluationSamplesUseCase,
        now: @escaping () -> Date = Date.init
    ) {
        self.loadProgress = loadProgress
        self.saveSample = saveSample
        self.exportSamples = exportSamples
        self.importSamples = importSamples
        self.now = now
    }

    var canSave: Bool { target != nil && !sketch.isEmpty && !isBusy }

    func load(author: String) async {
        await refresh(author: author)
    }

    func sketchDidChange(_ sketch: Sketch) {
        self.sketch = sketch
        if feedback == .tooSmall { feedback = nil }
    }

    func save(author: String) async {
        guard let target, canSave else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await saveSample.execute(symbolName: target, sketch: sketch, author: author, now: now())
            feedback = .saved
            skipped = []
            resetCanvas()
            await refresh(author: author)
        } catch SaveEvaluationSampleError.sketchTooSmall {
            feedback = .tooSmall
        } catch {
            feedback = .failed(error.localizedDescription)
        }
    }

    func skip() {
        guard let target else { return }
        skipped.insert(target)
        self.target = EvaluationTargetPicker.next(counts: progress.countsByTarget, excluding: skipped)
        feedback = nil
        resetCanvas()
    }

    func export() async {
        isBusy = true
        defer { isBusy = false }
        do {
            exportedFile = try await exportSamples.execute()
        } catch {
            feedback = .failed(error.localizedDescription)
        }
    }

    /// 내보냈던 파일(.json)을 다시 들인다. 파일 앱에서 고른 파일은 접근 권한을 잠깐 열어야 읽을 수 있다.
    func importArchive(from url: URL, author: String) async {
        isBusy = true
        defer { isBusy = false }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            feedback = .imported(try await importSamples.execute(from: url))
            skipped = []
            await refresh(author: author)
        } catch {
            feedback = .failed(String(localized: "가져오지 못했어요: \(error.localizedDescription)"))
        }
    }

    func authorDidChange(_ author: String) async {
        skipped = []
        await refresh(author: author)
    }

    private func refresh(author: String) async {
        do {
            progress = try await loadProgress.execute(author: author)
            target = EvaluationTargetPicker.next(counts: progress.countsByTarget, excluding: skipped)
        } catch {
            feedback = .failed(error.localizedDescription)
        }
    }

    private func resetCanvas() {
        sketch = .empty
        isHintVisible = false
        canvasResetCount += 1
    }
}
