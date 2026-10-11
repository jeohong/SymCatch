//
//  EmbeddingPipeline.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import CoreGraphics
import Domain

/// 그림과 심볼을 같은 전처리 → 같은 모델로 벡터로 바꾸는 한 묶음(방식 B·C·D 공통).
public struct EmbeddingPipeline: Sendable {
    public let embedder: any SketchEmbedder
    /// 심볼을 채움 그대로 비교할지, 윤곽선으로 바꿔 비교할지
    public let symbolStyle: SymbolRenderer.Style
    public let options: PreprocessingOptions

    public init(embedder: any SketchEmbedder, symbolStyle: SymbolRenderer.Style, options: PreprocessingOptions? = nil) {
        self.embedder = embedder
        self.symbolStyle = symbolStyle
        self.options = options ?? PreprocessingOptions(size: embedder.inputSize)
    }

    /// 인덱스·보정값을 구분하는 식별자. 모델·전처리가 바뀌면 달라진다.
    public var engineID: String {
        "\(embedder.modelVersion)-\(symbolStyle.rawValue)-s\(options.size)-lw\(Int(options.lineWidthRatio * 1000))"
    }

    var rasterizer: SketchRasterizer { SketchRasterizer(options: options) }
    var renderer: SymbolRenderer { SymbolRenderer(options: options, style: symbolStyle) }

    /// 빈 그림이면 nil.
    func embed(_ sketch: Sketch) throws -> [Float]? {
        guard let image = rasterizer.image(for: sketch) else { return nil }
        return try embedder.embed(image)
    }

    /// 이 OS에 없는 심볼이면 nil. 뱃지 판정용 복잡도도 함께 돌려준다.
    func embedSymbol(named name: String) throws -> (vector: [Float], complexity: Float)? {
        guard let bitmap = renderer.bitmap(forSymbolNamed: name), let image = bitmap.makeCGImage() else { return nil }
        let outline = symbolStyle == .outline ? bitmap : bitmap.outlined(thickness: Int(options.lineWidth.rounded()))
        return (try embedder.embed(image), SymbolComplexity.measure(outline: outline))
    }
}

/// 심볼 모양이 얼마나 복잡한지(0...1). `circle`, `minus`처럼 너무 단순한 심볼은
/// 대충 그려도 높은 점수가 나오므로 뱃지 대상에서 뺄 때 쓴다(기준값은 M0 평가로 정함).
enum SymbolComplexity {
    /// 윤곽선 잉크 픽셀 비율. 테두리가 길고 꺾인 곳이 많을수록 크다.
    static func measure(outline: GrayBitmap) -> Float {
        Float(outline.inkPixelCount) / Float(outline.width * outline.height)
    }
}
