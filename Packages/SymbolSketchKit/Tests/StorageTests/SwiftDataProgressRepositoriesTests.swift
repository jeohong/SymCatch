//
//  SwiftDataProgressRepositoriesTests.swift
//  StorageTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import SwiftData
import Domain
@testable import Storage

private enum Samples {
    static let sketch = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1), SketchPoint(x: 0.9, y: 0.9)]])
    static let otherSketch = Sketch(strokes: [[SketchPoint(x: 0.2, y: 0.8), SketchPoint(x: 0.8, y: 0.2)]])

    static func date(days: Int = 0, hours: Int = 0) -> Date {
        Date(timeIntervalSince1970: 1_791_720_000 + Double(days) * 86_400 + Double(hours) * 3_600)
    }

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}

struct SwiftDataFoundRecordRepositoryTests {
    private let repository: SwiftDataFoundRecordRepository

    init() throws {
        repository = SwiftDataFoundRecordRepository(modelContainer: try ProgressModelContainerFactory.inMemory())
    }

    @Test func 저장한_기록을_최신순으로_읽는다() async throws {
        let old = FoundRecord(symbolName: "heart", sketch: Samples.sketch, similarity: 80, foundAt: Samples.date())
        let new = FoundRecord(symbolName: "star", sketch: Samples.otherSketch, similarity: 60, foundAt: Samples.date(days: 1))
        try await repository.save(old)
        try await repository.save(new)

        #expect(try await repository.all() == [new, old])
        #expect(try await repository.record(forSymbol: "heart") == old)
        #expect(try await repository.record(forSymbol: "none") == nil)
    }

    @Test func 같은_id로_저장하면_덮어쓴다() async throws {
        var record = FoundRecord(symbolName: "heart", sketch: Samples.sketch, similarity: 80, foundAt: Samples.date())
        try await repository.save(record)
        record.similarity = 95
        record.sketch = Samples.otherSketch
        record.foundAt = Samples.date(days: 2)
        try await repository.save(record)

        #expect(try await repository.all() == [record])
    }

    @Test func 같은_심볼은_한_건만_남는다() async throws {
        try await repository.save(FoundRecord(symbolName: "heart", sketch: Samples.sketch, similarity: 80, foundAt: Samples.date()))
        let replacement = FoundRecord(symbolName: "heart", sketch: Samples.otherSketch, similarity: 50, foundAt: Samples.date(days: 1))
        try await repository.save(replacement)

        #expect(try await repository.all() == [replacement])
    }

    @Test func 골라서_지우거나_모두_지운다() async throws {
        let records = (0..<3).map { FoundRecord(symbolName: "s\($0)", sketch: Samples.sketch, similarity: 10, foundAt: Samples.date(days: $0)) }
        for record in records { try await repository.save(record) }

        try await repository.delete(ids: [records[0].id, records[2].id])
        #expect(try await repository.all() == [records[1]])

        try await repository.deleteAll()
        #expect(try await repository.all().isEmpty)
    }
}

struct SwiftDataBadgeRepositoryTests {
    private let repository: SwiftDataBadgeRepository

    init() throws {
        repository = SwiftDataBadgeRepository(modelContainer: try ProgressModelContainerFactory.inMemory())
    }

    @Test func 심볼당_하나이고_승급하면_덮어쓴다() async throws {
        let bronze = SymbolBadge(symbolName: "heart", tier: .bronze, bestSimilarity: 91, bestSketch: Samples.sketch, earnedAt: Samples.date())
        try await repository.save(bronze)
        var gold = bronze
        gold.tier = .gold
        gold.bestSimilarity = 99
        gold.bestSketch = Samples.otherSketch
        gold.upgradedAt = Samples.date(days: 1)
        try await repository.save(gold)

        #expect(try await repository.all() == [gold])
        #expect(try await repository.badge(forSymbol: "heart") == gold)
    }

    @Test func 모두_지운다() async throws {
        try await repository.save(SymbolBadge(symbolName: "a", tier: .silver, bestSimilarity: 96, bestSketch: Samples.sketch, earnedAt: Samples.date()))
        try await repository.deleteAll()
        #expect(try await repository.all().isEmpty)
    }
}

struct SwiftDataAchievementAndStatsRepositoryTests {
    private let container: ModelContainer

    init() throws {
        container = try ProgressModelContainerFactory.inMemory()
    }

    @Test func 업적은_갱신되고_선언_순서로_읽힌다() async throws {
        let repository = SwiftDataAchievementRepository(modelContainer: container)
        try await repository.save([Achievement(id: .collector10, progress: 3), Achievement(id: .firstStroke, progress: 1, unlockedAt: Samples.date())])
        try await repository.save([Achievement(id: .collector10, progress: 4)])

        let all = try await repository.all()
        #expect(all.map(\.id) == [.firstStroke, .collector10])
        #expect(all.last?.progress == 4)
    }

    @Test func 통계는_한_행으로_저장되고_초기화된다() async throws {
        let repository = SwiftDataUserStatsRepository(modelContainer: container)
        #expect(try await repository.load() == .initial)

        try await repository.save(UserStats(totalSelections: 1, streakDays: 1, lastActiveDay: Samples.date()))
        let stats = UserStats(totalSelections: 2, streakDays: 2, lastActiveDay: Samples.date(days: 1))
        try await repository.save(stats)
        #expect(try await repository.load() == stats)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<UserStatsEntityModel>()) == 1)

        try await repository.reset()
        #expect(try await repository.load() == .initial)
    }
}

struct ProgressPersistenceTests {
    @Test func 앱을_다시_열어도_기록과_뱃지가_남는다() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress-\(UUID().uuidString)")
            .appendingPathComponent("Progress.store")

        do {
            let container = try ProgressModelContainerFactory.live(url: url)
            let useCase = DefaultSelectSymbolUseCase(
                records: SwiftDataFoundRecordRepository(modelContainer: container),
                badges: SwiftDataBadgeRepository(modelContainer: container),
                achievements: SwiftDataAchievementRepository(modelContainer: container),
                stats: SwiftDataUserStatsRepository(modelContainer: container),
                calendar: Samples.utcCalendar
            )
            let match = SymbolMatch(name: "heart", variants: [], similarity: 96)
            let outcome = try await useCase.execute(match: match, sketch: Samples.sketch, now: Samples.date())
            #expect(outcome.hasCelebration)
        }

        let reopened = try ProgressModelContainerFactory.live(url: url)
        let records = try await SwiftDataFoundRecordRepository(modelContainer: reopened).all()
        let badge = try await SwiftDataBadgeRepository(modelContainer: reopened).badge(forSymbol: "heart")
        let achievements = try await SwiftDataAchievementRepository(modelContainer: reopened).all()
        let stats = try await SwiftDataUserStatsRepository(modelContainer: reopened).load()

        #expect(records.map(\.symbolName) == ["heart"])
        #expect(records.first?.sketch == Samples.sketch)
        #expect(badge?.tier == .silver)
        #expect(achievements.filter(\.isUnlocked).map(\.id) == [.firstStroke, .sharpshooter])
        #expect(stats.streakDays == 1)
    }
}
