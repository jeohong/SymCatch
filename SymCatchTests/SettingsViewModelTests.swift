//
//  SettingsViewModelTests.swift
//  SymCatchTests
//
//  Created by Hongjeongmin on 10/14/26.
//

import Foundation
import Testing
import SwiftUI
import Domain
@testable import SymCatch

private struct StubPrepare: PrepareSymbolIndexUseCase {
    var status: SymbolIndexStatus
    func status() async -> SymbolIndexStatus { status }
    func execute() -> AsyncThrowingStream<Double, Error> { AsyncThrowingStream { $0.finish() } }
}

private final class SpyReset: ResetProgressUseCase, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var failure: Error?
    var resetCount: Int { lock.withLock { count } }
    func execute() async throws {
        if let failure { throw failure }
        lock.withLock { count += 1 }
    }
}

@MainActor
private final class SpySettingsNavigator: SettingsNavigating {
    var rebuilds = 0
    func rebuildSymbolIndex() { rebuilds += 1 }
}

private struct ResetFailed: Error {}

@MainActor
struct SettingsViewModelTests {
    private func makeViewModel(status: SymbolIndexStatus = .ready(symbolCount: 6_012), reset: SpyReset = SpyReset(),
                               navigator: SpySettingsNavigator? = nil) -> SettingsViewModel {
        SettingsViewModel(prepareIndex: StubPrepare(status: status), resetProgress: reset, navigator: navigator, appVersion: "1.0 (1)")
    }

    @Test func 인덱스_상태를_보여준다() async {
        let ready = makeViewModel()
        await ready.load()
        #expect(ready.indexStatusText.hasSuffix("개 · 준비 완료"))
        #expect(ready.indexStatusText.contains("6"))

        let missing = makeViewModel(status: .missing)
        await missing.load()
        #expect(missing.indexStatusText == "준비 전")
    }

    @Test func 초기화는_확인_후에만_하고_결과를_알린다() async {
        let reset = SpyReset()
        let viewModel = makeViewModel(reset: reset)

        viewModel.requestReset()
        #expect(viewModel.isConfirmingReset)
        #expect(reset.resetCount == 0)

        await viewModel.confirmReset()
        #expect(!viewModel.isConfirmingReset)
        #expect(reset.resetCount == 1)
        #expect(viewModel.toast?.text == "기록을 초기화했어요")
    }

    @Test func 초기화에_실패하면_알린다() async {
        let reset = SpyReset()
        reset.failure = ResetFailed()
        let viewModel = makeViewModel(reset: reset)
        await viewModel.confirmReset()
        #expect(viewModel.toast?.text == "초기화하지 못했어요")
    }

    @Test func 다시_준비하기는_라우터에_알린다() {
        let navigator = SpySettingsNavigator()
        makeViewModel(navigator: navigator).rebuildIndex()
        #expect(navigator.rebuilds == 1)
    }

    @Test func 테마_값과_색_모드() {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
        #expect(AppTheme(rawValue: "dark") == .dark)
    }
}
