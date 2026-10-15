//
//  SettingsViewModel.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/14/26.
//

import Foundation
import Domain

/// 설정(S8): 심볼 인덱스 상태·다시 준비하기, 기록 초기화, 앱 정보(DESIGN_NOTES S8).
/// 테마·햅틱은 화면에서 `@AppStorage`로 바로 저장한다(`AppPreferenceKey`).
@MainActor @Observable
final class SettingsViewModel {
    private(set) var indexStatus: SymbolIndexStatus?
    /// "기록 초기화" 확인 알림을 띄웠는지
    var isConfirmingReset = false
    /// 화면 아래 짧은 알림
    var toast: ToastMessage?

    /// "1.0 (1)"
    let appVersion: String

    private let prepareIndex: any PrepareSymbolIndexUseCase
    private let resetProgress: any ResetProgressUseCase
    private weak var navigator: (any SettingsNavigating)?

    init(prepareIndex: any PrepareSymbolIndexUseCase, resetProgress: any ResetProgressUseCase,
         navigator: (any SettingsNavigating)?, appVersion: String) {
        self.prepareIndex = prepareIndex
        self.resetProgress = resetProgress
        self.navigator = navigator
        self.appVersion = appVersion
    }

    /// 심볼 인덱스 줄의 오른쪽 값: "6,012개 · 준비 완료" 등
    var indexStatusText: String {
        switch indexStatus {
        case nil: ""
        case .ready(let count): String(localized: "\(count.formatted())개 · 준비 완료")
        case .missing: String(localized: "준비 전")
        case .outdated: String(localized: "다시 준비 필요")
        case .corrupted: String(localized: "손상됨 · 다시 준비 필요")
        }
    }

    func load() async {
        indexStatus = await prepareIndex.status()
    }

    /// "심볼 다시 준비하기": 그리기 탭으로 가서 처음부터 다시 만든다.
    func rebuildIndex() {
        navigator?.rebuildSymbolIndex()
    }

    func requestReset() {
        isConfirmingReset = true
    }

    /// 알림의 "초기화"
    func confirmReset() async {
        isConfirmingReset = false
        do {
            try await resetProgress.execute()
            toast = ToastMessage(text: String(localized: "기록을 초기화했어요"))
        } catch {
            toast = ToastMessage(text: String(localized: "초기화하지 못했어요"), systemImage: "exclamationmark.triangle.fill")
        }
    }
}
