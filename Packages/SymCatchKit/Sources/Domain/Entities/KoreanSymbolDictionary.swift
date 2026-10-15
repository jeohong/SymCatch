//
//  KoreanSymbolDictionary.swift
//  Domain
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation

/// 한국어 심볼 검색 사전(기획서 6장 S9, 계획서 7장 결정 22).
/// SF Symbols의 이름 단어·키워드는 영어뿐이라, 영어 단어 → 한국어 뜻을 기기 안 파일로 둔다.
public struct KoreanSymbolDictionary: Sendable, Hashable {
    /// 영어 단어(소문자) → 한국어 뜻(자주 쓰는 말 먼저)
    public let words: [String: [String]]
    /// 카테고리 키 → 한국어 이름
    public let categories: [String: [String]]

    public init(words: [String: [String]], categories: [String: [String]] = [:]) {
        self.words = words
        self.categories = categories
    }

    public static let empty = KoreanSymbolDictionary(words: [:])

    /// 한국어 뜻이 검색어와 얼마나 맞는지. 같음 → 시작 → 포함. 안 맞으면 nil.
    public enum Match: Int, Sendable, Comparable {
        case exact, prefix, contains
        public static func < (lhs: Match, rhs: Match) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static func match(_ terms: [String], query: String) -> Match? {
        terms.compactMap { term -> Match? in
            let term = term.lowercased()
            if term == query { return .exact }
            if term.hasPrefix(query) { return .prefix }
            if term.contains(query) { return .contains }
            return nil
        }.min()
    }

    /// 검색어에 맞는 영어 단어와 그 맞음 정도
    func matchingWords(_ query: String) -> [String: Match] {
        words.reduce(into: [:]) { result, entry in
            if let match = Self.match(entry.value, query: query) { result[entry.key] = match }
        }
    }

    /// 검색어에 맞는 카테고리 키
    func matchingCategories(_ query: String) -> Set<String> {
        Set(categories.filter { Self.match($0.value, query: query) != nil }.keys)
    }

    /// 한글(완성형·자모)이 들어 있는지. 들어 있으면 한국어 검색을 쓴다.
    public static func containsHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(scalar.value) || (0x1100...0x11FF).contains(scalar.value) || (0x3130...0x318F).contains(scalar.value)
        }
    }
}
