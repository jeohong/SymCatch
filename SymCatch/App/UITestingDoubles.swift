//
//  UITestingDoubles.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/14/26.
//

#if DEBUG
import Foundation
import Domain

/// UI 테스트에서 공통 상태(기획서 6장)를 일부러 만들기 위한 실행 인자와 가짜 UseCase. DEBUG 빌드에만 있다.
enum UITestingStates {
    /// 첫 준비가 한 번 실패한다 → 오류 상태와 "다시 준비하기"
    static let indexFailureArgument = "-UITestingIndexFailure"
    /// 준비가 몇 초 동안 진행률을 보이며 천천히 끝난다 → 준비 중 상태
    static let slowPrepareArgument = "-UITestingSlowPrepare"
    /// 검색이 1.5초 걸린다 → 스켈레톤과 "찾는 중"
    static let slowSearchArgument = "-UITestingSlowSearch"

    private static func has(_ argument: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    static func prepare(_ base: any PrepareSymbolIndexUseCase) -> any PrepareSymbolIndexUseCase {
        if has(indexFailureArgument) { return StagedPrepare(base: base, firstRun: .fail) }
        if has(slowPrepareArgument) { return StagedPrepare(base: base, firstRun: .slow) }
        return base
    }

    static func search(_ base: any SearchSymbolsUseCase) -> any SearchSymbolsUseCase {
        has(slowSearchArgument) ? SlowSearch(base: base) : base
    }
}

nonisolated private struct UITestingIndexError: LocalizedError {
    var errorDescription: String? { "UI 테스트: 인덱스 파일 손상" }
}

/// 첫 준비만 실패하거나 천천히 진행하고, 그다음부터는 실제 준비를 그대로 쓴다.
nonisolated private struct StagedPrepare: PrepareSymbolIndexUseCase {
    enum FirstRun { case fail, slow }

    let base: any PrepareSymbolIndexUseCase
    let firstRun: FirstRun
    private let started = Flag()

    init(base: any PrepareSymbolIndexUseCase, firstRun: FirstRun) {
        self.base = base
        self.firstRun = firstRun
    }

    func status() async -> SymbolIndexStatus {
        // 첫 준비 전에는 "없음"으로 답해 준비를 시작하게 한다.
        started.isSet ? await base.status() : (firstRun == .fail ? .corrupted : .missing)
    }

    func execute() -> AsyncThrowingStream<Double, Error> {
        guard started.setOnce() else { return base.execute() }
        let base = base, firstRun = firstRun
        return AsyncThrowingStream { continuation in
            let task = Task {
                switch firstRun {
                case .fail:
                    try? await Task.sleep(for: .milliseconds(300))
                    continuation.finish(throwing: UITestingIndexError())
                case .slow:
                    for step in 0...20 {
                        continuation.yield(Double(step) / 20)
                        try? await Task.sleep(for: .milliseconds(250))
                    }
                    do {
                        for try await _ in base.execute() {}
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func rebuild() -> AsyncThrowingStream<Double, Error> { base.rebuild() }
}

nonisolated private struct SlowSearch: SearchSymbolsUseCase {
    let base: any SearchSymbolsUseCase

    func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome {
        try await Task.sleep(for: .seconds(1.5))
        return try await base.execute(sketch: sketch, limit: limit)
    }
}

/// 한 번만 켜지는 표시(여러 스레드에서 불릴 수 있다)
nonisolated private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool { lock.withLock { value } }

    /// 처음 켤 때만 true
    func setOnce() -> Bool {
        lock.withLock {
            defer { value = true }
            return !value
        }
    }
}
#endif
