//
//  PercentText.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation

extension Int {
    /// 정수 퍼센트 표시("92%"). 언어마다 형식이 달라(프랑스어 "92 %", 터키어 "%92") 문구에 `%`를 직접 쓰지 않고 이 값을 넣는다.
    nonisolated var percentText: String { formatted(.percent) }
}
