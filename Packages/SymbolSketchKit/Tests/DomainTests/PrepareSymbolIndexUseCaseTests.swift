//
//  PrepareSymbolIndexUseCaseTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/14/26.
//

import Foundation
import Testing
@testable import Domain

/// 만든 횟수를 세는 가짜 인덱스 빌더
private final class CountingBuilder: SymbolIndexBuilding, @unchecked Sendable {
    private let lock = NSLock()
    private var ready: Bool
    private var count = 0

    init(ready: Bool) { self.ready = ready }

    var buildCount: Int { lock.withLock { count } }

    func status() async -> SymbolIndexStatus {
        lock.withLock { ready } ? .ready(symbolCount: 3) : .missing
    }

    func build() -> AsyncThrowingStream<Double, Error> {
        lock.withLock { count += 1; ready = true }
        return AsyncThrowingStream { continuation in
            continuation.yield(0.5)
            continuation.yield(1)
            continuation.finish()
        }
    }
}

struct PrepareSymbolIndexUseCaseTests {
    @Test func 준비돼_있으면_만들지_않는다() async throws {
        let builder = CountingBuilder(ready: true)
        for try await _ in DefaultPrepareSymbolIndexUseCase(builder: builder).execute() {}
        #expect(builder.buildCount == 0)
    }

    @Test func 없으면_만든다() async throws {
        let builder = CountingBuilder(ready: false)
        var progress: [Double] = []
        for try await value in DefaultPrepareSymbolIndexUseCase(builder: builder).execute() { progress.append(value) }
        #expect(builder.buildCount == 1)
        #expect(progress.last == 1)
    }

    @Test func 다시_준비하기는_준비돼_있어도_새로_만든다() async throws {
        let builder = CountingBuilder(ready: true)
        for try await _ in DefaultPrepareSymbolIndexUseCase(builder: builder).rebuild() {}
        #expect(builder.buildCount == 1)
    }
}

struct ResetProgressUseCaseTests {
    @Test func 기록_뱃지_업적_통계를_모두_지운다() async throws {
        let records = InMemoryFoundRecords(), badges = InMemoryBadges(), achievements = InMemoryAchievements(), stats = InMemoryStats()
        let select = DefaultSelectSymbolUseCase(records: records, badges: badges, achievements: achievements, stats: stats, calendar: Fixtures.utcCalendar)
        _ = try await select.execute(match: SymbolMatch(name: "heart", variants: [], similarity: 92), sketch: Fixtures.sketch, now: Fixtures.date())
        #expect(try await badges.all().count == 1)

        try await DefaultResetProgressUseCase(records: records, badges: badges, achievements: achievements, stats: stats).execute()

        #expect(try await records.all().isEmpty)
        #expect(try await badges.all().isEmpty)
        #expect(try await achievements.all().isEmpty)
        #expect(try await stats.load() == .initial)
    }
}
