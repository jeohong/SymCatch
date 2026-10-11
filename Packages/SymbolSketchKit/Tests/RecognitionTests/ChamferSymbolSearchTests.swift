//
//  ChamferSymbolSearchTests.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Testing
import Domain
@testable import Recognition

struct DistanceTransformTests {
    @Test func 잉크_픽셀에서_멀어질수록_거리가_커진다() {
        var bitmap = GrayBitmap.blank(width: 5, height: 5)
        bitmap[2, 2] = 0
        let distance = DistanceTransform.compute(bitmap)

        #expect(distance[2 * 5 + 2] == 0)
        #expect(distance[2 * 5 + 3] == 1)                    // 오른쪽 한 칸
        #expect(abs(distance[1 * 5 + 1] - 1.41421356) < 1e-5) // 대각선 한 칸
        #expect(distance[2 * 5 + 0] == 2)                    // 왼쪽 두 칸
    }
}

struct ChamferSymbolSearchTests {
    private let catalog = StubSymbolCatalog(names: ["circle", "triangle", "minus", "square", "circle.fill"])

    private func makeSearch() -> ChamferSymbolSearch {
        ChamferSymbolSearch(catalog: catalog, calibrator: RecognitionMethod.chamfer.provisionalCalibrator)
    }

    @Test(arguments: [
        ("circle", TestSketches.circle),
        ("triangle", TestSketches.triangle),
        ("minus", TestSketches.minus),
    ])
    func 단순한_도형은_정답이_1위(expected: String, sketch: Sketch) async throws {
        let results = try await makeSearch().search(sketch: sketch, limit: 3)
        #expect(results.first?.name == expected || results.first?.variants.contains(expected) == true)
    }

    @Test func 채움_변형은_한_항목으로_묶인다() async throws {
        let results = try await makeSearch().search(sketch: TestSketches.circle, limit: 10)
        let circleGroups = results.filter { VariantGrouper.family(of: $0.name) == "circle" }
        #expect(circleGroups.count == 1)
        #expect(results.allSatisfy { (0...100).contains($0.similarity) })
    }

    @Test func 빈_그림은_빈_결과() async throws {
        #expect(try await makeSearch().search(sketch: .empty, limit: 10).isEmpty)
    }
}
