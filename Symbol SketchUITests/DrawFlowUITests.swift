//
//  DrawFlowUITests.swift
//  Symbol SketchUITests
//
//  Created by Hongjeongmin on 10/11/26.
//

import XCTest

/// M1 수용 기준: 그리기에서 복사까지 3탭 이내(그리기 → 결과 탭 → 복사 탭).
final class DrawFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_그리고_결과를_탭해_이름을_복사한다() throws {
        let app = XCUIApplication()
        app.launch()

        // 첫 실행이면 심볼 준비를 기다린다(시뮬레이터는 CPU라 수 분 걸릴 수 있다).
        let canvas = app.descendants(matching: .any)["sketchCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        let preparing = app.staticTexts["심볼 준비 중"]
        if preparing.exists {
            let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: preparing)
            wait(for: [gone], timeout: 900)
        }
        attach(app, "ready")

        // 원 그리기
        let center = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let start = center.withOffset(CGVector(dx: 100, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 0, dy: 100)))
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS '유사도'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "그린 뒤 결과가 나와야 한다")
        attach(app, "results")

        // 탭 1: 결과 → 상세
        card.tap()
        let copyName = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '이름 복사'")).firstMatch
        XCTAssertTrue(copyName.waitForExistence(timeout: 10), "상세 화면이 열려야 한다")
        attach(app, "detail")

        // 탭 2: 이름 복사
        copyName.tap()
        XCTAssertTrue(app.staticTexts["복사했어요"].waitForExistence(timeout: 3) || app.descendants(matching: .any)["복사했어요"].exists)
        attach(app, "copied")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
