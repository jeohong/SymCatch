//
//  GetSymbolDetailUseCaseTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Testing
@testable import Domain

private struct FakeCatalog: SymbolCatalogRepository {
    let symbols: [SymbolMeta]
    let categoryList: [SymbolCategory]

    func allSymbols() async throws -> [SymbolMeta] { symbols }
    func categories() async throws -> [SymbolCategory] { categoryList }
    func symbol(named name: String) async throws -> SymbolMeta? { symbols.first { $0.name == name } }
    func symbols(inFamily family: String) async throws -> [SymbolMeta] { symbols.filter { $0.family == family } }
}

struct GetSymbolDetailUseCaseTests {
    private func meta(_ name: String, categories: [String] = []) -> SymbolMeta {
        SymbolMeta(name: name, family: VariantGrouper.family(of: name), categories: categories, keywords: [], minOS: "13.0")
    }

    private var catalog: FakeCatalog {
        FakeCatalog(
            symbols: [meta("heart.fill", categories: ["health"]), meta("heart", categories: ["health"]), meta("star")],
            categoryList: [SymbolCategory(key: "health", label: "Health", icon: "heart")]
        )
    }

    @Test func 변형은_기본_모양이_먼저() async throws {
        let detail = try await DefaultGetSymbolDetailUseCase(catalog: catalog).execute(name: "heart.fill")
        #expect(detail.symbol.name == "heart.fill")
        #expect(detail.variants.map(\.name) == ["heart", "heart.fill"])
    }

    @Test func 카테고리_키를_라벨로_바꾼다() async throws {
        let detail = try await DefaultGetSymbolDetailUseCase(catalog: catalog).execute(name: "heart")
        #expect(detail.categories.map(\.label) == ["Health"])
    }

    @Test func 없는_심볼은_notFound() async {
        await #expect(throws: GetSymbolDetailError.notFound("nope")) {
            try await DefaultGetSymbolDetailUseCase(catalog: catalog).execute(name: "nope")
        }
    }
}
