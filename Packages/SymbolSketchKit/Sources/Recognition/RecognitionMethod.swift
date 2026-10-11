//
//  RecognitionMethod.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Domain

/// M0에서 비교하는 인식 방식(기획서 9.2). 채택한 방식은 App의 AppContainer에서 고른다.
public enum RecognitionMethod: String, Sendable, CaseIterable {
    /// A. 윤곽 비교(Chamfer 거리), 모델 없음
    case chamfer
    /// B. Vision 특징 벡터, 심볼을 채운 모양 그대로 비교
    case visionFilled
    /// B. Vision 특징 벡터, 심볼을 윤곽선으로 바꿔 비교
    case visionOutline

    /// 평가셋으로 정하기 전의 임시 보정값. M0 평가 리포트가 나오면 실제 값으로 바꾼다.
    public var provisionalCalibrator: ScoreCalibrator {
        switch self {
        case .chamfer:
            // 점수 = −평균 거리 ÷ 한 변. 평균 거리가 한 변의 15%면 0%, 2%면 100%.
            ScoreCalibrator(sLow: -0.15, sHigh: -0.02)
        case .visionFilled, .visionOutline:
            ScoreCalibrator(sLow: 0.5, sHigh: 0.95)
        }
    }

    var symbolStyle: SymbolRenderer.Style? {
        switch self {
        case .chamfer: nil
        case .visionFilled: .filled
        case .visionOutline: .outline
        }
    }

    public var embeddingPipeline: EmbeddingPipeline? {
        symbolStyle.map { EmbeddingPipeline(embedder: VisionFeaturePrintEmbedder(), symbolStyle: $0) }
    }
}
