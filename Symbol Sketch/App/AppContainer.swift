//
//  AppContainer.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain
import Storage

/// 객체 조립(DI)을 하는 유일한 곳. 저장소·인식 엔진·UseCase를 만들고 ViewModel에 넘긴다.
/// Presentation 코드는 이 타입을 직접 참조하지 않고, 생성자로 UseCase만 받는다.
final class AppContainer {
    let symbolCatalog: any SymbolCatalogRepository

    init(symbolCatalog: any SymbolCatalogRepository) {
        self.symbolCatalog = symbolCatalog
    }

    static func live() -> AppContainer {
        guard let catalogURL = Bundle.main.url(forResource: "symbols", withExtension: "json") else {
            fatalError("symbols.json이 앱 번들에 없습니다. Tools/extract_symbols.swift를 실행하세요.")
        }
        return AppContainer(symbolCatalog: BundledSymbolCatalogRepository(fileURL: catalogURL))
    }
}
