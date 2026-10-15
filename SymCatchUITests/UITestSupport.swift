//
//  UITestSupport.swift
//  SymCatchUITests
//
//  Created by Hongjeongmin on 10/11/26.
//

import XCTest

extension XCUIApplication {
    /// 콜렉션 탭 → 개발 도구 → 해당 화면
    @MainActor
    func openDeveloperTool(_ title: String) {
        tabBars.buttons["콜렉션"].tap()
        buttons["개발 도구"].tap()
        buttons[title].tap()
    }
}

extension XCTestCase {
    /// 기록을 메모리에만 두고 앱을 연다(매번 빈 상태).
    @MainActor
    func launchWithInMemoryProgress() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryProgress", "-UITestingSkipOnboarding"]
        app.launch()
        return app
    }

    /// 심볼 준비가 끝날 때까지 기다리고, 캔버스에 선을 그어 첫 결과를 고른다. 축하 모달이 뜨면 닫는다.
    @MainActor
    func drawAndSelectFirstResult(_ app: XCUIApplication, offset: CGVector = CGVector(dx: 100, dy: 0)) {
        let canvas = app.descendants(matching: .any)["sketchCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        let preparing = app.staticTexts["심볼 준비 중"]
        if preparing.exists {
            let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: preparing)
            wait(for: [gone], timeout: 900)
        }
        let center = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.withOffset(offset).press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 0, dy: 100)))
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS '유사도'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "그린 뒤 결과가 나와야 한다")
        card.tap()

        let confirm = app.buttons["확인"]
        let next = app.buttons["다음"]
        if confirm.waitForExistence(timeout: 3) || next.exists {
            while next.exists { next.tap() }
            confirm.tap()
        }
    }
}
