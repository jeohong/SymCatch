//
//  SymbolIndexBuilder.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 기기에서 모든 심볼을 렌더링·임베딩해 인덱스 파일을 만든다(기획서 9.3).
/// 이 OS에서 그릴 수 없는 심볼(더 새 OS 전용)은 건너뛴다.
public struct SymbolIndexBuilder: SymbolIndexBuilding {
    private let catalog: any SymbolCatalogRepository
    private let pipeline: EmbeddingPipeline
    private let store: SymbolIndexStore
    private let osVersion: String

    public init(
        catalog: any SymbolCatalogRepository,
        pipeline: EmbeddingPipeline,
        store: SymbolIndexStore,
        osVersion: String = SymbolIndexBuilder.currentOSVersion
    ) {
        self.catalog = catalog
        self.pipeline = pipeline
        self.store = store
        self.osVersion = osVersion
    }

    public static var currentOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    public func status() async -> SymbolIndexStatus {
        do {
            let header = try store.loadHeader()
            guard header.engineID == pipeline.engineID, header.osVersion == osVersion else { return .outdated }
            return .ready(symbolCount: header.count)
        } catch SymbolIndexStoreError.notFound {
            return .missing
        } catch SymbolIndexStoreError.unsupportedFormat {
            return .outdated
        } catch {
            return .corrupted
        }
    }

    public func build() -> AsyncThrowingStream<Double, Error> {
        let (stream, continuation) = AsyncThrowingStream<Double, Error>.makeStream()
        let task = Task.detached(priority: .userInitiated) { [self] in
            do {
                try await run { continuation.yield($0) }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    private func run(progress: @escaping @Sendable (Double) -> Void) async throws {
        let names = try await catalog.allSymbols().map(\.name)
        progress(0)

        // 렌더링·Vision은 스레드를 오래 붙잡으므로 GCD 스레드에서 병렬로 돌린다(BlockingWork 참고).
        let pipeline = pipeline
        let total = names.count
        let results = try await BlockingWork.concurrentMap(count: total, progress: { done in
            if done % 50 == 0 || done == total { progress(Double(done) / Double(total)) }
        }) { index in
            try pipeline.embedSymbol(named: names[index])
        }
        try Task.checkCancellation()

        var keptNames: [String] = [], complexity: [Float] = [], vectors: [Float] = []
        var dimension = 0
        for (name, result) in zip(names, results) {
            guard let result else { continue }
            if dimension == 0 { dimension = result.vector.count }
            guard result.vector.count == dimension else { continue }
            keptNames.append(name)
            complexity.append(result.complexity)
            vectors.append(contentsOf: result.vector)
        }

        try store.save(SymbolIndex(
            engineID: pipeline.engineID,
            osVersion: osVersion,
            names: keptNames,
            complexity: complexity,
            dimension: dimension,
            vectors: vectors
        ))
        progress(1)
    }
}
