//
//  SymbolIndexBuilding.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

public enum SymbolIndexStatus: Sendable, Hashable {
    /// 아직 만든 적 없음
    case missing
    /// 엔진이나 OS가 바뀌어 다시 만들어야 함
    case outdated
    /// 파일이 손상됨 → "다시 준비하기"
    case corrupted
    case ready(symbolCount: Int)
}

/// 기기에서 심볼 인덱스를 만든다(첫 실행, OS·엔진 변경 시).
public protocol SymbolIndexBuilding: Sendable {
    func status() async -> SymbolIndexStatus
    /// 인덱스를 만들며 진행률(0...1)을 내보낸다. 끝나면 스트림이 종료된다.
    func build() -> AsyncThrowingStream<Double, Error>
}
