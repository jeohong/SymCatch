//
//  EvaluationSampleUseCases.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 수집 진행 상황
public struct EvaluationProgress: Sendable, Hashable {
    /// 이 사람이 심볼별로 그린 수
    public let countsByTarget: [String: Int]
    /// 이 사람이 그린 전체 수
    public let authorTotal: Int
    /// 모든 사람의 전체 수
    public let overallTotal: Int
    /// 이 사람의 목표 수(대표 심볼 수 × 심볼당 그림 수)
    public let authorGoal: Int

    public init(countsByTarget: [String: Int], authorTotal: Int, overallTotal: Int, authorGoal: Int) {
        self.countsByTarget = countsByTarget
        self.authorTotal = authorTotal
        self.overallTotal = overallTotal
        self.authorGoal = authorGoal
    }

    public static let empty = EvaluationProgress(countsByTarget: [:], authorTotal: 0, overallTotal: 0, authorGoal: 0)
}

public protocol LoadEvaluationProgressUseCase: Sendable {
    func execute(author: String) async throws -> EvaluationProgress
}

public struct DefaultLoadEvaluationProgressUseCase: LoadEvaluationProgressUseCase {
    private let repository: any EvaluationSampleRepository
    private let targets: [String]

    public init(repository: any EvaluationSampleRepository, targets: [String] = EvaluationTargetPicker.representativeSymbols) {
        self.repository = repository
        self.targets = targets
    }

    public func execute(author: String) async throws -> EvaluationProgress {
        let samples = try await repository.all()
        let mine = samples.filter { $0.author == author }
        let counts = Dictionary(grouping: mine, by: \.symbolName).mapValues(\.count)
        return EvaluationProgress(
            countsByTarget: counts,
            authorTotal: mine.count,
            overallTotal: samples.count,
            authorGoal: targets.count * EvaluationTargetPicker.samplesPerTarget
        )
    }
}

public protocol ExportEvaluationSamplesUseCase: Sendable {
    /// 평가셋 전체를 파일 하나로 내보내고 그 위치를 돌려준다(공유 시트로 Mac에 옮기기 위함).
    func execute() async throws -> URL
}

public struct DefaultExportEvaluationSamplesUseCase: ExportEvaluationSamplesUseCase {
    private let repository: any EvaluationSampleRepository

    public init(repository: any EvaluationSampleRepository) {
        self.repository = repository
    }

    public func execute() async throws -> URL {
        try await repository.exportArchive()
    }
}
