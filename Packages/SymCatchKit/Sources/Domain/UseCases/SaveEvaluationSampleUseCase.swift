//
//  SaveEvaluationSampleUseCase.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

public enum SaveEvaluationSampleError: Error, Sendable, Equatable {
    case sketchTooSmall
}

public protocol SaveEvaluationSampleUseCase: Sendable {
    func execute(symbolName: String, sketch: Sketch, author: String, now: Date) async throws
}

/// 수집 모드에서 그린 평가용 그림을 저장한다. 너무 작거나 빈 그림은 저장하지 않는다.
public struct DefaultSaveEvaluationSampleUseCase: SaveEvaluationSampleUseCase {
    private let repository: any EvaluationSampleRepository
    private let validator: SketchValidator

    public init(repository: any EvaluationSampleRepository, validator: SketchValidator = SketchValidator()) {
        self.repository = repository
        self.validator = validator
    }

    public func execute(symbolName: String, sketch: Sketch, author: String, now: Date) async throws {
        guard validator.validate(sketch) == .valid else {
            throw SaveEvaluationSampleError.sketchTooSmall
        }
        let sample = EvaluationSample(symbolName: symbolName, sketch: sketch, author: author, createdAt: now)
        try await repository.save(sample)
    }
}
