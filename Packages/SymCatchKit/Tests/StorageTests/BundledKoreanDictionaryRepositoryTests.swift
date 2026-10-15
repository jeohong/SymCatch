//
//  BundledKoreanDictionaryRepositoryTests.swift
//  StorageTests
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation
import Testing
import Domain
@testable import Storage

struct BundledKoreanDictionaryRepositoryTests {
    private func makeFile(_ json: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ko-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        return url
    }

    @Test func 단어와_카테고리를_읽고_키는_소문자로() async throws {
        let url = try makeFile(#"{"words":{"Heart":["하트","심장"]},"categories":{"nature":["자연"]}}"#)
        let dictionary = try await BundledKoreanDictionaryRepository(fileURL: url).dictionary()
        #expect(dictionary.words["heart"] == ["하트", "심장"])
        #expect(dictionary.categories["nature"] == ["자연"])
    }

    @Test func 카테고리가_없어도_읽는다() async throws {
        let url = try makeFile(#"{"words":{"car":["자동차"]}}"#)
        let dictionary = try await BundledKoreanDictionaryRepository(fileURL: url).dictionary()
        #expect(dictionary.categories.isEmpty)
    }

    @Test func 파일이_없으면_오류() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("none-\(UUID().uuidString).json")
        await #expect(throws: (any Error).self) { try await BundledKoreanDictionaryRepository(fileURL: missing).dictionary() }
    }
}
