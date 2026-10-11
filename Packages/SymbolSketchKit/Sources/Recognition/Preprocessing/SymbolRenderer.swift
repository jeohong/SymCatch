//
//  SymbolRenderer.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import UIKit

/// 심볼을 그림과 같은 전처리로 그린다. 심볼 이미지는 앱에 담지 않고 기기에서 렌더링한다.
public struct SymbolRenderer: Sendable {
    public enum Style: String, Sendable, CaseIterable {
        /// 심볼 모양 그대로(채움 포함)
        case filled
        /// 채운 부분을 테두리 선으로 바꿈(손그림과 비슷하게)
        case outline
    }

    public let options: PreprocessingOptions
    public let style: Style
    /// 렌더링할 때의 포인트 크기. 클수록 잘라 맞출 때 덜 뭉개진다.
    public let renderPointSize: CGFloat

    public init(options: PreprocessingOptions = PreprocessingOptions(), style: Style = .filled, renderPointSize: CGFloat = 200) {
        self.options = options
        self.style = style
        self.renderPointSize = renderPointSize
    }

    /// 이 기기 OS에 없는 심볼이면 nil.
    public func bitmap(forSymbolNamed name: String) -> GrayBitmap? {
        let configuration = UIImage.SymbolConfiguration(pointSize: renderPointSize, weight: .regular)
        guard let symbol = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(.black, renderingMode: .alwaysOriginal),
              let raw = Self.draw(symbol),
              let bounds = raw.inkBounds,
              let context = GrayBitmap.makeContext(width: options.size, height: options.size),
              let rawImage = raw.makeCGImage() else { return nil }

        let contentWidth = CGFloat(bounds.maxX - bounds.minX + 1)
        let contentHeight = CGFloat(bounds.maxY - bounds.minY + 1)
        let (scale, origin) = options.fit(contentWidth: contentWidth, contentHeight: contentHeight)

        // 잉크 영역만 잘라 여백 안 정사각형에 비율을 지켜 넣는다.
        guard let cropped = rawImage.cropping(to: CGRect(
            x: bounds.minX, y: bounds.minY, width: Int(contentWidth), height: Int(contentHeight)
        )) else { return nil }
        context.interpolationQuality = .high
        // CGContext는 아래가 0이므로 위 기준 origin을 바꿔서 그린다.
        let drawRect = CGRect(
            x: origin.x,
            y: CGFloat(options.size) - origin.y - contentHeight * scale,
            width: contentWidth * scale,
            height: contentHeight * scale
        )
        context.draw(cropped, in: drawRect)

        guard let fitted = GrayBitmap(context: context) else { return nil }
        switch style {
        case .filled:
            return fitted
        case .outline:
            return fitted.outlined(thickness: Int(options.lineWidth.rounded()))
        }
    }

    public func image(forSymbolNamed name: String) -> CGImage? {
        bitmap(forSymbolNamed: name)?.makeCGImage()
    }

    /// 심볼 UIImage를 흰 바탕 흑백 비트맵으로 그린다.
    private static func draw(_ image: UIImage) -> GrayBitmap? {
        let width = Int(image.size.width.rounded(.up)) + 2
        let height = Int(image.size.height.rounded(.up)) + 2
        guard width > 2, height > 2, let context = GrayBitmap.makeContext(width: width, height: height) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 1, y: 1, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        return GrayBitmap(context: context)
    }
}
