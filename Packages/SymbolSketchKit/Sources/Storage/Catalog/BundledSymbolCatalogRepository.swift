//
//  BundledSymbolCatalogRepository.swift
//  Storage
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

public enum SymbolCatalogError: Error, Sendable {
    case fileNotFound(URL)
}

/// 앱 번들에 포함된 `symbols.json`을 읽는 저장소. 처음 접근할 때 한 번만 읽는다.
public actor BundledSymbolCatalogRepository: SymbolCatalogRepository {
    private let fileURL: URL
    private var cache: (file: SymbolCatalogFile, byName: [String: SymbolMeta])?

    /// - Parameter fileURL: `symbols.json` 위치. 앱에서는 `Bundle.main`에서 찾아 넘긴다.
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func allSymbols() async throws -> [SymbolMeta] {
        try load().file.symbols
    }

    public func categories() async throws -> [SymbolCategory] {
        try load().file.categories
    }

    public func symbol(named name: String) async throws -> SymbolMeta? {
        try load().byName[name]
    }

    private func load() throws -> (file: SymbolCatalogFile, byName: [String: SymbolMeta]) {
        if let cache { return cache }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SymbolCatalogError.fileNotFound(fileURL)
        }
        let file = try JSONDecoder().decode(SymbolCatalogFile.self, from: Data(contentsOf: fileURL))
        let byName = Dictionary(file.symbols.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let loaded = (file, byName)
        cache = loaded
        return loaded
    }
}
