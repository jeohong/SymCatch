//
//  EvaluationRunViewModelTests.swift
//  SymCatchTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import SymCatch

private struct StubPrepare: PrepareSymbolIndexUseCase {
    var ready: Bool
    func status() async -> SymbolIndexStatus { ready ? .ready(symbolCount: 3) : .missing }
    func execute() -> AsyncThrowingStream<Double, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct StubRun: RunCalibrationUseCase {
    var run: CalibrationRun
    func execute(progress: @escaping @Sendable (Double) -> Void) async throws -> CalibrationRun {
        progress(1)
        return run
    }
}

private func measure(_ target: Double, author: String = "A", rank: Int = 1, wrongTop: Double = 0.6) -> SampleMeasurement {
    SampleMeasurement(sampleID: UUID(), author: author, targetName: "heart", targetScore: target, targetRank: rank, targetComplexity: 0.05,
                      wrongMedian: 0.5, topWrong: [.init(name: "circle", score: wrongTop, complexity: 0.02)], seconds: 0.1)
}

@MainActor
struct EvaluationRunViewModelTests {
    private let run = CalibrationRun(
        calibration: [measure(0.8), measure(0.9), measure(1.0)],
        holdout: [measure(0.95, author: "A"), measure(0.7, author: "B", rank: 5)],
        engineID: "vision-outline"
    )

    private func makeViewModel(ready: Bool = true) -> EvaluationRunViewModel {
        EvaluationRunViewModel(prepareIndex: StubPrepare(ready: ready), runCalibration: StubRun(run: run),
                               currentCalibrator: ScoreCalibrator(sLow: 0.5, sHigh: 0.95))
    }

    @Test func 인덱스가_없으면_실행하지_않는다() async {
        let viewModel = makeViewModel(ready: false)
        await viewModel.start()
        #expect(viewModel.state == .indexNotReady)
        #expect(viewModel.report == nil)
    }

    @Test func 실행하면_추천값과_작성자별_결과가_나온다() async throws {
        let viewModel = makeViewModel()
        await viewModel.start()

        let report = try #require(viewModel.report)
        #expect(report.recommended == ScoreCalibrator(sLow: 0.5, sHigh: 0.9))
        #expect(report.byAuthor.keys.sorted() == ["A", "B"])
        #expect(viewModel.exportText.contains("| 기존 점수 | 2 |"))
        #expect(viewModel.exportText.contains("vision-outline"))
        #expect(viewModel.exportText.contains("## 엄격도별 결과"))
        #expect(viewModel.exportText.contains(EvaluationRunViewModel.csvHeader))
        #expect(viewModel.exportText.contains("raw,holdout,B,heart,0.7000,5,"))
        #expect(viewModel.comparison.map(\.mode) == [.raw])          // 보정 측정값이 없으면 기존 방식만
    }

    @Test func 분위를_바꾸면_다시_계산한다() async throws {
        let viewModel = makeViewModel()
        await viewModel.start()
        viewModel.highPercentile = 0.75
        let report = try #require(viewModel.report)
        #expect(abs(report.recommended.sHigh - 0.95) < 1e-9)
    }
}

@MainActor
struct EvaluationRunComparisonTests {
    @Test func 닮은꼴_보정_결과가_있으면_두_방식을_나란히_보여준다() async throws {
        let raw = [measure(0.8), measure(0.9), measure(1.0)]
        let corrected = [measure(0.6), measure(0.7), measure(0.8)]
        let run = CalibrationRun(byMode: [
            .raw: .init(calibration: raw, holdout: [measure(0.95)]),
            .layout10: .init(calibration: corrected, holdout: [measure(0.75)]),
        ], engineID: "vision-outline")
        let viewModel = EvaluationRunViewModel(prepareIndex: StubPrepare(ready: true), runCalibration: StubRun(run: run),
                                               currentCalibrator: ScoreCalibrator(sLow: 0.5, sHigh: 0.95))
        await viewModel.start()

        #expect(viewModel.comparison.map(\.mode) == [.raw, .layout10])
        #expect(viewModel.scoreMode == .layout10)
        #expect(viewModel.report?.recommended.sHigh == 0.7)
        viewModel.scoreMode = .raw
        #expect(viewModel.report?.recommended.sHigh == 0.9)
        #expect(viewModel.exportText.contains("layout10,calibration,"))
        #expect(viewModel.exportText.contains("| + 방향 0.1(지금 앱) | 1 |"))
    }
}
