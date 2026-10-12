//
//  EmbeddingSymbolSearch.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Accelerate
import Domain

public enum SymbolSearchError: Error, Sendable, Equatable {
    /// 인덱스가 없거나 다른 엔진으로 만들어져 있음 → 먼저 인덱스를 준비해야 함
    case indexNotReady
}

/// 방식 B·C·D의 검색: 그림 → 벡터 → 모든 심볼과 코사인 유사도 → 변형 묶기 → 0~100% 보정.
public actor EmbeddingSymbolSearch: SymbolSearching, SymbolScoring {
    private let pipeline: EmbeddingPipeline
    private let store: SymbolIndexStore
    private let calibrator: ScoreCalibrator
    /// 점수 보정 세기(닮은꼴·방향, 모두 0이면 원래 코사인 그대로)
    private let weights: ScoreWeights
    private var loaded: (index: SymbolIndex, engine: VectorSearchEngine, families: [String])?

    public nonisolated let engineID: String

    public init(pipeline: EmbeddingPipeline, store: SymbolIndexStore, calibrator: ScoreCalibrator, weights: ScoreWeights = .none) {
        self.pipeline = pipeline
        self.store = store
        self.calibrator = calibrator
        self.weights = weights
        self.engineID = pipeline.engineID
    }

    public func search(sketch: Sketch, limit: Int) async throws -> [SymbolMatch] {
        let scored = ScoreAdjustment.adjusted(try await rawScores(for: sketch), weights: weights)
        return VariantGrouper.group(scored, limit: limit).map { group in
            SymbolMatch(
                name: group.representative.name,
                variants: group.variants,
                similarity: calibrator.percent(for: group.score),
                score: group.score
            )
        }
    }

    /// 묶기·보정 전의 원시 점수(모든 심볼). 평가와 보정값 계산에 쓴다.
    public func rawScores(for sketch: Sketch) async throws -> [ScoredSymbol] {
        let loaded = try loadIfNeeded()
        let pipeline = pipeline
        // Vision은 스레드를 오래 붙잡으므로 GCD 스레드에서 돌린다(BlockingWork 참고).
        guard let query = try await BlockingWork.run({ try pipeline.embedWithLayout(sketch) }) else { return [] }
        let scores = loaded.engine.scores(for: query.vector)
        let layoutScores = Self.layoutScores(query.layout, index: loaded.index)
        return loaded.index.names.indices.map { index in
            ScoredSymbol(name: loaded.index.names[index], family: loaded.families[index], score: Double(scores[index]),
                         complexity: Double(loaded.index.complexity[index]), hubness: Double(loaded.index.hubness[index]),
                         layout: layoutScores.map { Double($0[index]) })
        }
    }

    /// 그림과 모든 심볼의 잉크 배치 코사인(`InkLayout`). 인덱스에 배치가 없으면 nil.
    private static func layoutScores(_ query: [Float], index: SymbolIndex) -> [Float]? {
        let dimension = index.layoutDimension
        guard dimension > 0, query.count == dimension, index.layouts.count == index.count * dimension else { return nil }
        var result = [Float](repeating: 0, count: index.count)
        // (count × dimension) · (dimension × 1). 모두 길이 1이라 내적이 코사인이다.
        vDSP_mmul(index.layouts, 1, query, 1, &result, 1, vDSP_Length(index.count), 1, vDSP_Length(dimension))
        return result
    }

    /// 인덱스를 다시 만든 뒤 호출해 새 파일을 읽게 한다.
    public func invalidate() {
        loaded = nil
    }

    private func loadIfNeeded() throws -> (index: SymbolIndex, engine: VectorSearchEngine, families: [String]) {
        if let loaded { return loaded }
        let index: SymbolIndex
        do {
            index = try store.load()
        } catch SymbolIndexStoreError.notFound {
            throw SymbolSearchError.indexNotReady
        }
        guard index.engineID == engineID else { throw SymbolSearchError.indexNotReady }
        let result = (index, VectorSearchEngine(index: index), index.names.map(VariantGrouper.family(of:)))
        loaded = result
        return result
    }
}
