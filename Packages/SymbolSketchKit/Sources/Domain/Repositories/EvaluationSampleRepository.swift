//
//  EvaluationSampleRepository.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 평가용 손그림을 저장·조회한다(개발용 수집 모드).
public protocol EvaluationSampleRepository: Sendable {
    func save(_ sample: EvaluationSample) async throws
    func all() async throws -> [EvaluationSample]
    func delete(id: UUID) async throws
    /// 평가셋 전체를 한 폴더로 내보내고 그 위치를 돌려준다(공유 시트로 넘기기 위함).
    func exportArchive() async throws -> URL
}
