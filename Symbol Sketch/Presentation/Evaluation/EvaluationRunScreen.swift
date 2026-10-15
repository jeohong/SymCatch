//
//  EvaluationRunScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

#if DEBUG
import SwiftUI
import Domain

/// 개발용 평가 실행 화면. DEBUG 빌드에서만 존재한다.
struct EvaluationRunScreen: View {
    @Bindable var viewModel: EvaluationRunViewModel

    var body: some View {
        List {
            Section {
                Text("평가셋 수집에서 모은 그림을 반으로 나눠, 절반으로 보정값을 정하고 나머지 절반으로 정확도를 재요. 시뮬레이터 결과는 의미가 없으니 실기기에서 실행하세요.")
                    .font(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
                Button {
                    Task { await viewModel.start() }
                } label: {
                    Label("평가 실행", systemImage: "play.fill")
                }
                .disabled(viewModel.isRunning)
                status
            }

            if let run = viewModel.run {
                if run.supportsCorrection {
                    Section {
                        ForEach(viewModel.comparison, id: \.mode) { item in
                            value(EvaluationRunViewModel.title(item.mode),
                                  [item.report.holdout.top1, item.report.holdout.top3, item.report.holdout.top10]
                                    .map(EvaluationRunViewModel.percentText).joined(separator: " · "),
                                  detail: "Top 1 · 3 · 10, 10위 밖 \(EvaluationRunViewModel.percentText(1 - item.report.holdout.top10))")
                        }
                        Picker("점수 방식", selection: $viewModel.scoreMode) {
                            ForEach(run.availableModes, id: \.self) { mode in
                                Text(EvaluationRunViewModel.title(mode)).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text("방식 비교(시험용)")
                    } footer: {
                        Text("아래 결과는 고른 점수 방식 기준이에요.")
                    }
                }
                Section("\(100.percentText) 기준(sHigh)") {
                    Picker("정답 점수 분위", selection: $viewModel.highPercentile) {
                        Text("중앙값").tag(0.5)
                        Text("상위 \(25.percentText)").tag(0.75)
                    }
                    .pickerStyle(.segmented)
                }
                if let report = viewModel.report {
                    results(report)
                } else {
                    Section { Text("그림이 부족해 보정값을 계산하지 못했어요") }
                }
            }
        }
        .navigationTitle("평가 실행")
        .toolbar {
            if viewModel.run != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: viewModel.exportText) {
                        Label("결과 내보내기", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch viewModel.state {
        case .idle, .finished:
            EmptyView()
        case .indexNotReady:
            Text("심볼 준비가 끝나지 않았어요. 그리기 탭에서 준비를 마친 뒤 실행하세요.")
                .foregroundStyle(DSColor.danger)
        case .running(let progress):
            ProgressView(value: progress) { Text("검색 중 \(Int(progress * 100).percentText)") }
        case .failed(let message):
            Text(message).foregroundStyle(DSColor.danger)
        }
    }

    @ViewBuilder
    private func results(_ report: CalibrationReport) -> some View {
        Section("추천 보정값") {
            value("sLow (0%)", EvaluationRunViewModel.score(report.recommended.sLow), detail: "현재 \(EvaluationRunViewModel.score(viewModel.currentCalibrator.sLow))")
            value("sHigh (100%)", EvaluationRunViewModel.score(report.recommended.sHigh), detail: "현재 \(EvaluationRunViewModel.score(viewModel.currentCalibrator.sHigh))")
            value("그림", "보정용 \(report.calibrationCount) · 시험용 \(report.holdoutCount)", detail: report.skippedCount > 0 ? "제외 \(report.skippedCount)" : nil)
        }
        Section("시험용 결과") {
            accuracyRows(report.holdout)
        }
        ForEach(report.byAuthor.keys.sorted(), id: \.self) { author in
            Section("작성자: \(author)") { accuracyRows(report.byAuthor[author]!) }
        }
        Section {
            ForEach(report.tradeOffs, id: \.targetWrongRate) { tradeOff in
                value("오답 목표 \(EvaluationRunViewModel.percentText(tradeOff.targetWrongRate))",
                      "정답 \(EvaluationRunViewModel.percentText(tradeOff.holdout.targetBadgeRate)) · 오답 \(EvaluationRunViewModel.percentText(tradeOff.holdout.wrongBadgeRate))",
                      detail: "sHigh \(EvaluationRunViewModel.score(tradeOff.calibrator.sHigh))")
            }
        } header: {
            Text("엄격도별 결과")
        } footer: {
            Text("엉뚱한 1위가 뱃지 기준(\(BadgeTierPolicy.threshold.percentText))을 넘는 비율을 목표로 sHigh를 정했을 때, 시험용 그림에서 정답·오답이 기준 이상인 비율")
        }
        Section("오답인데 뱃지 기준 이상이 자주 나온 심볼") {
            if report.intruders.isEmpty { Text("없음").foregroundStyle(DSColor.textSecondary) }
            ForEach(report.intruders, id: \.name) { intruder in
                symbolRow(intruder.name, complexity: intruder.complexity, trailing: "\(intruder.count)회")
            }
        }
        Section("가장 단순한 정답 심볼") {
            ForEach(report.simplestTargets, id: \.name) { target in
                symbolRow(target.name, complexity: target.complexity, trailing: nil)
            }
        }
        Section("검색 시간(점수 계산)") {
            value("평균", EvaluationRunViewModel.seconds(report.meanSeconds), detail: "목표 0.3초")
            value("최대", EvaluationRunViewModel.seconds(report.maxSeconds), detail: nil)
        }
    }

    @ViewBuilder
    private func accuracyRows(_ accuracy: CalibrationReport.Accuracy) -> some View {
        value("장수", "\(accuracy.count)", detail: nil)
        value("Top 1 · 3 · 10", [accuracy.top1, accuracy.top3, accuracy.top10].map(EvaluationRunViewModel.percentText).joined(separator: " · "), detail: nil)
        value("정답 기준 이상", EvaluationRunViewModel.percentText(accuracy.targetBadgeRate), detail: "정답을 고르면 뱃지")
        value("오답 기준 이상", EvaluationRunViewModel.percentText(accuracy.wrongBadgeRate), detail: "엉뚱한 뱃지 위험")
        value("정답 유사도 중앙값", accuracy.medianTargetPercent.map { "\($0)%" } ?? "-", detail: nil)
    }

    private func value(_ title: String, _ value: String, detail: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                if let detail { Text(detail).font(.caption).foregroundStyle(DSColor.textSecondary) }
            }
            Spacer()
            Text(value).font(.body.monospacedDigit()).foregroundStyle(DSColor.textPrimary)
        }
    }

    private func symbolRow(_ name: String, complexity: Double?, trailing: String?) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: name).frame(width: Metrics.minTapTarget)
            VStack(alignment: .leading) {
                Text(name).font(DSFont.symbolName)
                Text("복잡도 \(EvaluationRunViewModel.complexity(complexity))").font(.caption).foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
            if let trailing { Text(trailing).monospacedDigit() }
        }
    }
}

private struct PreviewPrepare: PrepareSymbolIndexUseCase {
    func status() async -> SymbolIndexStatus { .ready(symbolCount: 3) }
    func execute() -> AsyncThrowingStream<Double, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct PreviewRun: RunCalibrationUseCase {
    func execute(progress: @escaping @Sendable (Double) -> Void) async throws -> CalibrationRun {
        func measure(_ target: Double, rank: Int) -> SampleMeasurement {
            SampleMeasurement(sampleID: UUID(), author: "정민", targetName: "heart", targetScore: target, targetRank: rank, targetComplexity: 0.05,
                              wrongMedian: 0.55, topWrong: [.init(name: "circle", score: 0.93, complexity: 0.02)], seconds: 0.12)
        }
        return CalibrationRun(calibration: [measure(0.9, rank: 1), measure(0.85, rank: 2)], holdout: [measure(0.92, rank: 1)], engineID: "preview")
    }
}

private func previewViewModel() -> EvaluationRunViewModel {
    EvaluationRunViewModel(prepareIndex: PreviewPrepare(), runCalibration: PreviewRun(), currentCalibrator: ScoreCalibrator(sLow: 0.5, sHigh: 0.95))
}

#Preview("라이트") { NavigationStack { EvaluationRunScreen(viewModel: previewViewModel()) }.preferredColorScheme(.light) }
#Preview("다크") { NavigationStack { EvaluationRunScreen(viewModel: previewViewModel()) }.preferredColorScheme(.dark) }
#endif
