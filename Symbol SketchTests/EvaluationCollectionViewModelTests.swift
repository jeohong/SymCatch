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
private final class FakeEvaluationUseCases: LoadEvaluationProgressUseCase, SaveEvaluationSampleUseCase, ExportEvaluationSamplesUseCase, @unchecked Sendable {
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
}

@MainActor
struct EvaluationCollectionViewModelTests {
    private let drawn = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])

    private func makeViewModel(_ fake: FakeEvaluationUseCases) -> EvaluationCollectionViewModel {
        EvaluationCollectionViewModel(loadProgress: fake, saveSample: fake, exportSamples: fake)
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
