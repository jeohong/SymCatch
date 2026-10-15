//
//  InkLayoutTests.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/12/26.
//

import Testing
import Domain
@testable import Recognition

@MainActor
struct InkLayoutTests {
    private let options = PreprocessingOptions(size: 96)

    private func dot(_ a: [Float], _ b: [Float]) -> Float {
        zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }

    private let rightArrow = Sketch(strokes: [
        [SketchPoint(x: 0.1, y: 0.5), SketchPoint(x: 0.9, y: 0.5)],
        [SketchPoint(x: 0.7, y: 0.3), SketchPoint(x: 0.9, y: 0.5), SketchPoint(x: 0.7, y: 0.7)],
    ])
    private let leftArrow = Sketch(strokes: [
        [SketchPoint(x: 0.9, y: 0.5), SketchPoint(x: 0.1, y: 0.5)],
        [SketchPoint(x: 0.3, y: 0.3), SketchPoint(x: 0.1, y: 0.5), SketchPoint(x: 0.3, y: 0.7)],
    ])

    @Test func 길이_1이고_빈_그림은_0() {
        let layout = InkLayout.descriptor(SketchRasterizer(options: options).bitmap(for: rightArrow)!)
        #expect(layout.count == InkLayout.dimension)
        #expect(abs(dot(layout, layout) - 1) < 1e-4)
        #expect(InkLayout.descriptor(.blank(width: 96, height: 96)).allSatisfy { $0 == 0 })
    }

    @Test func 그린_화살표는_같은_방향_심볼과_더_비슷하다() throws {
        let rasterizer = SketchRasterizer(options: options)
        let renderer = SymbolRenderer(options: options, style: .outline)
        let drawn = InkLayout.descriptor(try #require(rasterizer.bitmap(for: rightArrow)))
        let drawnLeft = InkLayout.descriptor(try #require(rasterizer.bitmap(for: leftArrow)))
        let symbolRight = InkLayout.descriptor(try #require(renderer.bitmap(forSymbolNamed: "arrow.right")))
        let symbolLeft = InkLayout.descriptor(try #require(renderer.bitmap(forSymbolNamed: "arrow.left")))

        #expect(dot(drawn, symbolRight) > dot(drawn, symbolLeft))
        #expect(dot(drawnLeft, symbolLeft) > dot(drawnLeft, symbolRight))
    }
}
