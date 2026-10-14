//
//  DrawLayoutResolverTests.swift
//  Symbol SketchTests
//
//  Created by Hongjeongmin on 10/14/26.
//

import Foundation
import Testing
import SwiftUI
@testable import Symbol_Sketch

struct DrawLayoutResolverTests {
    /// Duo 반쯤 접힘(디자인 890×626, 접힘 y 301~325)
    private let duoSize = CGSize(width: 890, height: 626)
    private let horizontalFold = CGRect(x: 0, y: 301, width: 890, height: 24)

    @Test func 가로_접힘선이면_위는_결과_아래는_캔버스() {
        let layout = DrawLayoutResolver.resolve(size: duoSize, horizontalSizeClass: .regular, fold: horizontalFold)
        #expect(layout == .duoHalfFolded(top: CGRect(x: 0, y: 0, width: 890, height: 301),
                                        bottom: CGRect(x: 0, y: 325, width: 890, height: 301)))
    }

    @Test(arguments: [UserInterfaceSizeClass.compact, .regular])
    func 세로_접힘선이면_기존_배치(sizeClass: UserInterfaceSizeClass) {
        let verticalFold = CGRect(x: 433, y: 0, width: 24, height: 626)
        let layout = DrawLayoutResolver.resolve(size: duoSize, horizontalSizeClass: sizeClass, fold: verticalFold)
        #expect(layout == (sizeClass == .regular ? .regularLandscape : .compact))
    }

    @Test func 접힘이_없으면_일반_iPhone은_compact() {
        let layout = DrawLayoutResolver.resolve(size: CGSize(width: 393, height: 852), horizontalSizeClass: .compact, fold: nil)
        #expect(layout == .compact)
    }

    @Test func 크기_클래스를_모르면_compact() {
        #expect(DrawLayoutResolver.resolve(size: CGSize(width: 1000, height: 700), horizontalSizeClass: nil, fold: nil) == .compact)
    }

    @Test func regular는_컨테이너_방향으로_나눈다() {
        #expect(DrawLayoutResolver.resolve(size: CGSize(width: 1180, height: 820), horizontalSizeClass: .regular, fold: nil) == .regularLandscape)
        #expect(DrawLayoutResolver.resolve(size: CGSize(width: 820, height: 1180), horizontalSizeClass: .regular, fold: nil) == .regularPortrait)
    }

    @Test func 접힘이_컨테이너_밖이면_무시한다() {
        let outside = CGRect(x: 0, y: 700, width: 890, height: 24)
        #expect(DrawLayoutResolver.resolve(size: duoSize, horizontalSizeClass: .compact, fold: outside) == .compact)
    }

    @Test func 접힘_위나_아래가_너무_낮으면_기존_배치() {
        let nearTop = CGRect(x: 0, y: 60, width: 890, height: 24)
        #expect(DrawLayoutResolver.resolve(size: duoSize, horizontalSizeClass: .compact, fold: nearTop) == .compact)
    }
}
