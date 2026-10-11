//
//  SketchEmbedder.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import CoreGraphics

/// 전처리된 흑백 이미지를 벡터(임베딩)로 바꾼다. 방식 B·C·D가 이 프로토콜을 구현한다.
/// CGImage를 다루므로 Domain이 아닌 Recognition 안에 둔다.
public protocol SketchEmbedder: Sendable {
    /// 모델 식별자. 바뀌면 심볼 인덱스를 다시 만든다.
    var modelVersion: String { get }
    /// 모델이 기대하는 입력 한 변의 픽셀 수
    var inputSize: Int { get }

    func embed(_ image: CGImage) throws -> [Float]
}
