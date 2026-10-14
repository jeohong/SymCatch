//
//  PrepareSymbolIndexUseCase.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

public protocol PrepareSymbolIndexUseCase: Sendable {
    /// 인덱스를 만들지 않고 지금 상태만 확인한다.
    func status() async -> SymbolIndexStatus
    /// 인덱스가 준비돼 있으면 바로 끝나고, 아니면 만들면서 진행률(0...1)을 내보낸다.
    func execute() -> AsyncThrowingStream<Double, Error>
    /// 준비돼 있어도 처음부터 다시 만든다(설정 "심볼 다시 준비하기").
    func rebuild() -> AsyncThrowingStream<Double, Error>
}

public extension PrepareSymbolIndexUseCase {
    /// 다시 만들기를 따로 지원하지 않는 구현(테스트 가짜 등)은 일반 준비와 같게 둔다.
    func rebuild() -> AsyncThrowingStream<Double, Error> { execute() }
}

public struct DefaultPrepareSymbolIndexUseCase: PrepareSymbolIndexUseCase {
    private let builder: any SymbolIndexBuilding

    public init(builder: any SymbolIndexBuilding) {
        self.builder = builder
    }

    public func status() async -> SymbolIndexStatus {
        await builder.status()
    }

    public func execute() -> AsyncThrowingStream<Double, Error> {
        stream(force: false)
    }

    public func rebuild() -> AsyncThrowingStream<Double, Error> {
        stream(force: true)
    }

    private func stream(force: Bool) -> AsyncThrowingStream<Double, Error> {
        let builder = builder
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if !force, case .ready = await builder.status() {
                        continuation.yield(1)
                        continuation.finish()
                        return
                    }
                    for try await progress in builder.build() {
                        continuation.yield(progress)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
