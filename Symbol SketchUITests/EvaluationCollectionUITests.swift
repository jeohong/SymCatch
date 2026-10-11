//
//  EvaluationCollectionUITests.swift
//  Symbol SketchUITests
//
//  Created by Hongjeongmin on 10/11/26.
//

import XCTest

/// 수집 모드에서 손가락으로 끌면 실제로 그려지는지 확인한다.
/// (캔버스를 ScrollView 안에 두면 끄는 동작이 스크롤로 처리돼 그려지지 않던 문제의 회귀 테스트)
final class EvaluationCollectionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_손가락으로_끌면_그려지고_저장할_수_있다() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["평가셋 수집"].tap()

        let author = app.textFields["authorField"]
        XCTAssertTrue(author.waitForExistence(timeout: 5))
        author.tap()
        author.typeText("uitest\n")

        let save = app.buttons["saveButton"]
        XCTAssertFalse(save.isEnabled, "그리기 전에는 저장할 수 없어야 한다")

        let canvas = app.descendants(matching: .any)["sketchCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "drawn"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(save.isEnabled, "끌어서 그린 뒤에는 저장할 수 있어야 한다")
    }
}
