//
//  FoldRegionReader.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import SwiftUI

/// iPhone Duo 접힘 영역 조회를 이 한 곳에 가둔다(기획서 8장, CLAUDE.md 4장).
/// iOS 27.1 미만이나 접힘이 없는 기기는 항상 nil이라 일반 iPhone 화면은 바뀌지 않는다.
enum FoldRegionReader {
    /// 활성 접힘 영역(`proxy` 좌표). 비활성 접힘은 nil.
    /// 가로·세로 접힘선 구분은 `DrawLayoutResolver`가 한다(가로면 위·아래 나누기, 세로면 가로지르지 않는 기존 배치).
    static func activeFold(in proxy: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        return proxy.reservedRegions(kind: .division)
            .first { $0.isActive }?
            .frame
    }
}
