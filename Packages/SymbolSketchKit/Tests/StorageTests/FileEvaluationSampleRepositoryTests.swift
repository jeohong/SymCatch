//
//  FileEvaluationSampleRepositoryTests.swift
//  StorageTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import Storage

struct FileEvaluationSampleRepositoryTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent("eval-\(UUID().uuidString)")

    private func makeRepository() -> FileEvaluationSampleRepository {
        FileEvaluationSampleRepository(
            directory: root.appendingPathComponent("samples"),
            exportDirectory: root.appendingPathComponent("export"),
            now: { Date(timeIntervalSince1970: 1_791_000_000) }
        )
    }

    private func sample(_ name: String, at seconds: TimeInterval) -> EvaluationSample {
        EvaluationSample(
            symbolName: name,
            sketch: Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.2), SketchPoint(x: 0.8, y: 0.9)]]),
            author: "작성자A",
            createdAt: Date(timeIntervalSince1970: seconds)
        )
    }

    @Test func 저장한_그림을_시간순으로_읽는다() async throws {
        let repository = makeRepository()
        let later = sample("star", at: 200), earlier = sample("heart", at: 100)
        try await repository.save(later)
        try await repository.save(earlier)

        #expect(try await repository.all() == [earlier, later])
    }

    @Test func 폴더가_없으면_빈_목록() async throws {
        #expect(try await makeRepository().all().isEmpty)
    }

    @Test func 삭제하면_목록에서_빠진다() async throws {
        let repository = makeRepository()
        let first = sample("heart", at: 1)
        try await repository.save(first)
        try await repository.save(sample("star", at: 2))
        try await repository.delete(id: first.id)

        #expect(try await repository.all().map(\.symbolName) == ["star"])
    }

    @Test func 내보내기는_모든_그림을_담은_JSON_파일() async throws {
        let repository = makeRepository()
        try await repository.save(sample("heart", at: 1))
        try await repository.save(sample("star", at: 2))

        let url = try await repository.exportArchive()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode([EvaluationSample].self, from: Data(contentsOf: url))

        #expect(url.lastPathComponent.hasPrefix("symbol-sketch-eval-"))
        #expect(exported.map(\.symbolName) == ["heart", "star"])
    }
}
