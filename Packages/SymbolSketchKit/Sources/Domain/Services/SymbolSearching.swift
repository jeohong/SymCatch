//
//  SymbolSearching.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 그림과 비슷한 심볼을 찾는다. 인식 방식(A·B·C·D)은 이 프로토콜 뒤에 숨긴다.
public protocol SymbolSearching: Sendable {
    /// 엔진·보정값 식별자. 바뀌면 심볼 인덱스를 다시 만든다.
    var engineID: String { get }

    /// - Returns: 변형을 묶은 뒤 유사도 내림차순 상위 `limit`개.
    func search(sketch: Sketch, limit: Int) async throws -> [SymbolMatch]
}
