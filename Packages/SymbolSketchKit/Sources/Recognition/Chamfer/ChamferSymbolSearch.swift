//
//  ChamferSymbolSearch.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 방식 A: 모델 없이 선과 선 사이 거리(양방향 Chamfer 거리)로 비교한다. 정확도 비교의 기준선.
///
/// 거리 d = ½·(그림 선 위 점에서 심볼 선까지 평균 거리) + ½·(심볼 선 위 점에서 그림 선까지 평균 거리).
/// 점수 = −d ÷ 이미지 한 변(클수록 비슷함). 0%·100% 기준은 `ScoreCalibrator`가 정한다.
///
/// 모든 심볼의 윤곽선과 거리 지도를 메모리에 만들어 둔다(파일로 저장하지 않음).
/// 처음 검색할 때 또는 `prepare()`를 부를 때 만들며, 심볼 8,000개 기준 수십 초가 걸릴 수 있다.
public actor ChamferSymbolSearch: SymbolSearching {
    public nonisolated let engineID: String

    private let catalog: any SymbolCatalogRepository
    private let calibrator: ScoreCalibrator
    private let options: PreprocessingOptions
    private var templates: [Template]?

    private struct Template: Sendable {
        let name: String
        let family: String
        /// 윤곽선 잉크 픽셀 위치(y × size + x)
        let inkIndices: [Int32]
        /// 각 픽셀에서 윤곽선까지 거리
        let distance: [Float]
    }

    public init(catalog: any SymbolCatalogRepository, calibrator: ScoreCalibrator, options: PreprocessingOptions = PreprocessingOptions(size: 48)) {
        self.catalog = catalog
        self.calibrator = calibrator
        self.options = options
        self.engineID = "chamfer-outline-s\(options.size)-lw\(Int(options.lineWidthRatio * 1000))"
    }

    /// 모든 심볼의 윤곽선·거리 지도를 미리 만든다.
    public func prepare() async throws {
        _ = try await loadTemplates()
    }

    public func search(sketch: Sketch, limit: Int) async throws -> [SymbolMatch] {
        let scored = try await rawScores(for: sketch)
        return VariantGrouper.group(scored, limit: limit).map { group in
            SymbolMatch(
                name: group.representative.name,
                variants: group.variants,
                similarity: calibrator.percent(for: group.representative.score)
            )
        }
    }

    public func rawScores(for sketch: Sketch) async throws -> [ScoredSymbol] {
        let templates = try await loadTemplates()
        guard let bitmap = SketchRasterizer(options: options).bitmap(for: sketch) else { return [] }
        let sketchInk = Self.inkIndices(of: bitmap)
        guard !sketchInk.isEmpty else { return [] }
        let sketchDistance = DistanceTransform.compute(bitmap)
        let side = Float(options.size)

        return templates.map { template in
            let forward = Self.meanDistance(at: sketchInk, in: template.distance)
            let backward = Self.meanDistance(at: template.inkIndices, in: sketchDistance)
            let score = -(forward + backward) / 2 / side
            return ScoredSymbol(name: template.name, family: template.family, score: Double(score))
        }
    }

    private func loadTemplates() async throws -> [Template] {
        if let templates { return templates }
        let names = try await catalog.allSymbols().map(\.name)
        let renderer = SymbolRenderer(options: options, style: .outline)

        // 렌더링은 스레드를 오래 붙잡으므로 GCD 스레드에서 병렬로 돌린다(BlockingWork 참고).
        let built = try await BlockingWork.concurrentMap(count: names.count) { index -> Template? in
            let name = names[index]
            guard let bitmap = renderer.bitmap(forSymbolNamed: name) else { return nil }
            let ink = Self.inkIndices(of: bitmap)
            guard !ink.isEmpty else { return nil }
            return Template(name: name, family: VariantGrouper.family(of: name), inkIndices: ink, distance: DistanceTransform.compute(bitmap))
        }.compactMap { $0 }
        templates = built
        return built
    }

    private static func inkIndices(of bitmap: GrayBitmap) -> [Int32] {
        bitmap.pixels.indices.compactMap { bitmap.pixels[$0] < GrayBitmap.inkThreshold ? Int32($0) : nil }
    }

    private static func meanDistance(at indices: [Int32], in distance: [Float]) -> Float {
        guard !indices.isEmpty else { return 0 }
        var sum: Float = 0
        for index in indices { sum += distance[Int(index)] }
        return sum / Float(indices.count)
    }
}
