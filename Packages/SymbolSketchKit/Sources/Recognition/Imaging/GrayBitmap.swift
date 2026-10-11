//
//  GrayBitmap.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import CoreGraphics
import Foundation

/// 8비트 흑백 비트맵. 0 = 검은 잉크, 255 = 흰 바탕. 첫 행이 이미지의 맨 위다.
/// 전처리 결과를 픽셀 단위로 다루고(윤곽선 변환, Chamfer 거리) 테스트하기 위한 타입.
public struct GrayBitmap: Sendable, Hashable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    /// 이 값보다 어두우면 잉크로 본다.
    public static let inkThreshold: UInt8 = 128

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "픽셀 수가 크기와 맞지 않는다")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public static func blank(width: Int, height: Int) -> GrayBitmap {
        GrayBitmap(width: width, height: height, pixels: Array(repeating: 255, count: width * height))
    }

    public subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }

    public func isInk(x: Int, y: Int) -> Bool {
        self[x, y] < Self.inkThreshold
    }

    public var inkPixelCount: Int {
        pixels.reduce(0) { $0 + ($1 < Self.inkThreshold ? 1 : 0) }
    }

    /// 잉크 픽셀을 감싸는 사각형(픽셀 좌표, 위가 0). 잉크가 없으면 nil.
    public var inkBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] < Self.inkThreshold {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return maxX < 0 ? nil : (minX, minY, maxX, maxY)
    }
}

// MARK: - CGImage 변환

extension GrayBitmap {
    /// 그리기 결과를 흑백 비트맵으로 받는 컨텍스트를 만든다. 바탕은 흰색으로 채워져 있다.
    static func makeContext(width: Int, height: Int) -> CGContext? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context
    }

    /// 컨텍스트 메모리를 그대로 복사한다(첫 행 = 맨 위).
    init?(context: CGContext) {
        guard let data = context.data else { return nil }
        let width = context.width, height = context.height, bytesPerRow = context.bytesPerRow
        let buffer = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
        var pixels = [UInt8](repeating: 255, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                pixels[y * width + x] = buffer[y * bytesPerRow + x]
            }
        }
        self.init(width: width, height: height, pixels: pixels)
    }

    /// 아무 CGImage나 흑백으로 다시 그려 비트맵으로 만든다. 투명 부분은 흰색이 된다.
    public init?(image: CGImage) {
        guard let context = Self.makeContext(width: image.width, height: image.height) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        self.init(context: context)
    }

    public func makeCGImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
