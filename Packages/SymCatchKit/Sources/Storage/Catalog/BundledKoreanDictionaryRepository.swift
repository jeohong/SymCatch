//
//  BundledKoreanDictionaryRepository.swift
//  Storage
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation
import Domain

/// 앱 번들의 `symbol_keywords_ko.json`(한국어 검색 사전, 계획서 7장 결정 22)을 읽는다. 처음 접근할 때 한 번만 읽는다.
/// 형식: `{ "words": { "heart": ["하트", "심장"] }, "categories": { "nature": ["자연"] } }`
public actor BundledKoreanDictionaryRepository: KoreanDictionaryRepository {
    private let fileURL: URL
    private var cache: KoreanSymbolDictionary?

    private struct File: Decodable {
        let words: [String: [String]]
        let categories: [String: [String]]?
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func dictionary() async throws -> KoreanSymbolDictionary {
        if let cache { return cache }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: fileURL))
        let dictionary = KoreanSymbolDictionary(
            words: Dictionary(file.words.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first }),
            categories: file.categories ?? [:]
        )
        cache = dictionary
        return dictionary
    }
}
