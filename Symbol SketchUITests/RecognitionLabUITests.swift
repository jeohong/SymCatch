//
//  RecognitionLabUITests.swift
//  Symbol SketchUITests
//
//  Created by Hongjeongmin on 10/11/26.
//

import XCTest

/// 인식 실험: 준비 → 그리기 → 자동 검색 → Top 10 결과까지 실제 앱에서 이어지는지 확인한다.
/// 방식 A(윤곽 비교)만 확인한다. 방식 B는 시뮬레이터에서 준비에 수 분이 걸린다.
final class RecognitionLabUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_방식A를_준비하고_그리면_결과가_나온다() throws {
        let app = XCUIApplication()
        app.launch()
        app.openDeveloperTool("인식 실험")

        let prepare = app.buttons["준비하기"]
        if prepare.waitForExistence(timeout: 5) {
            prepare.tap()
        }
        XCTAssertTrue(app.staticTexts["준비됨"].waitForExistence(timeout: 300), "방식 A 준비가 5분 안에 끝나야 한다")
        attachScreenshot(app, name: "prepared")

        let canvas = app.descendants(matching: .any)["sketchCanvas"]
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(app.staticTexts["minus"].waitForExistence(timeout: 30) || app.cells.firstMatch.waitForExistence(timeout: 5),
                      "그린 뒤 결과 목록이 나와야 한다")
        attachScreenshot(app, name: "results")
    }

    /// 방식 B(채움) 준비 → 검색. 시뮬레이터에서는 CPU로 돌아 수 분이 걸린다.
    @MainActor
    func test_방식B를_준비하고_그리면_결과가_나온다() throws {
        let app = XCUIApplication()
        app.launch()
        app.openDeveloperTool("인식 실험")
        app.buttons["B 채움"].tap()

        let prepare = app.buttons["준비하기"]
        if prepare.waitForExistence(timeout: 5) {
            prepare.tap()
        }
        XCTAssertTrue(app.staticTexts["준비됨"].waitForExistence(timeout: 900), "방식 B 준비가 15분 안에 끝나야 한다")
        attachScreenshot(app, name: "b-prepared")

        let canvas = app.descendants(matching: .any)["sketchCanvas"]
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 30), "그린 뒤 결과 목록이 나와야 한다")
        attachScreenshot(app, name: "b-results")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
