//
//  EvaluationRunViewModel.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

#if DEBUG
import Foundation
import Domain

/// 개발용 평가 실행: 모은 평가 그림으로 보정값(sLow·sHigh)을 추천하고 정확도를 잰다.
/// 시뮬레이터의 Vision 결과는 의미가 없으므로 실기기에서 돌린다(CLAUDE.md 2.3).
@MainActor @Observable
final class EvaluationRunViewModel {
    enum State: Equatable {
        case idle
        /// 심볼 인덱스가 아직 없음(그리기 탭에서 준비를 먼저 끝내야 함)
        case indexNotReady
        case running(progress: Double)
        case finished(CalibrationRun)
        case failed(String)
    }

    /// sHigh 분위 선택지: 중앙값 / 상위 25% 지점
    static let percentileOptions: [Double] = [0.5, 0.75]

    private(set) var state: State = .idle
    var highPercentile = 0.5
    /// 화면에 보여 줄 점수 방식(기존 / 닮은꼴 보정)
    var scoreMode: CalibrationScoreMode = .layout10

    let currentCalibrator: ScoreCalibrator
    private let prepareIndex: any PrepareSymbolIndexUseCase
    private let runCalibration: any RunCalibrationUseCase

    init(prepareIndex: any PrepareSymbolIndexUseCase, runCalibration: any RunCalibrationUseCase, currentCalibrator: ScoreCalibrator) {
        self.prepareIndex = prepareIndex
        self.runCalibration = runCalibration
        self.currentCalibrator = currentCalibrator
    }

    var isRunning: Bool {
        if case .running = state { true } else { false }
    }

    var run: CalibrationRun? {
        if case .finished(let run) = state { run } else { nil }
    }

    /// 지금 고른 분위·점수 방식으로 계산한 보고서. 그림이 부족하면 nil
    var report: CalibrationReport? {
        guard let run else { return nil }
        return run.report(mode: run.availableModes.contains(scoreMode) ? scoreMode : .raw, highPercentile: highPercentile)
    }

    /// 두 방식 나란히 비교(같은 그림·같은 분위)
    var comparison: [(mode: CalibrationScoreMode, report: CalibrationReport)] {
        guard let run else { return [] }
        return run.availableModes.compactMap { mode in run.report(mode: mode, highPercentile: highPercentile).map { (mode, $0) } }
    }

    func start() async {
        guard !isRunning else { return }
        guard case .ready = await prepareIndex.status() else {
            state = .indexNotReady
            return
        }
        state = .running(progress: 0)
        do {
            let result = try await runCalibration.execute { progress in
                Task { @MainActor [weak self] in
                    guard let self, case .running = self.state else { return }
                    self.state = .running(progress: progress)
                }
            }
            state = .finished(result)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - 내보내기

    /// 공유 시트로 내보낼 Markdown 보고서(두 점수 방식 모두)
    var exportText: String {
        guard let run, !comparison.isEmpty else { return "평가 그림이 부족해 보정값을 계산하지 못했습니다." }
        var lines = [
            "# SymCatch 보정 평가",
            "",
            "- 엔진: `\(run.engineID)`",
            "- sHigh 분위: \(Self.percentText(highPercentile)) · 뱃지 기준 \(BadgeTierPolicy.threshold)%",
            "- 현재 보정값 sLow \(Self.score(currentCalibrator.sLow)) · sHigh \(Self.score(currentCalibrator.sHigh))",
            "",
            "## 방식 비교(시험용)",
            "",
            "| 방식 | 장수 | Top1 | Top3 | Top10 | 정답 기준+ | 오답 기준+ | 정답 중앙값 |",
            "| --- | --- | --- | --- | --- | --- | --- | --- |",
        ]
        lines += comparison.map { Self.row(Self.title($0.mode), $0.report.holdout) }
        for (mode, report) in comparison {
            lines += [
                "",
                "# \(Self.title(mode))",
                "",
                "- 그림: 보정용 \(report.calibrationCount)장 · 시험용 \(report.holdoutCount)장 · 제외 \(report.skippedCount)장",
                "- 추천 sLow \(Self.score(report.recommended.sLow)) · sHigh \(Self.score(report.recommended.sHigh))",
                "- 검색 시간 평균 \(Self.seconds(report.meanSeconds)) · 최대 \(Self.seconds(report.maxSeconds))",
                "",
                "## 작성자별(시험용)",
                "",
                "| 작성자 | 장수 | Top1 | Top3 | Top10 | 정답 기준+ | 오답 기준+ | 정답 중앙값 |",
                "| --- | --- | --- | --- | --- | --- | --- | --- |",
            ]
            lines += report.byAuthor.keys.sorted().map { Self.row($0, report.byAuthor[$0]!) }
            lines += ["", "## 엄격도별 결과(엉뚱한 1위가 뱃지 기준을 넘는 비율 목표)", "",
                      "| 목표 | sHigh | 정답 기준+ | 오답 기준+ | 정답 중앙값 |", "| --- | --- | --- | --- | --- |"]
            lines += report.tradeOffs.map {
                "| \(Self.percentText($0.targetWrongRate)) | \(Self.score($0.calibrator.sHigh)) | \(Self.percentText($0.holdout.targetBadgeRate))"
                    + " | \(Self.percentText($0.holdout.wrongBadgeRate)) | \($0.holdout.medianTargetPercent.map { "\($0)%" } ?? "-") |"
            }
            lines += ["", "## 오답인데 뱃지 기준 이상이 자주 나온 심볼", "", "| 심볼 | 복잡도 | 횟수 |", "| --- | --- | --- |"]
            lines += report.intruders.map { "| \($0.name) | \(Self.complexity($0.complexity)) | \($0.count) |" }
        }
        lines += ["", "## 그림별 점수(CSV)", "", "```csv", Self.csvHeader]
        for mode in comparison.map(\.mode) {
            let (calibration, holdout) = run.measurements(mode)
            lines += calibration.map { Self.csvRow(mode, "calibration", $0) } + holdout.map { Self.csvRow(mode, "holdout", $0) }
        }
        lines += ["```"]
        return lines.joined(separator: "\n")
    }

    static func title(_ mode: CalibrationScoreMode) -> String {
        switch mode {
        case .raw: "기존 점수"
        case .hubness25: "닮은꼴 25%"
        case .layout05: "+ 방향 0.05"
        case .layout10: "+ 방향 0.1(지금 앱)"
        case .layout20: "+ 방향 0.2"
        }
    }

    static let csvHeader = "mode,half,author,target,targetScore,targetRank,targetComplexity,wrongMedian,seconds,topWrong(name:score:complexity|…)"

    static func csvRow(_ mode: CalibrationScoreMode, _ half: String, _ m: SampleMeasurement) -> String {
        let wrong = m.topWrong.map { "\($0.name):\(score($0.score)):\(complexity($0.complexity))" }.joined(separator: "|")
        return [mode.rawValue, half, m.author, m.targetName, m.targetScore.map(score) ?? "", m.targetRank.map(String.init) ?? "",
                complexity(m.targetComplexity), score(m.wrongMedian), String(format: "%.4f", m.seconds), wrong]
            .map { $0.contains(",") ? "\"\($0)\"" : $0 }
            .joined(separator: ",")
    }

    private static func row(_ title: String, _ accuracy: CalibrationReport.Accuracy) -> String {
        "| \(title) | \(accuracy.count) | \(percentText(accuracy.top1)) | \(percentText(accuracy.top3)) | \(percentText(accuracy.top10))"
            + " | \(percentText(accuracy.targetBadgeRate)) | \(percentText(accuracy.wrongBadgeRate)) | \(accuracy.medianTargetPercent.map { "\($0)%" } ?? "-") |"
    }

    // MARK: - 숫자 표시

    static func percentText(_ ratio: Double) -> String { "\(Int((ratio * 100).rounded()))%" }
    static func score(_ value: Double) -> String { String(format: "%.4f", value) }
    static func seconds(_ value: Double) -> String { String(format: "%.3f초", value) }
    static func complexity(_ value: Double?) -> String { value.map { String(format: "%.4f", $0) } ?? "-" }
}
#endif
