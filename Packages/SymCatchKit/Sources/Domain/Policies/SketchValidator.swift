//
//  SketchValidator.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

public enum SketchValidity: Sendable, Hashable {
    case valid
    /// 아무것도 그리지 않음
    case empty
    /// 너무 작거나 짧음 → "조금 더 크게 그려 주세요", 검색하지 않음
    case tooSmall
}

/// 검색해도 될 만큼 그렸는지 판단한다. 기준값은 정규화 좌표(캔버스 한 변 = 1) 기준.
public struct SketchValidator: Sendable, Hashable {
    /// 그림 전체의 긴 변이 캔버스 한 변의 이 비율보다 작으면 너무 작다.
    public let minimumExtent: Double
    /// 모든 획 길이의 합이 이 값보다 짧으면 너무 적다.
    public let minimumTotalLength: Double

    public init(minimumExtent: Double = 0.15, minimumTotalLength: Double = 0.3) {
        self.minimumExtent = minimumExtent
        self.minimumTotalLength = minimumTotalLength
    }

    public func validate(_ sketch: Sketch) -> SketchValidity {
        guard let bounds = sketch.bounds else { return .empty }
        if bounds.longestSide < minimumExtent || sketch.totalLength < minimumTotalLength {
            return .tooSmall
        }
        return .valid
    }
}
