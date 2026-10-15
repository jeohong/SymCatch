//
//  OnboardingFlowUITests.swift
//  SymCatchUITests
//
//  Created by Hongjeongmin on 10/14/26.
//

import XCTest

/// M3: 첫 실행 온보딩(S0). 소개 3장 → 하트 연습 → 결과 탭 → 첫 번째 획 업적 → 그리기 홈.
final class OnboardingFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_소개를_넘기고_연습에서_고르면_업적과_함께_홈으로() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryProgress", "-UITestingShowOnboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["그려서 찾기"].waitForExistence(timeout: 10), "첫 실행이면 온보딩이 보여야 한다")
        attach(app, "intro1")
        app.buttons["다음"].tap()
        XCTAssertTrue(app.staticTexts["유사도로 비교하기"].waitForExistence(timeout: 3))
        attach(app, "intro2")
        app.buttons["다음"].tap()
        XCTAssertTrue(app.staticTexts["85% 넘으면 뱃지"].waitForExistence(timeout: 3))
        attach(app, "intro3")
        app.buttons["연습해 보기"].tap()

        XCTAssertTrue(app.staticTexts["하트를 그려 보세요"].waitForExistence(timeout: 3))
        // 시뮬레이터에 인덱스가 없으면 준비가 끝날 때까지 기다린다.
        let ready = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '준비 완료'")).firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 900), "심볼 준비가 끝나야 한다")

        // 온보딩 아래에 그리기 화면 캔버스도 깔려 있으므로, 실제로 누를 수 있는 쪽을 고른다.
        let canvases = app.descendants(matching: .any).matching(identifier: "sketchCanvas").allElementsBoundByIndex
        let canvas = try XCTUnwrap(canvases.first { $0.isHittable }, "연습 캔버스가 보여야 한다")
        let center = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.withOffset(CGVector(dx: -80, dy: -40)).press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 80, dy: 60)))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '유사도'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "그리면 결과가 나와야 한다")
        attach(app, "practice")
        row.tap()

        // 첫 선택이라 "첫 번째 획" 업적(그리고 뱃지) 카드가 뜬다.
        let confirm = app.buttons["확인"], next = app.buttons["다음"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5) || next.exists, "축하 모달이 떠야 한다")
        attach(app, "celebration")
        while next.exists { next.tap() }
        confirm.tap()

        XCTAssertTrue(app.tabBars.buttons["그리기"].waitForExistence(timeout: 5), "그리기 홈으로 가야 한다")
        XCTAssertFalse(app.staticTexts["하트를 그려 보세요"].exists, "온보딩이 닫혀야 한다")
        XCTAssertTrue(app.staticTexts["최근"].waitForExistence(timeout: 5), "연습에서 고른 심볼이 최근에 보여야 한다")
        attach(app, "home")
    }

    @MainActor
    func test_건너뛰면_바로_홈() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryProgress", "-UITestingShowOnboarding"]
        app.launch()

        XCTAssertTrue(app.buttons["건너뛰기"].waitForExistence(timeout: 10))
        app.buttons["건너뛰기"].tap()
        XCTAssertTrue(app.tabBars.buttons["그리기"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["그려서 찾기"].exists)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
