//
//  SearchSymbolsUseCaseTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Domain

private final class SpySymbolSearching: SymbolSearching, @unchecked Sendable {
    let engineID = "spy"
    private(set) var callCount = 0
    var stubbed: [SymbolMatch] = []

    func search(sketch: Sketch, limit: Int) async throws -> [SymbolMatch] {
        callCount += 1
        return Array(stubbed.prefix(limit))
    }
}

struct SearchSymbolsUseCaseTests {
    private let bigSketch = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])

    @Test func 그림이_부족하면_검색하지_않는다() async throws {
        let spy = SpySymbolSearching()
        let useCase = DefaultSearchSymbolsUseCase(searcher: spy)
        let tiny = Sketch(strokes: [[SketchPoint(x: 0.5, y: 0.5), SketchPoint(x: 0.52, y: 0.5)]])

        #expect(try await useCase.execute(sketch: tiny, limit: 10) == .tooSmall)
        #expect(try await useCase.execute(sketch: .empty, limit: 10) == .empty)
        #expect(spy.callCount == 0)
    }

    @Test func 그림이_충분하면_검색_결과를_돌려준다() async throws {
        let spy = SpySymbolSearching()
        spy.stubbed = [SymbolMatch(name: "heart", variants: ["heart.fill"], similarity: 92)]
        let useCase = DefaultSearchSymbolsUseCase(searcher: spy)

        #expect(try await useCase.execute(sketch: bigSketch, limit: 10) == .results(spy.stubbed))
        #expect(spy.callCount == 1)
    }
}
