//
//  EvaluationCollectionViewModelTests.swift
//  Symbol SketchTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import Symbol_Sketch

@MainActor
private final class FakeEvaluationUseCases: LoadEvaluationProgressUseCase, SaveEvaluationSampleUseCase, ExportEvaluationSamplesUseCase,
                                           ImportEvaluationSamplesUseCase, @unchecked Sendable {
    var counts: [String: Int] = [:]
    var saved: [(symbol: String, author: String)] = []
    var saveError: Error?

    nonisolated func execute(author: String) async throws -> EvaluationProgress {
        let counts = await MainActor.run { self.counts }
        return EvaluationProgress(countsByTarget: counts, authorTotal: counts.values.reduce(0, +), overallTotal: 0, authorGoal: 300)
    }

    nonisolated func execute(symbolName: String, sketch: Sketch, author: String, now: Date) async throws {
        try await MainActor.run {
            if let saveError { throw saveError }
            saved.append((symbolName, author))
            counts[symbolName, default: 0] += 1
        }
    }

    nonisolated func execute() async throws -> URL { URL(fileURLWithPath: "/tmp/export.json") }

    /// 가져오기: heart 2장을 들인 것으로 친다.
    var importError: Error?
    nonisolated func execute(from url: URL) async throws -> Int {
        try await MainActor.run {
            if let importError { throw importError }
            counts["heart", default: 0] += 2
            return 2
        }
    }
}

@MainActor
struct EvaluationCollectionViewModelTests {
    private let drawn = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])

    private func makeViewModel(_ fake: FakeEvaluationUseCases) -> EvaluationCollectionViewModel {
        EvaluationCollectionViewModel(loadProgress: fake, saveSample: fake, exportSamples: fake, importSamples: fake)
    }

    @Test func 가져오면_장수를_알려주고_진행을_다시_읽는다() async {
        let fake = FakeEvaluationUseCases()
        let viewModel = makeViewModel(fake)
        await viewModel.load(author: "chikong")

        await viewModel.importArchive(from: URL(fileURLWithPath: "/tmp/eval.json"), author: "chikong")

        #expect(viewModel.feedback == .imported(2))
        #expect(viewModel.progress.countsByTarget["heart"] == 2)
        #expect(!viewModel.isBusy)
    }

    @Test func 가져오기에_실패하면_알려준다() async {
        let fake = FakeEvaluationUseCases()
        fake.importError = CocoaError(.fileReadCorruptFile)
        let viewModel = makeViewModel(fake)

        await viewModel.importArchive(from: URL(fileURLWithPath: "/tmp/eval.json"), author: "chikong")

        guard case .failed = viewModel.feedback else {
            Issue.record("실패를 알려야 한다: \(String(describing: viewModel.feedback))")
            return
        }
    }

    @Test func 처음에는_그린_수가_가장_적은_첫_대표_심볼을_보여준다() async {
        let viewModel = makeViewModel(FakeEvaluationUseCases())
        await viewModel.load(author: "작성자A")
        #expect(viewModel.target == EvaluationTargetPicker.representativeSymbols.first)
    }

    @Test func 저장하면_다음_심볼로_넘어가고_캔버스를_비운다() async {
        let fake = FakeEvaluationUseCases()
        let viewModel = makeViewModel(fake)
        await viewModel.load(author: "작성자A")
        let first = viewModel.target

        viewModel.sketchDidChange(drawn)
        await viewModel.save(author: "작성자A")

        #expect(fake.saved.map(\.symbol) == [first])
        #expect(viewModel.feedback == .saved)
        #expect(viewModel.target != first)
        #expect(viewModel.canvasResetCount == 1)
        #expect(!viewModel.canSave)
    }

    @Test func 그림이_작으면_저장하지_않고_안내한다() async {
        let fake = FakeEvaluationUseCases()
        fake.saveError = SaveEvaluationSampleError.sketchTooSmall
        let viewModel = makeViewModel(fake)
        await viewModel.load(author: "작성자A")

        viewModel.sketchDidChange(drawn)
        await viewModel.save(author: "작성자A")

        #expect(viewModel.feedback == .tooSmall)
        #expect(viewModel.canvasResetCount == 0)
    }

    @Test func 빈_캔버스면_저장할_수_없다() async {
        let viewModel = makeViewModel(FakeEvaluationUseCases())
        await viewModel.load(author: "작성자A")
        #expect(!viewModel.canSave)
    }

    @Test func 건너뛰면_다른_심볼을_보여준다() async {
        let viewModel = makeViewModel(FakeEvaluationUseCases())
        await viewModel.load(author: "작성자A")
        let first = viewModel.target

        viewModel.skip()

        #expect(viewModel.target != nil)
        #expect(viewModel.target != first)
    }
}
