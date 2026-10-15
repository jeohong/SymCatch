//
//  CollectionViewModelTests.swift
//  SymCatchTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import SymCatch

private struct StubCollection: FetchCollectionUseCase {
    var summary: CollectionSummary
    func execute() async throws -> CollectionSummary { summary }
}

private struct StubBadges: FetchBadgesUseCase {
    var badges: [String: SymbolBadge] = [:]
    func execute() async throws -> [String: SymbolBadge] { badges }
}

@MainActor
private final class SpyCollectionNavigator: CollectionNavigating {
    var badgeDetails: [String] = []
    var symbolDetails: [SymbolDetailRequest] = []
    var challenges: [String] = []
    var wentToDraw = 0
    var openedSettings = 0
    var openedAchievements = 0
    func showSettings() { openedSettings += 1 }
    func showAchievements() { openedAchievements += 1 }
    func showBadgeDetail(symbolName: String) { badgeDetails.append(symbolName) }
    func showCollectionSymbolDetail(_ request: SymbolDetailRequest) { symbolDetails.append(request) }
    func startChallenge(symbolName: String) { challenges.append(symbolName) }
    func showDrawTab() { wentToDraw += 1 }
}

private let sketch = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])
private let date = Date(timeIntervalSince1970: 1_791_720_000)

private func badge(_ name: String, _ tier: BadgeTier, upgradedAt: Date? = nil) -> SymbolBadge {
    SymbolBadge(symbolName: name, tier: tier, bestSimilarity: 96, bestSketch: sketch, earnedAt: date, upgradedAt: upgradedAt)
}

@MainActor
struct CollectionViewModelTests {
    private func summary(badges: [SymbolBadge], total: Int = 1_000) -> CollectionSummary {
        CollectionSummary(
            badges: badges,
            achievements: [Achievement(id: .firstStroke, progress: 1, unlockedAt: date), Achievement(id: .collector10, progress: 9)],
            totalSymbolCount: total,
            categories: [CategorySymbols(category: SymbolCategory(key: "health", label: "Health", icon: "heart"), names: ["heart", "pills", "cross"])]
        )
    }

    @Test func 진행률은_획득_수_나누기_전체이고_최소_0점8퍼센트() async {
        let viewModel = CollectionViewModel(fetchCollection: StubCollection(summary: summary(badges: [badge("heart", .gold)])), navigator: nil)
        await viewModel.load()
        #expect(viewModel.progress == 0.008)

        let empty = CollectionViewModel(fetchCollection: StubCollection(summary: summary(badges: [])), navigator: nil)
        await empty.load()
        #expect(empty.progress == 0)

        let half = CollectionViewModel(fetchCollection: StubCollection(summary: summary(badges: [badge("heart", .gold)], total: 2)), navigator: nil)
        await half.load()
        #expect(half.progress == 0.5)
    }

    @Test func 카테고리별_획득_수와_메달_상태() async throws {
        let viewModel = CollectionViewModel(fetchCollection: StubCollection(summary: summary(badges: [badge("heart", .silver)])), navigator: nil)
        await viewModel.load()
        let category = try #require(viewModel.summary?.categories.first)

        #expect(viewModel.earnedCount(in: category) == 1)
        #expect(viewModel.badge(for: "heart")?.tier == .silver)
        #expect(viewModel.badge(for: "pills") == nil)
    }

    @Test func 업적_상태_문구() async {
        let viewModel = CollectionViewModel(fetchCollection: StubCollection(summary: summary(badges: [])), navigator: nil)
        #expect(viewModel.statusText(for: Achievement(id: .collector10, progress: 9)) == "9 / 10")
        #expect(viewModel.statusText(for: Achievement(id: .firstStroke, progress: 1, unlockedAt: date)).hasSuffix("달성"))
    }

    @Test func 메달을_탭하면_뱃지_상세로() {
        let navigator = SpyCollectionNavigator()
        let viewModel = CollectionViewModel(fetchCollection: StubCollection(summary: summary(badges: [])), navigator: navigator)
        viewModel.select(symbolName: "pills")
        viewModel.goDraw()
        viewModel.openSettings()
        #expect(navigator.badgeDetails == ["pills"])
        #expect(navigator.wentToDraw == 1)
        #expect(navigator.openedSettings == 1)
    }
}

@MainActor
struct BadgeDetailViewModelTests {
    private func makeViewModel(_ name: String, badge: SymbolBadge? = nil, navigator: SpyCollectionNavigator? = nil) -> BadgeDetailViewModel {
        BadgeDetailViewModel(symbolName: name, fetchBadges: StubBadges(badges: badge.map { [$0.symbolName: $0] } ?? [:]), navigator: navigator)
    }

    @Test(arguments: [
        (nil, "유사도 85% 이상이면 브론즈 뱃지를 얻어요", true),
        (BadgeTier.bronze, "90% 이상이면 실버로 승급해요", true),
        (.silver, "95% 이상이면 골드로 승급해요", true),
        (.gold, "100%를 달성하면 레전더리로 승급해요", true),
        (.legendary, "최고 등급을 달성했어요", false),
    ] as [(BadgeTier?, String, Bool)])
    func 등급별_안내와_도전_가능_여부(tier: BadgeTier?, goal: String, canChallenge: Bool) async {
        let viewModel = makeViewModel("heart", badge: tier.map { badge("heart", $0) })
        await viewModel.load()
        #expect(viewModel.goalText == goal)
        #expect(viewModel.canChallenge == canChallenge)
    }

    @Test func 보유하면_당시_그림으로_상세를_열고_도전한다() async {
        let navigator = SpyCollectionNavigator()
        let viewModel = makeViewModel("heart", badge: badge("heart", .bronze), navigator: navigator)
        await viewModel.load()

        viewModel.showSymbolDetail()
        viewModel.challenge()

        #expect(navigator.symbolDetails == [SymbolDetailRequest(name: "heart", sketch: sketch, similarity: 96, isPastSketch: true)])
        #expect(navigator.challenges == ["heart"])
        #expect(viewModel.challengeTitle == "더 높은 등급에 도전")
    }

    @Test func 미획득이면_그림_없이_상세를_연다() async {
        let navigator = SpyCollectionNavigator()
        let viewModel = makeViewModel("pills", navigator: navigator)
        await viewModel.load()

        viewModel.showSymbolDetail()

        #expect(navigator.symbolDetails == [SymbolDetailRequest(name: "pills", sketch: nil, similarity: nil)])
        #expect(viewModel.challengeTitle == "그려서 도전하기")
    }

    // MARK: - 업적(기획서 3.2)

    private func achievementSummary() -> CollectionSummary {
        CollectionSummary(
            badges: [badge("leaf.fill", .bronze)],
            achievements: [
                Achievement(id: .firstStroke, progress: 1, unlockedAt: date),
                Achievement(id: .sharpshooter, progress: 1, unlockedAt: date.addingTimeInterval(60)),
                Achievement(id: .collector10, progress: 1),
                Achievement(id: .streak7, progress: 5),
                Achievement(id: .categoryStarter("nature"), progress: 1, goal: 10),
                Achievement(id: .categoryMaster("nature"), progress: 1, goal: 178),
            ],
            totalSymbolCount: 1_000,
            categories: [CategorySymbols(category: SymbolCategory(key: "nature", label: "Nature", icon: "leaf"), names: ["leaf", "tree"])]
        )
    }

    @Test func 업적_줄은_일반_업적만_미달성을_진행률_순으로_먼저() async {
        let viewModel = CollectionViewModel(fetchCollection: StubCollection(summary: achievementSummary()), navigator: nil)
        await viewModel.load()
        // 미달성: 연속 출석(5/7) → 수집가 10(1/10), 그다음 달성(최근 달성순)
        #expect(viewModel.featuredAchievements.map(\.id) == [.streak7, .collector10, .sharpshooter, .firstStroke])
        #expect(viewModel.unlockedAchievementCount == 2)
        #expect(viewModel.achievementCount == 6)
    }

    @Test func 카테고리_업적은_입문과_전설() async {
        let viewModel = CollectionViewModel(fetchCollection: StubCollection(summary: achievementSummary()), navigator: nil)
        await viewModel.load()
        #expect(viewModel.categoryAchievements(for: "nature").map(\.id) == [.categoryStarter("nature"), .categoryMaster("nature")])
        #expect(viewModel.categoryAchievements(for: "uncategorized").isEmpty)
    }

    @Test func 변형_이름으로_받은_뱃지도_대표_칸에_보인다() async {
        let viewModel = CollectionViewModel(fetchCollection: StubCollection(summary: achievementSummary()), navigator: nil)
        await viewModel.load()
        #expect(viewModel.badge(for: "leaf")?.symbolName == "leaf.fill")
        #expect(viewModel.earnedCount(in: achievementSummary().categories[0]) == 1)
    }

    @Test func 전체_보기를_누르면_업적_화면으로() {
        let navigator = SpyCollectionNavigator()
        let viewModel = CollectionViewModel(fetchCollection: StubCollection(summary: achievementSummary()), navigator: navigator)
        viewModel.openAchievements()
        #expect(navigator.openedAchievements == 1)
    }
}
