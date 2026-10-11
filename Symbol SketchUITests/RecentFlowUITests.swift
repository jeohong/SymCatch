//
//  RecentFlowUITests.swift
//  Symbol SketchUITests
//
//  Created by Hongjeongmin on 10/11/26.
//

import XCTest

/// M2: 결과를 고르면 최근 탭(S5)에 기록이 생기고, 밀어서 지우면 빈 상태가 된다.
final class RecentFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_고른_심볼이_최근에_쌓이고_지우면_빈_상태() throws {
        let app = launchWithInMemoryProgress()

        app.tabBars.buttons["최근"].tap()
        XCTAssertTrue(app.staticTexts["아직 찾은 심볼이 없어요"].waitForExistence(timeout: 5))
        attach(app, "empty")

        // 빈 상태의 "그리러 가기" → 그리기 탭에서 결과 선택
        app.buttons["그리러 가기"].tap()
        drawAndSelectFirstResult(app)

        app.tabBars.buttons["최근"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '유사도'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "고른 심볼이 최근 목록에 있어야 한다")
        XCTAssertTrue(app.staticTexts["오늘"].exists)
        attach(app, "list")

        // 행을 탭하면 당시 그림과 함께 상세가 열린다.
        row.tap()
        XCTAssertTrue(app.staticTexts["당시 그림"].waitForExistence(timeout: 5))
        attach(app, "detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 밀어서 삭제
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["삭제"].tap()
        XCTAssertTrue(app.staticTexts["아직 찾은 심볼이 없어요"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
