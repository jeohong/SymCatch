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
    /// 렌더링할 때의 포인트 크기. 화면 배율(2~3배)이 곱해져 약 150~220픽셀로 그려진다.
    /// 모델 입력(224)보다 크게 그려 봐야 줄일 때 버려지고, 크게 그릴수록 메인 스레드 렌더링이 느려진다
    /// (200pt로 그리면 iPhone 13에서 방식 A 준비에 170초 이상 걸렸다).
    public let renderPointSize: CGFloat

    public init(options: PreprocessingOptions = PreprocessingOptions(), style: Style = .filled, renderPointSize: CGFloat = 72) {
        self.options = options
        self.style = style
        self.renderPointSize = renderPointSize
    }

    /// 심볼 이름으로 바로 그린다(메인 스레드 전용 — `SymbolImageSource`를 쓰기 때문). 이 OS에 없는 심볼이면 nil.
    @MainActor
    public func bitmap(forSymbolNamed name: String) -> GrayBitmap? {
        SymbolImageSource.image(named: name, pointSize: renderPointSize).flatMap(bitmap(from:))
    }

    @MainActor
    public func image(forSymbolNamed name: String) -> CGImage? {
        bitmap(forSymbolNamed: name)?.makeCGImage()
    }

    /// `SymbolImageSource`가 만든 심볼 이미지를 전처리한다. CoreGraphics만 쓰므로 어느 스레드에서나 안전하다.
    public func bitmap(from symbol: CGImage) -> GrayBitmap? {
        guard let raw = Self.draw(symbol),
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

    /// 심볼 이미지(검은 모양 + 투명 바탕)를 흰 바탕 흑백 비트맵으로 그린다.
    /// 화면 배율(3배 등)로 커진 심볼 이미지를 긴 변 `maxRawSide` 픽셀 이하로 줄여 그린다(잉크 영역 계산을 가볍게).
    private static func draw(_ image: CGImage, maxRawSide: CGFloat = 200) -> GrayBitmap? {
        guard image.width > 0, image.height > 0 else { return nil }
        let scale = min(1, maxRawSide / CGFloat(max(image.width, image.height)))
        let drawWidth = (CGFloat(image.width) * scale).rounded(.up)
        let drawHeight = (CGFloat(image.height) * scale).rounded(.up)
        guard let context = GrayBitmap.makeContext(width: Int(drawWidth) + 2, height: Int(drawHeight) + 2) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 1, y: 1, width: drawWidth, height: drawHeight))
        return GrayBitmap(context: context)
    }
}

/// 심볼 이름 → 심볼 이미지(CGImage). UIKit(`UIImage(systemName:)`)은 메인 스레드에서만 부를 수 있으므로
/// 이 타입만 메인 스레드에서 돌고, 나머지 전처리·Vision은 `BlockingWork`로 백그라운드에서 돈다.
/// (백그라운드에서 부르면 Xcode Main Thread Checker가 앱을 멈춘다)
@MainActor
public enum SymbolImageSource {
    /// 이 OS에 없는 심볼이면 nil.
    public static func image(named name: String, pointSize: CGFloat) -> CGImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        return UIImage(systemName: name, withConfiguration: configuration)?.cgImage
    }

    /// 여러 심볼을 `batchSize`개씩 나눠 만든다. 묶음 사이에 메인 스레드를 양보해 화면이 멈추지 않게 한다.
    public static func images(named names: [String], pointSize: CGFloat, batchSize: Int = 32) async -> [CGImage?] {
        var result: [CGImage?] = []
        result.reserveCapacity(names.count)
        for (offset, name) in names.enumerated() {
            result.append(image(named: name, pointSize: pointSize))
            if offset % batchSize == batchSize - 1 { await Task.yield() }
        }
        return result
    }
}
