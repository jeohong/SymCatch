//
//  TestSupport.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain
import Recognition

/// 정해진 심볼 이름만 돌려주는 가짜 카탈로그
struct StubSymbolCatalog: SymbolCatalogRepository {
    let names: [String]

    func allSymbols() async throws -> [SymbolMeta] {
        names.map { SymbolMeta(name: $0, family: VariantGrouper.family(of: $0), categories: [], keywords: [], minOS: "13.0") }
    }

    func categories() async throws -> [SymbolCategory] { [] }

    func symbol(named name: String) async throws -> SymbolMeta? {
        try await allSymbols().first { $0.name == name }
    }

    func symbols(inFamily family: String) async throws -> [SymbolMeta] {
        try await allSymbols().filter { $0.family == family }
    }
}

enum TestSketches {
    /// 중심 (0.5, 0.5), 반지름 0.35인 원 한 획
    static var circle: Sketch {
        let points = (0...48).map { step -> SketchPoint in
            let angle = Double(step) / 48 * 2 * .pi
            return SketchPoint(x: 0.5 + 0.35 * cos(angle), y: 0.5 + 0.35 * sin(angle))
        }
        return Sketch(strokes: [points])
    }

    /// 꼭짓점이 위인 삼각형 한 획
    static var triangle: Sketch {
        let corners = [(0.5, 0.15), (0.85, 0.8), (0.15, 0.8), (0.5, 0.15)]
        return Sketch(strokes: [corners.map { SketchPoint(x: $0.0, y: $0.1) }])
    }

    /// 가로선 한 획
    static var minus: Sketch {
        Sketch(strokes: [[SketchPoint(x: 0.15, y: 0.5), SketchPoint(x: 0.85, y: 0.5)]])
    }
}

func temporaryIndexStore() -> SymbolIndexStore {
    SymbolIndexStore(fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("index-\(UUID().uuidString)")
        .appendingPathComponent("symbols.index"))
}
