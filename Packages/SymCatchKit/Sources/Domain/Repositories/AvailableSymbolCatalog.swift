//
//  AvailableSymbolCatalog.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 기기 OS에 있는 심볼만 보이게 하는 카탈로그.
/// 번들 목록(symbols.json)은 최신 SF Symbols 기준이라, 예전 OS 기기에는 아직 없는 심볼이 섞여 있다.
/// 검색·콜렉션 분모·상세의 변형 목록이 모두 이 목록을 쓰게 해서 기기마다 같은 기준을 지킨다.
public struct AvailableSymbolCatalog: SymbolCatalogRepository {
    private let base: any SymbolCatalogRepository
    private let os: OSVersion

    public init(base: any SymbolCatalogRepository, os: OSVersion) {
        self.base = base
        self.os = os
    }

    public func allSymbols() async throws -> [SymbolMeta] {
        try await base.allSymbols().filter { $0.isAvailable(on: os) }
    }

    public func categories() async throws -> [SymbolCategory] {
        try await base.categories()
    }

    public func symbol(named name: String) async throws -> SymbolMeta? {
        try await base.symbol(named: name).flatMap { $0.isAvailable(on: os) ? $0 : nil }
    }

    public func symbols(inFamily family: String) async throws -> [SymbolMeta] {
        try await base.symbols(inFamily: family).filter { $0.isAvailable(on: os) }
    }
}
