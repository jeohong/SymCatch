//
//  SymbolDetailViewModelTests.swift
//  SymCatchTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import SymCatch

private struct StubDetail: GetSymbolDetailUseCase {
    func execute(name: String) async throws -> SymbolDetail {
        let heart = SymbolMeta(name: "heart", family: "heart", categories: ["health"], keywords: ["love"], minOS: "13.0")
        let fill = SymbolMeta(name: "heart.fill", family: "heart", categories: ["health"], keywords: ["love"], minOS: "14.0")
        return SymbolDetail(symbol: heart, variants: [heart, fill], categories: [SymbolCategory(key: "health", label: "Health", icon: "heart")])
    }
}

private struct StubBadges: FetchBadgesUseCase {
    var badges: [String: SymbolBadge] = [:]
    func execute() async throws -> [String: SymbolBadge] { badges }
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
    private func makeViewModel(
        similarity: Int? = 92,
        badges: [String: SymbolBadge] = [:],
        pasteboard: SpyPasteboard = SpyPasteboard(),
        haptics: SpyHaptics = SpyHaptics()
    ) -> SymbolDetailViewModel {
        SymbolDetailViewModel(
            request: SymbolDetailRequest(name: "heart", sketch: .exampleHeart, similarity: similarity),
            getDetail: StubDetail(),
            fetchBadges: StubBadges(badges: badges),
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
        (95, "골드 등급 구간이에요"),
        (94, "실버 등급 구간이에요"),
        (85, "브론즈 등급 구간이에요"),
        (80, "뱃지까지 5% 남았어요"),
    ])
    func 유사도_설명은_등급_구간을_따른다(similarity: Int, expected: String) {
        #expect(makeViewModel(similarity: similarity).similarityCaption == expected)
    }

    @Test func 요약은_카테고리와_최소_OS() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        #expect(viewModel.summaryText == "건강 · iOS 13.0 이상")
    }

    @Test func 뱃지가_있으면_등급과_최고_유사도를_보여_준다() async {
        let badge = SymbolBadge(symbolName: "heart", tier: .silver, bestSimilarity: 92, bestSketch: .exampleHeart, earnedAt: .now)
        let viewModel = makeViewModel(badges: ["heart": badge])
        await viewModel.load()

        #expect(viewModel.selectedBadge == badge)
        #expect(viewModel.badgeText == "실버 뱃지 보유 · 최고 92%")
    }

    @Test func 뱃지는_보고_있는_변형을_따른다() async {
        let badge = SymbolBadge(symbolName: "heart.fill", tier: .legendary, bestSimilarity: 100, bestSketch: .exampleHeart, earnedAt: .now)
        let viewModel = makeViewModel(badges: ["heart.fill": badge])
        await viewModel.load()
        #expect(viewModel.badgeText == nil)

        viewModel.selectVariant("heart.fill")
        #expect(viewModel.badgeText == "레전더리 뱃지 보유 · 최고 100%")
    }
}
