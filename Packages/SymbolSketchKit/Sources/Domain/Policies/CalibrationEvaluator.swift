//
//  CalibrationEvaluator.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 평가 그림 한 장의 측정값(보정 전 원시 점수 기준)
public struct SampleMeasurement: Sendable, Hashable {
    /// 묶음(family) 하나의 점수
    public struct Candidate: Sendable, Hashable {
        public let name: String
        public let score: Double
        public let complexity: Double?

        public init(name: String, score: Double, complexity: Double?) {
            self.name = name
            self.score = score
            self.complexity = complexity
        }
    }

    public let sampleID: UUID
    public let author: String
    public let targetName: String
    /// 정답 묶음의 점수. 정답이 인덱스에 없으면(이 OS에 없는 심볼 등) nil
    public let targetScore: Double?
    /// 정답 묶음의 순위(1부터). 없으면 nil
    public let targetRank: Int?
    public let targetComplexity: Double?
    /// 오답 묶음 점수의 중앙값("관계없는 심볼" 점수)
    public let wrongMedian: Double
    /// 점수가 높은 오답 묶음(최대 10개)
    public let topWrong: [Candidate]
    /// 검색 1회 시간(초)
    public let seconds: Double

    public init(sampleID: UUID, author: String, targetName: String, targetScore: Double?, targetRank: Int?, targetComplexity: Double?,
                wrongMedian: Double, topWrong: [Candidate], seconds: Double) {
        self.sampleID = sampleID
        self.author = author
        self.targetName = targetName
        self.targetScore = targetScore
        self.targetRank = targetRank
        self.targetComplexity = targetComplexity
        self.wrongMedian = wrongMedian
        self.topWrong = topWrong
        self.seconds = seconds
    }

    /// - Parameter scored: 모든 심볼의 원시 점수
    public static func make(sample: EvaluationSample, scored: [ScoredSymbol], seconds: Double) -> SampleMeasurement {
        let targetFamily = VariantGrouper.family(of: sample.symbolName)
        let complexityByName = Dictionary(scored.compactMap { s in s.complexity.map { (s.name, $0) } }, uniquingKeysWith: { first, _ in first })
        let groups = VariantGrouper.group(scored, limit: .max)
        let targetIndex = groups.firstIndex { $0.representative.family == targetFamily }
        let wrong = groups.enumerated().filter { $0.offset != targetIndex }.map(\.element)
        let target = targetIndex.map { groups[$0] }
        return SampleMeasurement(
            sampleID: sample.id,
            author: sample.author,
            targetName: sample.symbolName,
            targetScore: target?.score,
            targetRank: targetIndex.map { $0 + 1 },
            targetComplexity: target.flatMap { complexityByName[$0.representative.name] },
            wrongMedian: CalibrationEvaluator.median(wrong.map(\.score)) ?? 0,
            topWrong: wrong.prefix(10).map { Candidate(name: $0.representative.name, score: $0.score, complexity: complexityByName[$0.representative.name]) },
            seconds: seconds
        )
    }
}

/// 평가 결과 보고서
public struct CalibrationReport: Sendable, Hashable {
    public struct Accuracy: Sendable, Hashable {
        public let count: Int
        public let top1: Double
        public let top3: Double
        public let top10: Double
        /// 정답 점수를 보정했을 때 90% 이상인 비율(정답을 골랐을 때 뱃지를 받는 비율)
        public let targetBadgeRate: Double
        /// 1위 오답이 90% 이상인 비율(엉뚱한 심볼로 뱃지를 받을 위험)
        public let wrongBadgeRate: Double
        /// 정답 점수 중앙값(보정 후 %)
        public let medianTargetPercent: Int?
    }

    /// 단순 심볼 후보: 다른 그림에서 오답인데 90% 이상이 자주 나온 심볼
    public struct Intruder: Sendable, Hashable {
        public let name: String
        public let complexity: Double?
        public let count: Int
    }

    public let calibrationCount: Int
    public let holdoutCount: Int
    public let recommended: ScoreCalibrator
    /// sHigh를 정답 점수의 어느 분위로 잡았는지(0.5 = 중앙값)
    public let highPercentile: Double
    /// 보정에 쓰지 않은 절반으로 잰 결과
    public let holdout: Accuracy
    /// 작성자별(보정에 쓰지 않은 절반)
    public let byAuthor: [String: Accuracy]
    public let intruders: [Intruder]
    /// 정답 심볼의 복잡도 분포(낮은 순 10개): 단순 심볼 기준선을 정할 때 본다
    public let simplestTargets: [Intruder]
    public let meanSeconds: Double
    public let maxSeconds: Double
    /// 정답이 인덱스에 없어 뺀 그림 수
    public let skippedCount: Int
    /// "엉뚱한 1위가 90%를 넘는 비율"을 목표로 sHigh를 정했을 때의 결과(엄격할수록 위)
    public let tradeOffs: [TradeOff]

    /// 오답 허용률 하나에 대한 보정값과 시험 결과
    public struct TradeOff: Sendable, Hashable {
        /// 보정용 그림에서 1위 오답이 90% 이상이 되는 비율 목표
        public let targetWrongRate: Double
        public let calibrator: ScoreCalibrator
        public let holdout: Accuracy
    }
}

/// 평가 그림으로 보정값(sLow·sHigh)을 정하고, 보정에 쓰지 않은 그림으로 결과를 잰다.
///
/// 평가셋을 보정에 섞지 않는다(CLAUDE.md 절대 규칙 8): 정답 심볼을 번갈아 "보정용"과 "시험용"으로 나눠,
/// 보정값은 앞쪽 심볼의 그림으로만 정하고 정확도는 뒤쪽 심볼의 그림으로만 잰다.
/// 수집 화면은 심볼마다 1장씩 먼저 모으므로, 그림 단위가 아니라 심볼 단위로 나눠야 양쪽에 그림이 생긴다.
public enum CalibrationEvaluator {
    public static let badgeThreshold = BadgeTierPolicy.threshold

    /// 보정용·시험용으로 나눈다. 정답 심볼 이름순으로 번갈아 배정하고, 한 심볼의 그림은 모두 같은 쪽에 둔다.
    public static func split(_ samples: [EvaluationSample]) -> (calibration: [EvaluationSample], holdout: [EvaluationSample]) {
        let symbols = Set(samples.map(\.symbolName)).sorted()
        let calibrationSymbols = Set(symbols.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element))
        let ordered = samples.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        return (ordered.filter { calibrationSymbols.contains($0.symbolName) }, ordered.filter { !calibrationSymbols.contains($0.symbolName) })
    }

    /// - Parameters:
    ///   - calibration: 보정용 측정값
    ///   - holdout: 시험용 측정값
    ///   - highPercentile: sHigh로 쓸 정답 점수 분위(0.5 중앙값, 0.75면 상위 25% 지점)
    public static func evaluate(calibration: [SampleMeasurement], holdout: [SampleMeasurement], highPercentile: Double = 0.5) -> CalibrationReport? {
        let validCalibration = calibration.filter { $0.targetScore != nil }
        let validHoldout = holdout.filter { $0.targetScore != nil }
        guard let sLow = median(validCalibration.map(\.wrongMedian)),
              let sHigh = percentile(validCalibration.compactMap(\.targetScore), highPercentile),
              sHigh > sLow else { return nil }
        let calibrator = ScoreCalibrator(sLow: sLow, sHigh: sHigh)

        let byAuthor = Dictionary(grouping: validHoldout, by: \.author).mapValues { accuracy($0, calibrator) }
        let all = validCalibration + validHoldout
        let seconds = (calibration + holdout).map(\.seconds)

        return CalibrationReport(
            calibrationCount: validCalibration.count,
            holdoutCount: validHoldout.count,
            recommended: calibrator,
            highPercentile: highPercentile,
            holdout: accuracy(validHoldout, calibrator),
            byAuthor: byAuthor,
            intruders: intruders(all, calibrator),
            simplestTargets: simplestTargets(all),
            meanSeconds: seconds.isEmpty ? 0 : seconds.reduce(0, +) / Double(seconds.count),
            maxSeconds: seconds.max() ?? 0,
            skippedCount: calibration.count + holdout.count - all.count,
            tradeOffs: tradeOffs(calibration: validCalibration, holdout: validHoldout, sLow: sLow)
        )
    }

    /// 오답 허용률 목표별 보정값: 보정용 그림의 1위 오답 점수 중 (1 − 목표) 분위가 딱 90%가 되도록 sHigh를 정한다.
    static func tradeOffs(calibration: [SampleMeasurement], holdout: [SampleMeasurement], sLow: Double,
                          targets: [Double] = [0.01, 0.05, 0.1, 0.2]) -> [CalibrationReport.TradeOff] {
        let topWrong = calibration.compactMap { $0.topWrong.first?.score }
        let ratio = Double(badgeThreshold) / 100
        return targets.compactMap { target in
            guard let line = percentile(topWrong, 1 - target), line > sLow else { return nil }
            // 90% 지점 = sLow + (sHigh − sLow) × 0.9 이므로 sHigh = sLow + (line − sLow) / 0.9
            // 반올림 때문에 경계 점수가 89.5%로 올라가지 않도록 아주 조금 더 높인다.
            let sHigh = sLow + (line - sLow) / ratio + 1e-9
            let calibrator = ScoreCalibrator(sLow: sLow, sHigh: sHigh)
            return CalibrationReport.TradeOff(targetWrongRate: target, calibrator: calibrator, holdout: accuracy(holdout, calibrator))
        }
    }

    static func accuracy(_ measurements: [SampleMeasurement], _ calibrator: ScoreCalibrator) -> CalibrationReport.Accuracy {
        let count = measurements.count
        func rate(_ predicate: (SampleMeasurement) -> Bool) -> Double {
            count == 0 ? 0 : Double(measurements.filter(predicate).count) / Double(count)
        }
        return CalibrationReport.Accuracy(
            count: count,
            top1: rate { ($0.targetRank ?? .max) <= 1 },
            top3: rate { ($0.targetRank ?? .max) <= 3 },
            top10: rate { ($0.targetRank ?? .max) <= 10 },
            targetBadgeRate: rate { $0.targetScore.map { calibrator.percent(for: $0) >= badgeThreshold } ?? false },
            wrongBadgeRate: rate { $0.topWrong.first.map { calibrator.percent(for: $0.score) >= badgeThreshold } ?? false },
            medianTargetPercent: median(measurements.compactMap(\.targetScore)).map(calibrator.percent(for:))
        )
    }

    static func intruders(_ measurements: [SampleMeasurement], _ calibrator: ScoreCalibrator) -> [CalibrationReport.Intruder] {
        var counts: [String: (complexity: Double?, count: Int)] = [:]
        for measurement in measurements {
            for candidate in measurement.topWrong where calibrator.percent(for: candidate.score) >= badgeThreshold {
                counts[candidate.name, default: (candidate.complexity, 0)].count += 1
            }
        }
        return counts.map { CalibrationReport.Intruder(name: $0.key, complexity: $0.value.complexity, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .prefix(15).map { $0 }
    }

    static func simplestTargets(_ measurements: [SampleMeasurement]) -> [CalibrationReport.Intruder] {
        let byName = Dictionary(grouping: measurements, by: \.targetName)
        return byName.compactMap { name, items in
            items.first?.targetComplexity.map { CalibrationReport.Intruder(name: name, complexity: $0, count: items.count) }
        }
        .sorted { ($0.complexity ?? 0, $0.name) < ($1.complexity ?? 0, $1.name) }
        .prefix(10).map { $0 }
    }

    static func median(_ values: [Double]) -> Double? {
        percentile(values, 0.5)
    }

    /// 선형 보간 분위수. 비어 있으면 nil
    static func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let position = min(max(p, 0), 1) * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down)), upper = Int(position.rounded(.up))
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
    }
}
