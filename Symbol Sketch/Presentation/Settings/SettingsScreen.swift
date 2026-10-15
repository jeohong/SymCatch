//
//  SettingsScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import SwiftUI
import Domain

/// 설정(S8). 콜렉션 오른쪽 위 톱니로 들어온다.
struct SettingsScreen: View {
    @Bindable var viewModel: SettingsViewModel
    @AppStorage(AppPreferenceKey.theme) private var theme = AppTheme.system
    @AppStorage(AppPreferenceKey.haptics) private var hapticsEnabled = true

    var body: some View {
        Form {
            Section("화면") {
                Picker("테마", selection: $theme) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("햅틱", isOn: $hapticsEnabled)
                    .tint(DSColor.accent)
            } header: {
                Text("피드백")
            } footer: {
                Text("복사와 뱃지 획득 때 진동으로 알려 줘요.")
            }

            Section {
                LabeledContent("심볼 인덱스", value: viewModel.indexStatusText)
                Button("심볼 다시 준비하기") { viewModel.rebuildIndex() }
                    .foregroundStyle(DSColor.accent)
                Button("기록 초기화", role: .destructive) { viewModel.requestReset() }
                    .foregroundStyle(DSColor.danger)
            } header: {
                Text("데이터")
            } footer: {
                Text("모든 데이터는 이 기기 안에만 저장되고 밖으로 나가지 않아요.")
            }

            Section("앱 정보") {
                LabeledContent("버전", value: viewModel.appVersion)
                LabeledContent("인식 방식", value: String(localized: "기기 내 처리"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.bgGrouped)
        .navigationTitle("설정")
        .alert("기록을 초기화할까요?", isPresented: $viewModel.isConfirmingReset) {
            Button("취소", role: .cancel) {}
            Button("초기화", role: .destructive) {
                Task { await viewModel.confirmReset() }
            }
        } message: {
            Text("최근 찾은 심볼, 뱃지, 업적이 모두 지워지고 되돌릴 수 없어요.")
        }
        .toast($viewModel.toast)
        .task { await viewModel.load() }
    }
}

private struct PreviewPrepare: PrepareSymbolIndexUseCase {
    func status() async -> SymbolIndexStatus { .ready(symbolCount: 6_012) }
    func execute() -> AsyncThrowingStream<Double, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct PreviewReset: ResetProgressUseCase {
    func execute() async throws {}
}

private func previewViewModel() -> SettingsViewModel {
    SettingsViewModel(prepareIndex: PreviewPrepare(), resetProgress: PreviewReset(), navigator: nil, appVersion: "1.0 (1)")
}

#Preview("라이트") { NavigationStack { SettingsScreen(viewModel: previewViewModel()) }.preferredColorScheme(.light) }
#Preview("다크") { NavigationStack { SettingsScreen(viewModel: previewViewModel()) }.preferredColorScheme(.dark) }
