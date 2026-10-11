//
//  ChamferIndexPreparer.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 방식 A의 준비(모든 심볼 윤곽선·거리 지도 만들기)를 `SymbolIndexBuilding`으로 감싼다.
/// 방식 B와 같은 "준비하기" 흐름(PrepareSymbolIndexUseCase)으로 다루기 위함. 파일로 저장하지 않고 메모리에만 둔다.
public struct ChamferIndexPreparer: SymbolIndexBuilding {
    private let search: ChamferSymbolSearch

    public init(search: ChamferSymbolSearch) {
        self.search = search
    }

    public func status() async -> SymbolIndexStatus {
        await search.isPrepared ? .ready(symbolCount: 0) : .missing
    }

    public func build() -> AsyncThrowingStream<Double, Error> {
        let (stream, continuation) = AsyncThrowingStream<Double, Error>.makeStream()
        let task = Task { [search] in
            do {
                try await search.prepare { continuation.yield($0) }
                continuation.yield(1)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }
}
