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

    /// 한 번에 메인 스레드에서 만들 심볼 이미지 수
    static let batchSize = 256

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

        // 심볼 이미지 만들기(UIKit)는 메인 스레드에서, 전처리·Vision은 GCD 스레드에서 병렬로(BlockingWork 참고).
        // 묶음 단위로 번갈아 돌려 메인 스레드를 오래 잡지 않는다.
        let pipeline = pipeline
        let total = names.count
        var results: [(vector: [Float], complexity: Float)?] = []
        results.reserveCapacity(total)
        for start in stride(from: 0, to: total, by: Self.batchSize) {
            let batch = Array(names[start..<min(start + Self.batchSize, total)])
            let images = await SymbolImageSource.images(named: batch, pointSize: pipeline.symbolPointSize)
            let part = try await BlockingWork.concurrentMap(count: images.count, progress: { done in
                let overall = start + done
                if overall % 50 == 0 || overall == total { progress(Double(overall) / Double(total)) }
            }) { index -> (vector: [Float], complexity: Float)? in
                guard let image = images[index] else { return nil }
                return try pipeline.embedSymbol(image)
            }
            results.append(contentsOf: part)
            try Task.checkCancellation()
        }

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

        // 만능 닮은꼴 정도: 모든 심볼 쌍의 코사인을 계산하므로 GCD 스레드에서 돌린다(BlockingWork 참고).
        let families = keptNames.map(VariantGrouper.family(of:))
        let hubness = try await BlockingWork.run { [vectors, dimension] in
            SymbolHubness.compute(vectors: vectors, dimension: dimension, families: families)
        }
        try store.save(SymbolIndex(
            engineID: pipeline.engineID,
            osVersion: osVersion,
            names: keptNames,
            complexity: complexity,
            hubness: hubness,
            dimension: dimension,
            vectors: vectors
        ))
        progress(1)
    }
}
