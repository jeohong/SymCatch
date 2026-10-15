//
//  PreprocessingOptions.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import CoreGraphics

/// 그림과 심볼에 똑같이 적용하는 전처리 설정.
/// 흰 바탕 검은 선 → 내용 영역만 잘라 중앙 정렬 → 여백 → 정사각형 `size`로 맞춤.
public struct PreprocessingOptions: Sendable, Hashable {
    /// 출력 이미지 한 변의 픽셀 수(모델 입력 크기)
    public var size: Int
    /// 네 변의 여백 비율(기획서 9.5: 10%)
    public var marginRatio: Double
    /// 그림 선 굵기 = size × lineWidthRatio. 윤곽선으로 바꾼 심볼의 테두리 두께도 같다.
    public var lineWidthRatio: Double

    public init(size: Int = 224, marginRatio: Double = 0.1, lineWidthRatio: Double = 0.03) {
        self.size = size
        self.marginRatio = marginRatio
        self.lineWidthRatio = lineWidthRatio
    }

    public var lineWidth: CGFloat {
        max(1, CGFloat(size) * lineWidthRatio)
    }

    /// 여백을 뺀, 내용이 들어갈 수 있는 한 변의 길이
    public var contentSide: CGFloat {
        CGFloat(size) * (1 - 2 * marginRatio)
    }

    /// 내용 크기(width, height)를 여백 안 정사각형에 비율을 지켜 넣었을 때의 배율과 위치(위가 0).
    func fit(contentWidth: CGFloat, contentHeight: CGFloat, inset: CGFloat = 0) -> (scale: CGFloat, origin: CGPoint) {
        let available = max(1, contentSide - inset)
        let longest = max(contentWidth, contentHeight, .ulpOfOne)
        let scale = available / longest
        let origin = CGPoint(
            x: (CGFloat(size) - contentWidth * scale) / 2,
            y: (CGFloat(size) - contentHeight * scale) / 2
        )
        return (scale, origin)
    }
}
