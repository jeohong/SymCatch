//
//  SymbolIndexStoreTests.swift
//  RecognitionTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Recognition

struct SymbolIndexStoreTests {
    private func temporaryStore() -> SymbolIndexStore {
        SymbolIndexStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("index-\(UUID().uuidString)")
            .appendingPathComponent("symbols.index"))
    }

    private let sample = SymbolIndex(
        engineID: "vision-fp-v1",
        osVersion: "27.1",
        names: ["heart", "star.fill", "한글.이름"],
        complexity: [0.4, 0.7, 0.1],
        hubness: [0.81, 0.5, 0.33],
        layoutDimension: 2,
        layouts: [0.5, -0.5, 0.25, 0.75, -1, 0],
        dimension: 2,
        vectors: [0.5, -0.25, 1, 0, 0.125, 0.75]
    )

    @Test func 저장한_인덱스를_그대로_읽는다() throws {
        let store = temporaryStore()
        try store.save(sample)
        // float16으로 정확히 표현되는 값만 써서 그대로 돌아와야 한다.
        #expect(try store.load() == sample)
    }

    @Test func 파일이_없으면_notFound() {
        #expect(throws: SymbolIndexStoreError.notFound) { try temporaryStore().load() }
    }

    @Test func 잘린_파일은_corrupted() throws {
        let store = temporaryStore()
        try store.save(sample)
        let data = try Data(contentsOf: store.fileURL)
        try data.prefix(data.count - 3).write(to: store.fileURL)

        #expect(throws: SymbolIndexStoreError.corrupted) { try store.load() }
    }

    @Test func 다른_형식의_파일은_corrupted() throws {
        let store = temporaryStore()
        try store.save(sample)
        try Data("not an index file".utf8).write(to: store.fileURL)

        #expect(throws: SymbolIndexStoreError.corrupted) { try store.load() }
    }

    @Test func 삭제하면_다시_notFound() throws {
        let store = temporaryStore()
        try store.save(sample)
        try store.delete()
        #expect(throws: SymbolIndexStoreError.notFound) { try store.load() }
    }
}
