//
//  CelebrationViewModelTests.swift
//  SymCatchTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import SymCatch

@MainActor
private final class SpyHaptics: HapticsClient {
    var successCount = 0
    func lightImpact() {}
    func success() { successCount += 1 }
}

@MainActor
struct CelebrationViewModelTests {
    private let sketch = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])
    private let date = Date(timeIntervalSince1970: 1_791_720_000)

    private func outcome(_ award: BadgeAward, achievements: [AchievementID] = []) -> SelectionOutcome {
        SelectionOutcome(
            record: FoundRecord(symbolName: "heart", sketch: sketch, similarity: 96, foundAt: date),
            badgeAward: award,
            newAchievements: achievements.map { Achievement(id: $0, progress: $0.fixedGoal ?? 1, unlockedAt: date) }
        )
    }

    private func badge(_ tier: BadgeTier, upgradedAt: Date? = nil) -> SymbolBadge {
        SymbolBadge(symbolName: "heart", tier: tier, bestSimilarity: 96, bestSketch: sketch, earnedAt: date, upgradedAt: upgradedAt)
    }

    @Test func 축하할_것이_없으면_만들지_않는다() {
        #expect(Celebration(outcome: outcome(.none), sketch: sketch) == nil)
        #expect(Celebration(outcome: outcome(.silentUpdate(badge(.bronze))), sketch: sketch) == nil)
    }

    @Test func 뱃지_카드가_먼저_업적_카드가_뒤() throws {
        let celebration = try #require(Celebration(outcome: outcome(.newBadge(badge(.silver)), achievements: [.firstStroke, .sharpshooter]), sketch: sketch))
        #expect(celebration.cards == [
            .badge(symbolName: "heart", tier: .silver, isUpgrade: false, similarity: 96, sketch: sketch, date: date),
            .achievement(.firstStroke, unlockedAt: date),
            .achievement(.sharpshooter, unlockedAt: date),
        ])
    }

    @Test func 승급_카드는_승급_날짜를_쓴다() throws {
        let later = date.addingTimeInterval(86_400)
        let celebration = try #require(Celebration(outcome: outcome(.upgraded(from: .bronze, to: badge(.gold, upgradedAt: later))), sketch: sketch))
        #expect(celebration.cards == [.badge(symbolName: "heart", tier: .gold, isUpgrade: true, similarity: 96, sketch: sketch, date: later)])
    }

    @Test func 다음을_누르며_넘기고_마지막에_닫는다() throws {
        let celebration = try #require(Celebration(outcome: outcome(.newBadge(badge(.bronze)), achievements: [.sharpshooter]), sketch: sketch))
        let haptics = SpyHaptics()
        var finished = false
        let viewModel = CelebrationViewModel(celebration: celebration, haptics: haptics) { finished = true }

        viewModel.appeared()
        #expect(haptics.successCount == 1)
        #expect(!viewModel.isLastPage)

        viewModel.advance()
        #expect(viewModel.index == 1)
        #expect(viewModel.isLastPage)
        #expect(!finished)

        viewModel.advance()
        #expect(finished)
    }
}
