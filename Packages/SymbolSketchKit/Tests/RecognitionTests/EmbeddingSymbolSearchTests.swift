//
//  EmbeddingSymbolSearchTests.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Testing
import Domain
@testable import Recognition

struct VisionFeaturePrintEmbedderTests {
    @Test func 같은_이미지는_거의_같은_벡터() throws {
        let embedder = VisionFeaturePrintEmbedder()
        let image = try #require(SketchRasterizer().image(for: TestSketches.circle))
        let first = try embedder.embed(image)
        let second = try embedder.embed(image)

        #expect(!first.isEmpty)
        // 실행마다 실수 연산 순서가 달라 아주 미세한 차이는 있을 수 있다.
        let similarity = VectorSearchEngine(vectors: first, dimension: first.count).scores(for: second)[0]
        #expect(similarity > 0.9999)
    }
}

/// 인덱스 생성 → 상태 확인 → 검색까지 이어지는 흐름. 정확도는 평가 러너가 따로 잰다.
struct EmbeddingSymbolSearchTests {
    private let catalog = StubSymbolCatalog(names: ["circle", "circle.fill", "triangle", "minus", "no.such.symbol"])
    private let pipeline = RecognitionMethod.visionOutline.embeddingPipeline!

    @Test func 인덱스_상태는_없음에서_준비됨으로_바뀐다() async throws {
        let store = temporaryIndexStore()
        let builder = SymbolIndexBuilder(catalog: catalog, pipeline: pipeline, store: store, osVersion: "27.1")

        #expect(await builder.status() == .missing)
        var progress: [Double] = []
        for try await value in builder.build() { progress.append(value) }

        #expect(progress.last == 1)
        // 이 OS에 없는 이름은 건너뛴다.
        #expect(await builder.status() == .ready(symbolCount: 4))
    }

    @Test func OS나_엔진이_바뀌면_outdated() async throws {
        let store = temporaryIndexStore()
        for try await _ in SymbolIndexBuilder(catalog: catalog, pipeline: pipeline, store: store, osVersion: "27.0").build() {}

        let newOS = SymbolIndexBuilder(catalog: catalog, pipeline: pipeline, store: store, osVersion: "27.1")
        #expect(await newOS.status() == .outdated)

        let otherEngine = SymbolIndexBuilder(catalog: catalog, pipeline: RecognitionMethod.visionFilled.embeddingPipeline!, store: store, osVersion: "27.0")
        #expect(await otherEngine.status() == .outdated)
    }

    @Test func 인덱스가_없으면_indexNotReady() async {
        let search = EmbeddingSymbolSearch(pipeline: pipeline, store: temporaryIndexStore(), calibrator: RecognitionMethod.visionOutline.provisionalCalibrator)
        await #expect(throws: SymbolSearchError.indexNotReady) {
            try await search.search(sketch: TestSketches.circle, limit: 10)
        }
    }

    @Test func 검색_결과는_변형을_묶고_0에서_100_사이() async throws {
        let store = temporaryIndexStore()
        for try await _ in SymbolIndexBuilder(catalog: catalog, pipeline: pipeline, store: store, osVersion: "27.1").build() {}
        let search = EmbeddingSymbolSearch(pipeline: pipeline, store: store, calibrator: RecognitionMethod.visionOutline.provisionalCalibrator)

        let results = try await search.search(sketch: TestSketches.circle, limit: 10)

        #expect(results.count == 3)   // circle(+fill), triangle, minus
        #expect(results.filter { VariantGrouper.family(of: $0.name) == "circle" }.count == 1)
        #expect(results.allSatisfy { (0...100).contains($0.similarity) })
        #expect(results.map(\.similarity) == results.map(\.similarity).sorted(by: >))
    }

    /// 심볼 수가 CPU 코어 수보다 많아도 멈추지 않는다.
    /// (동기 Vision 작업이 Swift 동시성 스레드를 모두 차지해 교착되던 문제의 회귀 테스트)
    @Test(.timeLimit(.minutes(1)))
    func 심볼이_많아도_멈추지_않는다() async throws {
        let names = ["circle", "square", "triangle", "minus", "plus", "heart", "star", "house", "cloud", "bell",
                     "gear", "trash", "folder", "paperplane", "bookmark", "tag", "bolt", "camera", "phone", "envelope",
                     "lock", "key", "flag", "map", "pencil", "scissors", "cart", "gift", "moon", "sun.max",
                     "drop", "flame", "leaf", "globe", "car", "bicycle", "airplane", "tram", "bus", "ferry"]
        let store = temporaryIndexStore()
        let builder = SymbolIndexBuilder(catalog: StubSymbolCatalog(names: names), pipeline: pipeline, store: store, osVersion: "27.1")
        for try await _ in builder.build() {}
        #expect(await builder.status() == .ready(symbolCount: names.count))
    }
}
