//
//  DrawPreviewSupport.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

#if DEBUG
import Foundation
import Domain

/// 그리기 화면(S1·S2) Preview용 가짜 UseCase. 심볼 준비는 바로 끝나고, 그리면 정해진 결과 10개를 돌려준다.
enum DrawPreviewFixture {
    /// `withSketch`가 true면 하트를 그린 것처럼 바로 검색해 결과 상태로 만든다.
    static func viewModel(withSketch: Bool = true) -> DrawViewModel {
        let viewModel = DrawViewModel(
            prepareIndex: PreviewPrepare(),
            searchSymbols: PreviewSearch(),
            selectSymbol: PreviewSelect(),
            fetchRecent: PreviewProgress(),
            fetchBadges: PreviewProgress(),
            navigator: nil,
            debounce: .zero
        )
        if withSketch { viewModel.sketchDidChange(.exampleHeart) }
        return viewModel
    }
}

private struct PreviewPrepare: PrepareSymbolIndexUseCase {
    func status() async -> SymbolIndexStatus { .ready(symbolCount: 8_092) }
    func execute() -> AsyncThrowingStream<Double, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private struct PreviewSearch: SearchSymbolsUseCase {
    func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome {
        let names: [(String, Int)] = [
            ("heart.fill", 96), ("suit.heart", 91), ("heart.circle", 88), ("bolt.heart", 84), ("heart.text.square", 81),
            ("arrow.up.heart", 79), ("heart.rectangle", 77), ("person.crop.circle.badge.heart", 74), ("cross", 70), ("drop", 66),
        ]
        return .results(names.prefix(limit).map { SymbolMatch(name: $0.0, variants: [], similarity: $0.1) })
    }
}

private struct PreviewSelect: SelectSymbolUseCase {
    func execute(match: SymbolMatch, sketch: Sketch, now: Date) async throws -> SelectionOutcome {
        throw CancellationError()   // Preview에서는 저장하지 않는다.
    }
}

private struct PreviewProgress: FetchRecentRecordsUseCase, FetchBadgesUseCase {
    func execute(limit: Int?) async throws -> [FoundRecord] {
        let line = Sketch(strokes: [[SketchPoint(x: 0.2, y: 0.2), SketchPoint(x: 0.8, y: 0.8)]])
        return [
            FoundRecord(symbolName: "star.fill", sketch: line, similarity: 92, foundAt: .now),
            FoundRecord(symbolName: "cloud", sketch: line, similarity: 87, foundAt: .now),
        ]
    }

    func execute() async throws -> [String: SymbolBadge] {
        ["star.fill": SymbolBadge(symbolName: "star.fill", tier: .silver, bestSimilarity: 92, bestSketch: .empty, earnedAt: .now)]
    }
}
#endif
