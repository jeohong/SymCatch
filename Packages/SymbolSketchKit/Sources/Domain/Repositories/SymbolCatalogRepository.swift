//
//  SymbolCatalogRepository.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 앱에 포함된 심볼 목록(읽기 전용)에 접근한다.
public protocol SymbolCatalogRepository: Sendable {
    func allSymbols() async throws -> [SymbolMeta]
    func categories() async throws -> [SymbolCategory]
    func symbol(named name: String) async throws -> SymbolMeta?
}
