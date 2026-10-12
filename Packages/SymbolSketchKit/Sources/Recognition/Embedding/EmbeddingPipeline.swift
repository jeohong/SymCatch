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
        try embedWithLayout(sketch)?.vector
    }

    /// 특징 벡터와 잉크 배치(`InkLayout`)를 함께 만든다. 빈 그림이면 nil.
    func embedWithLayout(_ sketch: Sketch) throws -> (vector: [Float], layout: [Float])? {
        guard let bitmap = rasterizer.bitmap(for: sketch), let image = bitmap.makeCGImage() else { return nil }
        return (try embedder.embed(image), InkLayout.descriptor(bitmap))
    }

    /// 심볼을 렌더링할 포인트 크기(`SymbolImageSource`에 넘김)
    var symbolPointSize: CGFloat { renderer.renderPointSize }

    /// `SymbolImageSource`가 만든 심볼 이미지를 임베딩한다. 복잡도와 잉크 배치(모델이 보는 이미지 기준)도 함께 돌려준다.
    func embedSymbol(_ symbol: CGImage) throws -> SymbolEmbedding? {
        guard let bitmap = renderer.bitmap(from: symbol), let image = bitmap.makeCGImage() else { return nil }
        let outline = symbolStyle == .outline ? bitmap : bitmap.outlined(thickness: Int(options.lineWidth.rounded()))
        return SymbolEmbedding(vector: try embedder.embed(image), complexity: SymbolComplexity.measure(outline: outline),
                               layout: InkLayout.descriptor(bitmap))
    }
}

/// 심볼 하나를 인덱스에 넣을 값
struct SymbolEmbedding: Sendable {
    let vector: [Float]
    let complexity: Float
    let layout: [Float]
}

/// 심볼 모양이 얼마나 복잡한지(0...1). `circle`, `minus`처럼 너무 단순한 심볼은
/// 대충 그려도 높은 점수가 나오므로 뱃지 대상에서 뺄 때 쓴다(기준값은 M0 평가로 정함).
enum SymbolComplexity {
    /// 윤곽선 잉크 픽셀 비율. 테두리가 길고 꺾인 곳이 많을수록 크다.
    static func measure(outline: GrayBitmap) -> Float {
        Float(outline.inkPixelCount) / Float(outline.width * outline.height)
    }
}
