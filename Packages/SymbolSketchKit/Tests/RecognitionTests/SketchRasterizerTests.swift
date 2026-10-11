//
//  SketchRasterizerTests.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Testing
import Domain
@testable import Recognition

struct SketchRasterizerTests {
    let options = PreprocessingOptions(size: 64, marginRatio: 0.1, lineWidthRatio: 0.05)

    /// 정사각형 테두리를 (x, y)에서 한 변 side로 그린 그림
    private func square(x: Double, y: Double, side: Double) -> Sketch {
        let points = [(x, y), (x + side, y), (x + side, y + side), (x, y + side), (x, y)]
        return Sketch(strokes: [points.map { SketchPoint(x: $0.0, y: $0.1) }])
    }

    @Test func 빈_그림은_nil() {
        #expect(SketchRasterizer(options: options).bitmap(for: .empty) == nil)
    }

    @Test func 출력은_지정한_크기의_흰_바탕_검은_선이다() throws {
        let bitmap = try #require(SketchRasterizer(options: options).bitmap(for: square(x: 0.2, y: 0.2, side: 0.6)))

        #expect(bitmap.width == 64 && bitmap.height == 64)
        #expect(bitmap[0, 0] == 255)          // 모서리는 여백(흰색)
        #expect(bitmap.inkPixelCount > 0)
        #expect(bitmap.makeCGImage() != nil)
    }

    @Test func 내용을_여백_안에_가운데로_맞춘다() throws {
        // 캔버스 왼쪽 위 구석에 작게 그려도 결과는 가운데에 크게 놓인다.
        let bitmap = try #require(SketchRasterizer(options: options).bitmap(for: square(x: 0.02, y: 0.02, side: 0.2)))
        let bounds = try #require(bitmap.inkBounds)
        let margin = Int(Double(options.size) * options.marginRatio)

        #expect(bounds.minX >= margin - 1 && bounds.minY >= margin - 1)
        #expect(bounds.maxX <= options.size - margin && bounds.maxY <= options.size - margin)
        #expect(abs((bounds.minX + bounds.maxX) / 2 - options.size / 2) <= 1)
    }

    @Test func 크기와_위치가_달라도_같은_모양이면_같은_이미지() throws {
        let rasterizer = SketchRasterizer(options: options)
        let small = try #require(rasterizer.bitmap(for: square(x: 0.05, y: 0.6, side: 0.25)))
        let large = try #require(rasterizer.bitmap(for: square(x: 0.1, y: 0.1, side: 0.8)))

        let different = zip(small.pixels, large.pixels).filter { abs(Int($0) - Int($1)) > 64 }.count
        #expect(different <= small.pixels.count / 100)
    }

    @Test func 점_하나만_찍어도_그려진다() throws {
        let dot = Sketch(strokes: [[SketchPoint(x: 0.5, y: 0.5)]])
        let bitmap = try #require(SketchRasterizer(options: options).bitmap(for: dot))
        #expect(bitmap.inkPixelCount > 0)
    }
}
