//
//  RunCalibrationUseCase.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 점수 방식: 엔진 원래 점수 / 만능 닮은꼴 보정 점수(`HubnessCorrection`)
public enum CalibrationScoreMode: String, Sendable, Hashable, CaseIterable {
    case raw
    case hubnessCorrected
}

/// 평가 실행 결과: 측정값을 들고 있어 분위·점수 방식만 바꿔 다시 계산할 수 있다.
public struct CalibrationRun: Sendable, Hashable {
    public let calibration: [SampleMeasurement]
    public let holdout: [SampleMeasurement]
    /// 같은 그림을 닮은꼴 보정 점수로 잰 값. 엔진이 지원하지 않으면 비어 있다.
    public let correctedCalibration: [SampleMeasurement]
    public let correctedHoldout: [SampleMeasurement]
    public let engineID: String

    public init(calibration: [SampleMeasurement], holdout: [SampleMeasurement],
                correctedCalibration: [SampleMeasurement] = [], correctedHoldout: [SampleMeasurement] = [], engineID: String) {
        self.calibration = calibration
        self.holdout = holdout
        self.correctedCalibration = correctedCalibration
        self.correctedHoldout = correctedHoldout
        self.engineID = engineID
    }

    /// 닮은꼴 보정 결과가 있는지
    public var supportsCorrection: Bool { !correctedCalibration.isEmpty }

    public func measurements(_ mode: CalibrationScoreMode) -> (calibration: [SampleMeasurement], holdout: [SampleMeasurement]) {
        switch mode {
        case .raw: (calibration, holdout)
        case .hubnessCorrected: (correctedCalibration, correctedHoldout)
        }
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
        var measurements: [SampleMeasurement] = [], corrected: [SampleMeasurement] = []
        var supportsCorrection = true
        for (index, sample) in ordered.enumerated() {
            try Task.checkCancellation()
            let start = clock.now
            let scored = try await scorer.rawScores(for: sample.sketch)
            let elapsed = start.duration(to: clock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            measurements.append(.make(sample: sample, scored: scored, seconds: seconds))
            supportsCorrection = supportsCorrection && scored.allSatisfy { $0.hubness != nil }
            corrected.append(.make(sample: sample, scored: HubnessCorrection.corrected(scored), seconds: seconds))
            progress(Double(index + 1) / Double(max(ordered.count, 1)))
        }
        return CalibrationRun(
            calibration: Array(measurements.prefix(calibration.count)),
            holdout: Array(measurements.dropFirst(calibration.count)),
            correctedCalibration: supportsCorrection ? Array(corrected.prefix(calibration.count)) : [],
            correctedHoldout: supportsCorrection ? Array(corrected.dropFirst(calibration.count)) : [],
            engineID: scorer.engineID
        )
    }
}
