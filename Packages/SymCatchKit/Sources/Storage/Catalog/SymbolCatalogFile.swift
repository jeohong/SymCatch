//
//  SymbolCatalogFile.swift
//  Storage
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// `symbols.json`의 파일 형식. `Tools/extract_symbols.swift`가 만든다.
struct SymbolCatalogFile: Codable, Sendable {
    /// 추출에 쓴 SF Symbols 메타데이터의 최신 릴리스 키. 예: `"2024.4"`
    let source: String
    let categories: [SymbolCategory]
    let symbols: [SymbolMeta]
}
