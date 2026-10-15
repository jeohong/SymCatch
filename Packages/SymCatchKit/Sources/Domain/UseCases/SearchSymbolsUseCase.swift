//
//  SearchSymbolsUseCase.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

public enum SearchOutcome: Sendable, Hashable {
    case empty
    case tooSmall
    case results([SymbolMatch])
}

public protocol SearchSymbolsUseCase: Sendable {
    func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome
}

/// 그림이 충분한지 먼저 확인하고, 충분할 때만 검색한다.
public struct DefaultSearchSymbolsUseCase: SearchSymbolsUseCase {
    private let searcher: any SymbolSearching
    private let validator: SketchValidator

    public init(searcher: any SymbolSearching, validator: SketchValidator = SketchValidator()) {
        self.searcher = searcher
        self.validator = validator
    }

    public func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome {
        switch validator.validate(sketch) {
        case .empty:
            return .empty
        case .tooSmall:
            return .tooSmall
        case .valid:
            return .results(try await searcher.search(sketch: sketch, limit: limit))
        }
    }
}
