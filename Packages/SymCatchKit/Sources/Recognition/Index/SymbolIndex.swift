//
//  SymbolIndex.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 모든 심볼의 임베딩을 모은 인덱스(메모리 표현).
/// 엔진이나 OS 버전이 바뀌면 다시 만든다.
public struct SymbolIndex: Sendable, Hashable {
    /// 만든 엔진 식별자(`SymbolSearching.engineID`)
    public let engineID: String
    /// 만들 때의 OS 버전. 바뀌면 심볼 모양이 달라졌을 수 있다.
    public let osVersion: String
    public let names: [String]
    /// 심볼별 윤곽 복잡도(0...1). 너무 단순한 심볼을 뱃지 대상에서 뺄 때 쓴다.
    public let complexity: [Float]
    /// 심볼별 "만능 닮은꼴" 정도: 가장 닮은 다른 심볼 k개의 평균 코사인(`HubnessCorrection`)
    public let hubness: [Float]
    /// 잉크 배치(`InkLayout`) 한 개의 길이(8×8 = 64)
    public let layoutDimension: Int
    /// `names.count × layoutDimension` 행렬(행 우선). 좌우·상하 방향을 구분하는 데 쓴다.
    public let layouts: [Float]
    public let dimension: Int
    /// `names.count × dimension` 행렬(행 우선)
    public let vectors: [Float]

    public init(engineID: String, osVersion: String, names: [String], complexity: [Float], hubness: [Float],
                layoutDimension: Int, layouts: [Float], dimension: Int, vectors: [Float]) {
        precondition(layouts.count == names.count * layoutDimension, "layouts 크기가 names × layoutDimension과 맞지 않는다")
        precondition(complexity.count == names.count, "complexity 개수가 names와 맞지 않는다")
        precondition(hubness.count == names.count, "hubness 개수가 names와 맞지 않는다")
        precondition(vectors.count == names.count * dimension, "vectors 크기가 names × dimension과 맞지 않는다")
        self.engineID = engineID
        self.osVersion = osVersion
        self.names = names
        self.complexity = complexity
        self.hubness = hubness
        self.layoutDimension = layoutDimension
        self.layouts = layouts
        self.dimension = dimension
        self.vectors = vectors
    }

    public var count: Int { names.count }
}
