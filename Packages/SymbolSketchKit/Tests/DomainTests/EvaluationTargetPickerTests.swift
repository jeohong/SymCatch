//
//  EvaluationTargetPickerTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Domain

struct EvaluationTargetPickerTests {
    @Test func 대표_심볼은_중복_없는_100개() {
        let symbols = EvaluationTargetPicker.representativeSymbols
        #expect(symbols.count == 100)
        #expect(Set(symbols).count == 100)
    }

    @Test func 그린_수가_가장_적은_심볼을_목록_순서대로_고른다() {
        let targets = ["a", "b", "c"]
        #expect(EvaluationTargetPicker.next(from: targets, counts: [:]) == "a")
        #expect(EvaluationTargetPicker.next(from: targets, counts: ["a": 1]) == "b")
        #expect(EvaluationTargetPicker.next(from: targets, counts: ["a": 1, "b": 1, "c": 2]) == "a")
    }

    @Test func 건너뛴_심볼은_이번에는_고르지_않는다() {
        #expect(EvaluationTargetPicker.next(from: ["a", "b"], counts: [:], excluding: ["a"]) == "b")
    }

    @Test func 남은_것이_건너뛴_심볼뿐이면_그것을_고른다() {
        #expect(EvaluationTargetPicker.next(from: ["a", "b"], counts: ["b": 3], excluding: ["a"], goal: 3) == "a")
    }

    @Test func 모두_목표에_닿으면_nil() {
        #expect(EvaluationTargetPicker.next(from: ["a", "b"], counts: ["a": 3, "b": 3], goal: 3) == nil)
    }
}

private actor InMemoryEvaluationRepository: EvaluationSampleRepository {
    var samples: [EvaluationSample]
    init(samples: [EvaluationSample]) { self.samples = samples }
    func save(_ sample: EvaluationSample) async throws { samples.append(sample) }
    func all() async throws -> [EvaluationSample] { samples }
    func delete(id: UUID) async throws { samples.removeAll { $0.id == id } }
    func exportArchive() async throws -> URL { URL(fileURLWithPath: "/tmp/export.json") }
}

struct LoadEvaluationProgressUseCaseTests {
    private func sample(_ name: String, by author: String) -> EvaluationSample {
        EvaluationSample(symbolName: name, sketch: .empty, author: author, createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test func 사람별로_심볼마다_센다() async throws {
        let repository = InMemoryEvaluationRepository(samples: [
            sample("heart", by: "작성자A"), sample("heart", by: "작성자A"), sample("star", by: "작성자A"),
            sample("heart", by: "작성자B"),
        ])
        let progress = try await DefaultLoadEvaluationProgressUseCase(repository: repository, targets: ["heart", "star"])
            .execute(author: "작성자A")

        #expect(progress.countsByTarget == ["heart": 2, "star": 1])
        #expect(progress.authorTotal == 3)
        #expect(progress.overallTotal == 4)
        #expect(progress.authorGoal == 2 * EvaluationTargetPicker.samplesPerTarget)
    }
}
