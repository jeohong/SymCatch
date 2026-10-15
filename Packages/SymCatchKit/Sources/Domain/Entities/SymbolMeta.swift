//
//  SymbolMeta.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 앱에 포함된 심볼 목록(symbols.json)의 한 항목. 읽기 전용.
public struct SymbolMeta: Sendable, Hashable, Codable, Identifiable {
    /// 심볼 이름. 예: `heart.fill`
    public let name: String
    /// 채움·테두리 변형을 묶는 키. 예: `heart.fill` → `heart`
    public let family: String
    /// 카테고리 키 목록. 예: `["health", "shapes"]`
    public let categories: [String]
    /// 검색 키워드
    public let keywords: [String]
    /// 최소 지원 iOS 버전. 예: `"13.0"`
    public let minOS: String

    public var id: String { name }

    public init(name: String, family: String, categories: [String], keywords: [String], minOS: String) {
        self.name = name
        self.family = family
        self.categories = categories
        self.keywords = keywords
        self.minOS = minOS
    }
}

/// 심볼 카테고리. 예: key `weather`, label `Weather`, icon `cloud.sun`
public struct SymbolCategory: Sendable, Hashable, Codable, Identifiable {
    public let key: String
    public let label: String
    public let icon: String

    public var id: String { key }

    public init(key: String, label: String, icon: String) {
        self.key = key
        self.label = label
        self.icon = icon
    }
}
