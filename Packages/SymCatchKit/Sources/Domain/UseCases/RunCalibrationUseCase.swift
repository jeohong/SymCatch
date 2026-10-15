//
//  RunCalibrationUseCase.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 점수 방식: 엔진 원래 점수 / 지금 앱(닮은꼴 25%) / 거기에 방향 보정 세기별(`ScoreAdjustment`)
public enum CalibrationScoreMode: String, Sendable, Hashable, CaseIterable {
    case raw
    case hubness25
    case layout05
    case layout10
    case layout20

    public var weights: ScoreWeights {
        switch self {
        case .raw: .none
        case .hubness25: ScoreWeights(hubness: 0.25)
        case .layout05: ScoreWeights(hubness: 0.25, layout: 0.05)
        case .layout10: ScoreWeights(hubness: 0.25, layout: 0.1)
        case .layout20: ScoreWeights(hubness: 0.25, layout: 0.2)
        }
    }
}

/// 평가 실행 결과: 방식별 측정값을 들고 있어 분위·방식만 바꿔 다시 계산할 수 있다.
public struct CalibrationRun: Sendable, Hashable {
    public struct Measurements: Sendable, Hashable {
        public let calibration: [SampleMeasurement]
        public let holdout: [SampleMeasurement]

        public init(calibration: [SampleMeasurement], holdout: [SampleMeasurement]) {
            self.calibration = calibration
            self.holdout = holdout
        }
    }

    public let byMode: [CalibrationScoreMode: Measurements]
    public let engineID: String

    public init(byMode: [CalibrationScoreMode: Measurements], engineID: String) {
        self.byMode = byMode
        self.engineID = engineID
    }

    /// 기존 점수만 있는 실행
    public init(calibration: [SampleMeasurement], holdout: [SampleMeasurement], engineID: String) {
        self.init(byMode: [.raw: Measurements(calibration: calibration, holdout: holdout)], engineID: engineID)
    }

    /// 측정한 방식(선언 순서)
    public var availableModes: [CalibrationScoreMode] {
        CalibrationScoreMode.allCases.filter { byMode[$0] != nil }
    }

    /// 보정 결과(닮은꼴·방향)가 있는지
    public var supportsCorrection: Bool { availableModes.count > 1 }

    public func measurements(_ mode: CalibrationScoreMode) -> (calibration: [SampleMeasurement], holdout: [SampleMeasurement]) {
        let measurements = byMode[mode]
        return (measurements?.calibration ?? [], measurements?.holdout ?? [])
    }

    public func report(mode: CalibrationScoreMode = .raw, highPercentile: Double) -> CalibrationReport? {
        let (calibration, holdout) = measurements(mode)
        return CalibrationEvaluator.evaluate(calibration: calibration, holdout: holdout, highPercentile: highPercentile)
    }
}

/// 개발용: 저장된 평가 그림을 모두 검색해 보정값과 정확도를 잰다(기획서 9.5).
public protocol RunCalibrationUseCase: Sendable {
    /// - Parameter progress: 0...1
    func execute(progress: @escaping @Sendable (Double) -> Void) async throws -> CalibrationRun
}

public struct DefaultRunCalibrationUseCase: RunCalibrationUseCase {
    private let samples: any EvaluationSampleRepository
    private let scorer: any SymbolScoring
    private let validator: SketchValidator

    public init(samples: any EvaluationSampleRepository, scorer: any SymbolScoring, validator: SketchValidator = SketchValidator()) {
        self.samples = samples
        self.scorer = scorer
        self.validator = validator
    }

    public func execute(progress: @escaping @Sendable (Double) -> Void) async throws -> CalibrationRun {
        // 검색에서 막히는 너무 작은 그림은 평가에서도 뺀다(앱에서는 찾지 않는 그림).
        let all = try await samples.all().filter { validator.validate($0.sketch) == .valid }
        let (calibration, holdout) = CalibrationEvaluator.split(all)
        let ordered = calibration + holdout
        let clock = ContinuousClock()
        var measured: [CalibrationScoreMode: [SampleMeasurement]] = [:]
        var supportsCorrection = true
        for (index, sample) in ordered.enumerated() {
            try Task.checkCancellation()
            let start = clock.now
            let scored = try await scorer.rawScores(for: sample.sketch)
            let elapsed = start.duration(to: clock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            supportsCorrection = supportsCorrection && scored.allSatisfy { $0.hubness != nil && $0.layout != nil }
            for mode in CalibrationScoreMode.allCases {
                let modeScores = ScoreAdjustment.adjusted(scored, weights: mode.weights)
                measured[mode, default: []].append(.make(sample: sample, scored: modeScores, seconds: seconds))
            }
            progress(Double(index + 1) / Double(max(ordered.count, 1)))
        }
        let modes = supportsCorrection ? CalibrationScoreMode.allCases : [.raw]
        var byMode: [CalibrationScoreMode: CalibrationRun.Measurements] = [:]
        for mode in modes {
            let all = measured[mode] ?? []
            byMode[mode] = .init(calibration: Array(all.prefix(calibration.count)), holdout: Array(all.dropFirst(calibration.count)))
        }
        return CalibrationRun(byMode: byMode, engineID: scorer.engineID)
    }
}
