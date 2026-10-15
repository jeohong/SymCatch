//
//  BundledSymbolCatalogRepositoryTests.swift
//  StorageTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
import Domain
@testable import Storage

struct BundledSymbolCatalogRepositoryTests {
    private func makeCatalogFile() throws -> URL {
        let json = """
        {
          "source": "2024.4",
          "categories": [{ "key": "health", "label": "Health", "icon": "heart" }],
          "symbols": [
            { "name": "heart", "family": "heart", "categories": ["health"], "keywords": ["love"], "minOS": "13.0" },
            { "name": "heart.fill", "family": "heart", "categories": ["health"], "keywords": ["love"], "minOS": "13.0" }
          ]
        }
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("symbols-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        return url
    }

    @Test func symbols_json을_읽는다() async throws {
        let repository = BundledSymbolCatalogRepository(fileURL: try makeCatalogFile())

        #expect(try await repository.allSymbols().map(\.name) == ["heart", "heart.fill"])
        #expect(try await repository.categories().map(\.key) == ["health"])
        #expect(try await repository.symbol(named: "heart.fill")?.family == "heart")
        #expect(try await repository.symbol(named: "star") == nil)
        #expect(try await repository.symbols(inFamily: "heart").map(\.name) == ["heart", "heart.fill"])
        #expect(try await repository.symbols(inFamily: "star").isEmpty)
    }

    @Test func 파일이_없으면_오류() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).json")
        let repository = BundledSymbolCatalogRepository(fileURL: missing)

        await #expect(throws: SymbolCatalogError.self) {
            try await repository.allSymbols()
        }
    }
}
