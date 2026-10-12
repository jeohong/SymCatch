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

struct FileEvaluationSampleImportTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent("eval-import-\(UUID().uuidString)")

    private func repository(_ folder: String) -> FileEvaluationSampleRepository {
        FileEvaluationSampleRepository(directory: root.appendingPathComponent(folder), exportDirectory: root.appendingPathComponent("export"),
                                       now: { Date(timeIntervalSince1970: 1_791_000_000) })
    }

    @Test func 내보낸_파일을_다른_곳에서_다시_들이면_그대로_돌아온다() async throws {
        let original = repository("original")
        let samples = (0..<3).map {
            EvaluationSample(symbolName: "s\($0)", sketch: Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.2), SketchPoint(x: 0.8, y: 0.9)]]),
                             author: "chikong", createdAt: Date(timeIntervalSince1970: Double($0)))
        }
        for sample in samples { try await original.save(sample) }
        let archive = try await original.exportArchive()

        let reinstalled = repository("reinstalled")
        #expect(try await reinstalled.importArchive(from: archive) == 3)
        #expect(try await reinstalled.all() == samples)

        // 같은 파일을 또 들여도 중복되지 않는다.
        #expect(try await reinstalled.importArchive(from: archive) == 0)
        #expect(try await reinstalled.all().count == 3)
    }

    @Test func 형식이_다른_파일은_오류() async throws {
        let file = root.appendingPathComponent("broken.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("{\"hello\": 1}".utf8).write(to: file)
        await #expect(throws: (any Error).self) { try await repository("x").importArchive(from: file) }
    }
}
