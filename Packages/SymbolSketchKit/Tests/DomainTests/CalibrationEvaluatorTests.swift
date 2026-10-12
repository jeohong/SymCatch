//
//  CalibrationEvaluatorTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Domain

private func sample(_ name: String, author: String = "A", at seconds: Double) -> EvaluationSample {
    EvaluationSample(symbolName: name, sketch: Fixtures.sketch, author: author, createdAt: Date(timeIntervalSince1970: seconds))
}

private func scored(_ pairs: [(String, Double)]) -> [ScoredSymbol] {
    pairs.map { ScoredSymbol(name: $0.0, family: VariantGrouper.family(of: $0.0), score: $0.1, complexity: $0.0 == "circle" ? 0.02 : 0.1) }
}

struct CalibrationEvaluatorTests {
    @Test func 심볼_단위로_번갈아_나누고_한_심볼의_그림은_같은_쪽에_둔다() {
        let samples = [sample("heart", at: 1), sample("heart", author: "B", at: 2), sample("star", at: 3), sample("bolt", at: 4), sample("cloud", at: 5)]
        let (calibration, holdout) = CalibrationEvaluator.split(samples)

        // 이름순 bolt, cloud, heart, star → bolt·heart 보정용, cloud·star 시험용
        #expect(Set(calibration.map(\.symbolName)) == ["bolt", "heart"])
        #expect(Set(holdout.map(\.symbolName)) == ["cloud", "star"])
        #expect(calibration.filter { $0.symbolName == "heart" }.count == 2)
    }

    @Test func 심볼마다_한_장씩이어도_양쪽에_그림이_생긴다() {
        let samples = ["a", "b", "c", "d"].enumerated().map { sample($0.element, at: Double($0.offset)) }
        let (calibration, holdout) = CalibrationEvaluator.split(samples)
        #expect(calibration.count == 2 && holdout.count == 2)
    }

    @Test func 측정값은_변형을_묶은_순위와_오답_점수를_담는다() {
        let measurement = SampleMeasurement.make(
            sample: sample("heart", at: 0),
            scored: scored([("circle", 0.9), ("heart.fill", 0.85), ("heart", 0.8), ("star", 0.5), ("bolt", 0.3)]),
            seconds: 0.2
        )
        #expect(measurement.targetRank == 2)
        #expect(measurement.targetScore == 0.85)        // 묶음 최고점
        #expect(measurement.topWrong.map(\.name) == ["circle", "star", "bolt"])
        #expect(measurement.wrongMedian == 0.5)
        #expect(measurement.topWrong.first?.complexity == 0.02)
    }

    @Test func 정답이_인덱스에_없으면_순위가_없다() {
        let measurement = SampleMeasurement.make(sample: sample("new.symbol", at: 0), scored: scored([("star", 0.5)]), seconds: 0)
        #expect(measurement.targetRank == nil && measurement.targetScore == nil)
    }

    @Test func 보정값은_오답_중앙값과_정답_분위로_정하고_시험용으로만_잰다() throws {
        func measure(_ target: Double, wrong: Double, top: Double, rank: Int) -> SampleMeasurement {
            SampleMeasurement(sampleID: UUID(), author: "A", targetName: "heart", targetScore: target, targetRank: rank, targetComplexity: 0.1,
                              wrongMedian: wrong, topWrong: [.init(name: "circle", score: top, complexity: 0.02)], seconds: 0.1)
        }
        let calibration = [measure(0.8, wrong: 0.4, top: 0.7, rank: 1), measure(0.9, wrong: 0.5, top: 0.7, rank: 1), measure(1.0, wrong: 0.6, top: 0.7, rank: 2)]
        let holdout = [measure(0.95, wrong: 0.5, top: 0.96, rank: 1), measure(0.6, wrong: 0.5, top: 0.5, rank: 4)]

        let report = try #require(CalibrationEvaluator.evaluate(calibration: calibration, holdout: holdout))
        #expect(report.recommended == ScoreCalibrator(sLow: 0.5, sHigh: 0.9))
        #expect(report.holdout.count == 2)
        #expect(report.holdout.top1 == 0.5 && report.holdout.top3 == 0.5 && report.holdout.top10 == 1)
        #expect(report.holdout.targetBadgeRate == 0.5)  // 0.95 → 100%, 0.6 → 25%
        #expect(report.holdout.wrongBadgeRate == 0.5)   // 0.96 → 100%
        #expect(report.intruders.first?.name == "circle")

        let stricter = try #require(CalibrationEvaluator.evaluate(calibration: calibration, holdout: holdout, highPercentile: 0.75))
        #expect(abs(stricter.recommended.sHigh - 0.95) < 1e-9)
    }

    @Test func 오답_허용률별로_sHigh를_정하고_엄격할수록_오답_뱃지가_줄어든다() throws {
        func measure(_ target: Double, top: Double) -> SampleMeasurement {
            SampleMeasurement(sampleID: UUID(), author: "A", targetName: "heart", targetScore: target, targetRank: 1, targetComplexity: 0.1,
                              wrongMedian: 0.5, topWrong: [.init(name: "circle", score: top, complexity: 0.02)], seconds: 0.1)
        }
        let tops = stride(from: 0.60, through: 0.79, by: 0.01).map { $0 }        // 오답 1위 0.60…0.79
        let calibration = tops.map { measure(0.8, top: $0) }
        let holdout = [measure(0.85, top: 0.70), measure(0.75, top: 0.785), measure(0.9, top: 0.6)]

        let report = try #require(CalibrationEvaluator.evaluate(calibration: calibration, holdout: holdout))
        #expect(report.tradeOffs.map(\.targetWrongRate) == [0.01, 0.05, 0.1, 0.2])
        let strict = report.tradeOffs[0], loose = report.tradeOffs[3]
        #expect(strict.calibrator.sHigh > loose.calibrator.sHigh)
        #expect(strict.holdout.wrongBadgeRate <= loose.holdout.wrongBadgeRate)
        // 10% 목표: 보정용 1위 오답의 90% 분위 점수가 정확히 뱃지 기준(%)이 된다.
        let line = try #require(CalibrationEvaluator.percentile(tops, 0.9))
        #expect(report.tradeOffs[2].calibrator.percent(for: line) == BadgeTierPolicy.threshold)
    }

    @Test func 분위수는_선형_보간() {
        #expect(CalibrationEvaluator.percentile([1, 2, 3, 4], 0.5) == 2.5)
        #expect(CalibrationEvaluator.percentile([3, 1, 2], 1) == 3)
        #expect(CalibrationEvaluator.percentile([], 0.5) == nil)
    }
}

private actor ListSamples: EvaluationSampleRepository {
    let samples: [EvaluationSample]
    init(_ samples: [EvaluationSample]) { self.samples = samples }
    func save(_ sample: EvaluationSample) async throws {}
    func all() async throws -> [EvaluationSample] { samples }
    func delete(id: UUID) async throws {}
    func exportArchive() async throws -> URL { URL(fileURLWithPath: "/dev/null") }
    func importArchive(from url: URL) async throws -> Int { 0 }
}

/// 정답 심볼에 0.9, 나머지에 0.4를 주는 가짜 엔진
private struct FakeScorer: SymbolScoring {
    let engineID = "fake"
    let names = ["heart", "heart.circle", "heart.square", "heart.slash", "star", "bolt"]
    func rawScores(for sketch: Sketch) async throws -> [ScoredSymbol] {
        // 그림의 첫 점 x로 정답을 구분한다(테스트용).
        // 그림의 첫 점 x(0.1, 0.2, …)로 정답 순번을 정한다(테스트용).
        let index = Int(((sketch.strokes.first?.first?.x ?? 0) * 10).rounded()) - 1
        return names.enumerated().map {
            ScoredSymbol(name: $0.element, family: $0.element, score: $0.offset == index ? 0.9 : 0.4, hubness: $0.element == "bolt" ? 0.8 : 0.3)
        }
    }
}

struct RunCalibrationUseCaseTests {
    @Test func 그림을_모두_검색해_보정용과_시험용_측정값을_만든다() async throws {
        let samples = ["heart", "heart.circle", "heart.square", "heart.slash"].enumerated().map { offset, name in
            let x = Double(offset + 1) / 10
            return EvaluationSample(symbolName: name, sketch: Sketch(strokes: [[SketchPoint(x: x, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]]),
                                    author: "A", createdAt: Date(timeIntervalSince1970: Double(offset)))
        }
            + [EvaluationSample(symbolName: "heart", sketch: .empty, author: "A", createdAt: .distantFuture)]   // 빈 그림은 빠진다
        let progress = ProgressBox()

        let run = try await DefaultRunCalibrationUseCase(samples: ListSamples(samples), scorer: FakeScorer()).execute { progress.set($0) }

        #expect(run.measurements(.raw).calibration.count == 2 && run.measurements(.raw).holdout.count == 2)
        #expect(run.engineID == "fake")
        #expect(progress.value == 1)
        let report = try #require(run.report(highPercentile: 0.5))
        #expect(report.holdout.top1 == 1)
        #expect(report.recommended == ScoreCalibrator(sLow: 0.4, sHigh: 0.9))

        #expect(run.supportsCorrection)
        #expect(run.availableModes == CalibrationScoreMode.allCases)
        let corrected = try #require(run.report(mode: .hubness100, highPercentile: 0.5))
        #expect(corrected.holdout.top1 == 1)
        // 보정 점수: 정답 2×0.9 − r(그림) − 0.3, 오답은 더 낮다.
        #expect(corrected.recommended.sHigh > corrected.recommended.sLow)
    }
}

private final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0.0
    var value: Double { lock.withLock { stored } }
    func set(_ value: Double) { lock.withLock { stored = value } }
}
