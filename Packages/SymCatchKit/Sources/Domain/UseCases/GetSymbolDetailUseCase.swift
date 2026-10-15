//
//  GetSymbolDetailUseCase.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 심볼 상세(S3)에 필요한 정보
public struct SymbolDetail: Sendable, Hashable {
    public let symbol: SymbolMeta
    /// 같은 family의 모든 변형(자기 자신 포함). 기본 모양이 먼저, `fill`이 많을수록 뒤.
    public let variants: [SymbolMeta]
    /// 이 심볼의 카테고리(라벨 포함)
    public let categories: [SymbolCategory]

    public init(symbol: SymbolMeta, variants: [SymbolMeta], categories: [SymbolCategory]) {
        self.symbol = symbol
        self.variants = variants
        self.categories = categories
    }
}

public enum GetSymbolDetailError: Error, Sendable, Equatable {
    case notFound(String)
}

public protocol GetSymbolDetailUseCase: Sendable {
    func execute(name: String) async throws -> SymbolDetail
}

public struct DefaultGetSymbolDetailUseCase: GetSymbolDetailUseCase {
    private let catalog: any SymbolCatalogRepository

    public init(catalog: any SymbolCatalogRepository) {
        self.catalog = catalog
    }

    public func execute(name: String) async throws -> SymbolDetail {
        guard let symbol = try await catalog.symbol(named: name) else {
            throw GetSymbolDetailError.notFound(name)
        }
        let variants = try await catalog.symbols(inFamily: symbol.family).sorted { lhs, rhs in
            let (left, right) = (Self.fillCount(lhs.name), Self.fillCount(rhs.name))
            return left != right ? left < right : lhs.name < rhs.name
        }
        let categoriesByKey = Dictionary(try await catalog.categories().map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        return SymbolDetail(
            symbol: symbol,
            variants: variants.isEmpty ? [symbol] : variants,
            categories: symbol.categories.compactMap { categoriesByKey[$0] }
        )
    }

    private static func fillCount(_ name: String) -> Int {
        name.split(separator: ".").filter { $0 == "fill" }.count
    }
}
