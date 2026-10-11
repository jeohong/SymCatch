//
//  SymbolDetailViewModelTests.swift
//  Symbol SketchTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import Symbol_Sketch

private struct StubDetail: GetSymbolDetailUseCase {
    func execute(name: String) async throws -> SymbolDetail {
        let heart = SymbolMeta(name: "heart", family: "heart", categories: ["health"], keywords: ["love"], minOS: "13.0")
        let fill = SymbolMeta(name: "heart.fill", family: "heart", categories: ["health"], keywords: ["love"], minOS: "14.0")
        return SymbolDetail(symbol: heart, variants: [heart, fill], categories: [SymbolCategory(key: "health", label: "Health", icon: "heart")])
    }
}

@MainActor
private final class SpyPasteboard: PasteboardClient {
    var copied: [String] = []
    func copy(_ text: String) { copied.append(text) }
}

@MainActor
private final class SpyHaptics: HapticsClient {
    var lightCount = 0
    func lightImpact() { lightCount += 1 }
    func success() {}
}

@MainActor
struct SymbolDetailViewModelTests {
    private func makeViewModel(similarity: Int? = 92, pasteboard: SpyPasteboard = SpyPasteboard(), haptics: SpyHaptics = SpyHaptics()) -> SymbolDetailViewModel {
        SymbolDetailViewModel(
            request: SymbolDetailRequest(name: "heart", sketch: .exampleHeart, similarity: similarity),
            getDetail: StubDetail(),
            pasteboard: pasteboard,
            haptics: haptics
        )
    }

    @Test func 복사_코드는_선택한_이름을_쓴다() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        #expect(viewModel.code(for: .name) == "heart")
        #expect(viewModel.code(for: .swiftUI) == "Image(systemName: \"heart\")")
        #expect(viewModel.code(for: .uiKit) == "UIImage(systemName: \"heart\")")
    }

    @Test func 복사하면_클립보드에_넣고_햅틱과_토스트() async {
        let pasteboard = SpyPasteboard(), haptics = SpyHaptics()
        let viewModel = makeViewModel(pasteboard: pasteboard, haptics: haptics)
        await viewModel.load()

        viewModel.copy(.swiftUI)

        #expect(pasteboard.copied == ["Image(systemName: \"heart\")"])
        #expect(haptics.lightCount == 1)
        #expect(viewModel.toast?.text == "복사했어요")
        #expect(viewModel.recentlyCopied == .swiftUI)
    }

    @Test func 변형을_고르면_이름과_코드가_바뀐다() async {
        let viewModel = makeViewModel()
        await viewModel.load()

        viewModel.selectVariant("heart.fill")

        #expect(viewModel.selectedName == "heart.fill")
        #expect(viewModel.code(for: .name) == "heart.fill")
        #expect(viewModel.selectedSymbol?.minOS == "14.0")
    }

    @Test func 없는_변형은_무시한다() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.selectVariant("star")
        #expect(viewModel.selectedName == "heart")
    }

    @Test(arguments: [
        (99, "골드 등급 구간이에요"),
        (96, "실버 등급 구간이에요"),
        (90, "브론즈 등급 구간이에요"),
        (85, "뱃지까지 5% 남았어요"),
    ])
    func 유사도_설명은_등급_구간을_따른다(similarity: Int, expected: String) {
        #expect(makeViewModel(similarity: similarity).similarityCaption == expected)
    }

    @Test func 요약은_카테고리와_최소_OS() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        #expect(viewModel.summaryText == "건강 · iOS 13.0 이상")
    }
}
