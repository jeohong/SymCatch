//
//  DrawNavigation.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 심볼 상세(S3)를 열 때 넘기는 값
struct SymbolDetailRequest: Hashable {
    /// 결과에서 고른 대표 이름
    let name: String
    /// 그린 그림(그리기·최근에서 들어올 때). 비교 영역에 쓴다.
    let sketch: Sketch?
    /// 그 그림과의 유사도
    let similarity: Int?
}

enum DrawRoute: Hashable {
    case symbolDetail(SymbolDetailRequest)
}

/// 그리기 화면이 화면 이동 의도를 알리는 통로. ViewModel은 라우터 구현을 모른다.
@MainActor
protocol DrawNavigating: AnyObject {
    func showSymbolDetail(_ request: SymbolDetailRequest)
}
