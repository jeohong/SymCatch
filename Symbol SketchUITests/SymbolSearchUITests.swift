//
//  SymbolSearchUITests.swift
//  Symbol SketchUITests
//
//  Created by Hongjeongmin on 10/15/26.
//

import XCTest

/// 심볼 검색 탭(S9): 글자로 찾아 상세로 가고, 카테고리를 둘러본다.
final class SymbolSearchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func test_이름으로_찾아_상세로_가고_카테고리를_둘러본다() throws {
        let app = launchWithInMemoryProgress()
        // iPhone은 아래 탭 바, iPad·펼친 Duo는 위쪽 탭 바·레일이라 탭 바가 없으면 버튼으로 찾는다.
        let tabBarSearch = app.tabBars.buttons["검색"]
        (tabBarSearch.waitForExistence(timeout: 5) ? tabBarSearch : app.buttons["검색"].firstMatch).tap()

        XCTAssertTrue(app.staticTexts["카테고리 둘러보기"].waitForExistence(timeout: 10), "처음에는 카테고리 둘러보기")
        attach(app, "browse")

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("heart")
        let heart = app.buttons["heart"]
        XCTAssertTrue(heart.waitForExistence(timeout: 5), "heart가 결과에 있어야 한다")
        XCTAssertTrue(app.buttons["suit.heart"].exists, "이름 중간에 heart가 있는 심볼도 나와야 한다")
        attach(app, "results")

        // 한국어로도 찾는다(사전: heart → 하트)
        field.buttons.firstMatch.tap()   // 지우기(✕)
        app.searchFields.firstMatch.tap()   // iPad는 지우기 뒤 포커스가 풀린다
        app.searchFields.firstMatch.typeText("하트")
        XCTAssertTrue(app.buttons["heart"].waitForExistence(timeout: 5), "'하트'로 heart를 찾아야 한다")
        attach(app, "results_korean")

        app.buttons["heart"].tap()
        XCTAssertTrue(app.staticTexts["복사"].waitForExistence(timeout: 5), "상세로 가야 한다")
        XCTAssertFalse(app.staticTexts["내 그림과 비교"].exists, "검색에서 온 상세에는 그림 비교가 없다")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 검색어를 지우고 카테고리를 고르면 그 카테고리 심볼만
        app.searchFields.firstMatch.buttons.firstMatch.tap()   // 지우기(✕)
        if app.buttons["취소"].exists { app.buttons["취소"].tap() }
        let nature = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '자연'")).firstMatch
        XCTAssertTrue(nature.waitForExistence(timeout: 5))
        nature.tap()
        XCTAssertTrue(app.buttons["자연 카테고리 해제"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '결과 '")).firstMatch.exists)
        attach(app, "category")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
