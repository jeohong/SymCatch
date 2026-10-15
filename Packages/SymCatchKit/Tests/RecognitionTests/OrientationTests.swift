//
//  OrientationTests.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/12/26.
//

import Testing
import Domain
@testable import Recognition

/// 전처리가 그림·심볼을 뒤집거나 돌리지 않는지 확인한다(→를 그렸는데 ←가 위에 나온 원인 조사, 2026-10-12).
@MainActor
struct OrientationTests {
    let options = PreprocessingOptions(size: 96)

    /// 화살촉이 있는 쪽은 잉크가 세로로 넓게 퍼진다. 왼쪽·오른쪽 끝 20% 열에서 잉크가 있는 행 수를 센다.
    private func spread(_ bitmap: GrayBitmap, columns: Range<Int>) -> Int {
        (0..<bitmap.height).filter { y in columns.contains { bitmap.isInk(x: $0, y: y) } }.count
    }

    private func headIsRight(_ bitmap: GrayBitmap) -> Bool {
        let band = bitmap.width / 5
        return spread(bitmap, columns: bitmap.width - band..<bitmap.width) > spread(bitmap, columns: 0..<band)
    }

    private func headIsTop(_ bitmap: GrayBitmap) -> Bool {
        let band = bitmap.height / 5
        func rowsSpread(_ rows: Range<Int>) -> Int {
            (0..<bitmap.width).filter { x in rows.contains { bitmap.isInk(x: x, y: $0) } }.count
        }
        return rowsSpread(0..<band) > rowsSpread(bitmap.height - band..<bitmap.height)
    }

    /// → : 가로선 + 오른쪽 끝 화살촉
    private let rightArrow = Sketch(strokes: [
        [SketchPoint(x: 0.1, y: 0.5), SketchPoint(x: 0.9, y: 0.5)],
        [SketchPoint(x: 0.7, y: 0.3), SketchPoint(x: 0.9, y: 0.5), SketchPoint(x: 0.7, y: 0.7)],
    ])

    /// ↑ : 세로선 + 위쪽 끝 화살촉(캔버스 좌표는 위가 0)
    private let upArrow = Sketch(strokes: [
        [SketchPoint(x: 0.5, y: 0.9), SketchPoint(x: 0.5, y: 0.1)],
        [SketchPoint(x: 0.3, y: 0.3), SketchPoint(x: 0.5, y: 0.1), SketchPoint(x: 0.7, y: 0.3)],
    ])

    @Test func 그림은_좌우_상하가_그대로다() throws {
        let rasterizer = SketchRasterizer(options: options)
        #expect(headIsRight(try #require(rasterizer.bitmap(for: rightArrow))))
        #expect(headIsTop(try #require(rasterizer.bitmap(for: upArrow))))
    }

    @Test func 심볼도_좌우_상하가_그대로다() throws {
        let renderer = SymbolRenderer(options: options, style: .outline)
        #expect(headIsRight(try #require(renderer.bitmap(forSymbolNamed: "arrow.right"))))
        #expect(!headIsRight(try #require(renderer.bitmap(forSymbolNamed: "arrow.left"))))
        #expect(headIsTop(try #require(renderer.bitmap(forSymbolNamed: "arrow.up"))))
    }

    @Test func 비전에_넘기는_이미지도_방향이_같다() throws {
        // GrayBitmap → CGImage → 다시 GrayBitmap으로 돌려도 화살촉 위치가 같아야 한다.
        let sketchBitmap = try #require(SketchRasterizer(options: options).bitmap(for: rightArrow))
        let sketchImage = try #require(sketchBitmap.makeCGImage())
        #expect(headIsRight(try #require(GrayBitmap(image: sketchImage))))

        let symbolImage = try #require(SymbolRenderer(options: options, style: .outline).bitmap(forSymbolNamed: "arrow.right")?.makeCGImage())
        #expect(headIsRight(try #require(GrayBitmap(image: symbolImage))))
    }
}
