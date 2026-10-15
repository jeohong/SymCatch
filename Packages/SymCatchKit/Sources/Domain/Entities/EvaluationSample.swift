//
//  EvaluationSample.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 인식 정확도를 재기 위한 평가용 손그림 한 장(개발용 수집 모드에서 만든다).
/// 평가셋은 학습·보정에 섞지 않는다.
public struct EvaluationSample: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    /// 정답 심볼 이름
    public let symbolName: String
    public let sketch: Sketch
    /// 그린 사람 구분용 이름(여러 사람의 그림을 나눠 보기 위함)
    public let author: String
    public let createdAt: Date

    public init(id: UUID = UUID(), symbolName: String, sketch: Sketch, author: String, createdAt: Date) {
        self.id = id
        self.symbolName = symbolName
        self.sketch = sketch
        self.author = author
        self.createdAt = createdAt
    }
}
