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

    /// 유사도 % 보정값(기획서 9.5).
    /// - B 윤곽선(앱이 쓰는 방식): 실기기 평가셋 102장으로 정한 값(계획서 7장 결정 14, 2026-10-12).
    ///   닮은꼴 보정 점수 기준이므로 `scoreWeights`와 짝을 이룬다. 둘 중 하나를 바꾸면 평가 실행으로 다시 정한다.
    /// - A·B 채움: 비교용으로만 남긴 방식이라 임시 값.
    public var calibrator: ScoreCalibrator {
        switch self {
        case .chamfer:
            // 점수 = −평균 거리 ÷ 한 변. 평균 거리가 한 변의 15%면 0%, 2%면 100%.
            ScoreCalibrator(sLow: -0.15, sHigh: -0.02)
        case .visionFilled:
            ScoreCalibrator(sLow: 0.5, sHigh: 0.95)
        case .visionOutline:
            ScoreCalibrator(sLow: 0.3146, sHigh: 0.6805)
        }
    }

    /// 점수 보정 세기(`ScoreAdjustment`): 만능 닮은꼴 보정, 방향 보정. 0이면 하지 않는다.
    /// 방향 보정 세기는 평가 실행으로 정하기 전이라 아직 0이다.
    public var scoreWeights: ScoreWeights {
        switch self {
        case .chamfer, .visionFilled: .none
        case .visionOutline: ScoreWeights(hubness: 0.25, layout: 0)
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
