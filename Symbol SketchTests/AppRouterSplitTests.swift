//
//  AppRouterSplitTests.swift
//  Symbol SketchTests
//
//  Created by Hongjeongmin on 10/15/26.
//

import Foundation
import Testing
@testable import Symbol_Sketch

/// M4.5: 넓은 창(분할 화면)에서는 오른쪽 상세를 바꾸고, 좁은 창에서는 경로에 쌓는다(기획서 8A.1).
@MainActor
struct AppRouterSplitTests {
    private let request = SymbolDetailRequest(name: "heart", sketch: nil, similarity: 92, isPastSketch: true)

    private func makeRouter(split: Bool) -> AppRouter {
        let router = AppRouter(showsOnboarding: false, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        router.isSplitLayout = split
        return router
    }

    @Test func 좁은_창의_최근_상세는_경로에_쌓는다() {
        let router = makeRouter(split: false)
        router.showRecentDetail(request)
        #expect(router.recentPath == [.symbolDetail(request)])
        #expect(router.recentSelection == nil)
    }

    @Test func 넓은_창의_최근_상세는_오른쪽_선택을_바꾼다() {
        let router = makeRouter(split: true)
        router.showRecentDetail(request)
        #expect(router.recentSelection == request)
        #expect(router.recentPath.isEmpty)
    }

    @Test func 넓은_창의_콜렉션은_뱃지_설정을_오른쪽에_보여_주고_이어진_경로를_비운다() {
        let router = makeRouter(split: true)
        router.showBadgeDetail(symbolName: "heart")
        router.showCollectionSymbolDetail(request)
        #expect(router.collectionSelection == .badgeDetail(symbolName: "heart"))
        #expect(router.collectionDetailPath == [.symbolDetail(request)])

        router.showSettings()
        #expect(router.collectionSelection == .settings)
        #expect(router.collectionDetailPath.isEmpty)
        #expect(router.collectionPath.isEmpty)
    }

    @Test func 좁은_창의_콜렉션은_경로에_쌓는다() {
        let router = makeRouter(split: false)
        router.showBadgeDetail(symbolName: "heart")
        router.showSettings()
        #expect(router.collectionPath == [.badgeDetail(symbolName: "heart"), .settings])
        #expect(router.collectionSelection == nil)
    }
}
