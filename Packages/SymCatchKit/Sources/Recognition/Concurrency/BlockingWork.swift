//
//  BlockingWork.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// Vision·UIKit 렌더링처럼 스레드를 오래 붙잡는 동기 작업을 GCD 스레드에서 실행한다.
///
/// Swift 동시성의 협력 스레드는 CPU 코어 수만큼만 있다. 그 스레드들을 모두 동기 작업이 차지하면
/// Vision 내부가 기다리는 작업이 실행될 스레드가 없어 전체가 멈춘다(심볼 40개 병렬 임베딩에서 재현됨).
/// 그래서 무거운 동기 작업은 반드시 이 타입을 거쳐 실행한다.
enum BlockingWork {
    /// 동기 작업 하나를 GCD 스레드에서 실행하고 결과를 기다린다.
    /// - Parameter qos: 사용자가 기다리는 검색은 `.userInitiated`, 오래 걸리는 준비 작업은 `.utility`(화면 반응을 지키기 위함)
    static func run<T: Sendable>(qos: DispatchQoS.QoSClass = .userInitiated, _ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: qos).async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    /// `0..<count`를 GCD 스레드에서 병렬로 변환한다. 결과 순서는 입력 순서와 같다.
    /// - Parameters:
    ///   - progress: 끝난 개수가 바뀔 때 불린다(여러 스레드에서 불릴 수 있음).
    ///   - transform: nil을 돌려주면 그 항목은 건너뛴다.
    static func concurrentMap<T: Sendable>(
        count: Int,
        progress: @escaping @Sendable (Int) -> Void = { _ in },
        _ transform: @escaping @Sendable (Int) throws -> T?
    ) async throws -> [T?] {
        let state = MapState<T>(count: count)
        // 모든 코어를 쓰는 긴 작업이므로 낮은 우선순위로 돌려 화면이 버벅이지 않게 한다.
        return try await withTaskCancellationHandler {
            try await run(qos: .utility) {
                DispatchQueue.concurrentPerform(iterations: count) { index in
                    guard !state.shouldStop else { return }
                    do {
                        let value = try transform(index)
                        progress(state.store(value, at: index))
                    } catch {
                        state.fail(error)
                    }
                }
                return try state.finish()
            }
        } onCancel: {
            state.cancel()
        }
    }
}

/// `concurrentMap`의 공유 상태. 잠금으로 보호한다.
private final class MapState<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [T?]
    private var completed = 0
    private var error: Error?
    private var cancelled = false

    init(count: Int) {
        results = Array(repeating: nil, count: count)
    }

    var shouldStop: Bool {
        lock.withLock { cancelled || error != nil }
    }

    /// 저장하고 지금까지 끝난 개수를 돌려준다.
    func store(_ value: T?, at index: Int) -> Int {
        lock.withLock {
            results[index] = value
            completed += 1
            return completed
        }
    }

    func fail(_ error: Error) {
        lock.withLock { if self.error == nil { self.error = error } }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }

    func finish() throws -> [T?] {
        try lock.withLock {
            if cancelled { throw CancellationError() }
            if let error { throw error }
            return results
        }
    }
}
