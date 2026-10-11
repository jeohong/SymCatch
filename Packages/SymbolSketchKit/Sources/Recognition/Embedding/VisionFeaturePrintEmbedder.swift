//
//  VisionFeaturePrintEmbedder.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import CoreGraphics
import Vision

public enum EmbedderError: Error, Sendable {
    case noResult
    case unsupportedElementType
}

/// 방식 B: iOS에 내장된 Vision 이미지 특징 벡터. 학습·앱 용량 증가 없음.
/// 사진용으로 학습된 모델이라 선 그림 정확도는 M0 평가로 확인한다.
public struct VisionFeaturePrintEmbedder: SketchEmbedder {
    public let inputSize: Int

    public init(inputSize: Int = 224) {
        self.inputSize = inputSize
    }

    public var modelVersion: String {
        "vision-featureprint-r\(VNGenerateImageFeaturePrintRequest.currentRevision)"
    }

    public func embed(_ image: CGImage) throws -> [Float] {
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFit
        #if targetEnvironment(simulator)
        // 시뮬레이터는 GPU·Neural Engine 실행 환경을 만들지 못하므로 CPU로 돌린다.
        try Self.useCPU(for: request)
        #endif
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        guard let observation = request.results?.first else { throw EmbedderError.noResult }

        let data = observation.data
        switch observation.elementType {
        case .float:
            return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        case .double:
            return data.withUnsafeBytes { $0.bindMemory(to: Double.self).map(Float.init) }
        default:
            throw EmbedderError.unsupportedElementType
        }
    }

    private static func useCPU(for request: VNRequest) throws {
        for (stage, devices) in try request.supportedComputeStageDevices {
            if let cpu = devices.first(where: { if case .cpu = $0 { true } else { false } }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
    }
}
