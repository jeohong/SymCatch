//
//  SymbolRendererTests.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Testing
@testable import Recognition

struct SymbolRendererTests {
    let options = PreprocessingOptions(size: 96)

    @Test func 심볼을_여백_안_가운데에_그린다() throws {
        let bitmap = try #require(SymbolRenderer(options: options).bitmap(forSymbolNamed: "heart"))
        let bounds = try #require(bitmap.inkBounds)
        let margin = Int(Double(options.size) * options.marginRatio)

        #expect(bitmap.width == 96)
        #expect(bounds.minX >= margin - 1 && bounds.maxX <= options.size - margin)
        // 긴 변이 여백 안 정사각형을 거의 꽉 채운다.
        let longest = max(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY) + 1
        #expect(Double(longest) >= Double(options.contentSide) * 0.95)
    }

    @Test func 없는_심볼은_nil() {
        #expect(SymbolRenderer(options: options).bitmap(forSymbolNamed: "no.such.symbol.name") == nil)
    }

    @Test func 윤곽선_변환은_채운_심볼의_잉크를_줄인다() throws {
        let filled = try #require(SymbolRenderer(options: options, style: .filled).bitmap(forSymbolNamed: "heart.fill"))
        let outline = try #require(SymbolRenderer(options: options, style: .outline).bitmap(forSymbolNamed: "heart.fill"))

        #expect(outline.inkPixelCount > 0)
        #expect(outline.inkPixelCount < filled.inkPixelCount / 2)
        // 가운데(채워졌던 곳)는 비어 있다.
        #expect(!outline.isInk(x: options.size / 2, y: options.size / 2))
    }
}

struct MorphologyTests {
    /// 20×20 흰 바탕에 (x0, y0)부터 width×height 크기의 검은 사각형
    private func block(x0: Int, y0: Int, width: Int, height: Int) -> GrayBitmap {
        var bitmap = GrayBitmap.blank(width: 20, height: 20)
        for y in y0..<y0 + height {
            for x in x0..<x0 + width { bitmap[x, y] = 0 }
        }
        return bitmap
    }

    @Test func 선_굵기보다_가는_선은_그대로_남는다() {
        // 두께 3인 가로선, 테두리 두께 2 → 침식하면 모두 사라지므로 전부 테두리로 남는다.
        let line = block(x0: 2, y0: 8, width: 16, height: 3)
        #expect(line.outlined(thickness: 2) == line)
    }

    @Test func 채운_사각형은_두께만큼의_테두리만_남는다() {
        let filled = block(x0: 2, y0: 2, width: 16, height: 16)
        let outline = filled.outlined(thickness: 2)

        #expect(outline.isInk(x: 2, y: 2))       // 바깥 모서리
        #expect(outline.isInk(x: 3, y: 10))      // 테두리 안쪽(두께 2)
        #expect(!outline.isInk(x: 4, y: 10))     // 테두리보다 안쪽은 비움
        #expect(!outline.isInk(x: 10, y: 10))    // 가운데는 비움
        #expect(!outline.isInk(x: 0, y: 0))      // 바탕은 그대로
    }

    @Test func 두께가_0이면_변화_없음() {
        let filled = block(x0: 2, y0: 2, width: 16, height: 16)
        #expect(filled.outlined(thickness: 0) == filled)
    }
}
