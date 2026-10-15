//
//  CanvasRotationUITests.swift
//  SymCatchUITests
//
//  Created by Hongjeongmin on 10/14/26.
//

import XCTest

/// M4: 캔버스 크기가 바뀌어도(회전·Duo 접기) 그리던 그림이 같은 자리·같은 비율로 남는다.
/// PencilKit 화면이 이전 크기로 남던 문제(10-14)의 회귀 테스트. 그림 위치는 첨부 스크린샷으로 확인한다.
final class CanvasRotationUITests: XCTestCase {
    @MainActor
    func test_회전해도_그림_위치_유지() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryProgress", "-UITestingSkipOnboarding"]
        app.launch()

        let canvas = app.descendants(matching: .any)["sketchCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        // 왼쪽 위 사분면에 짧은 가로 획
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.2))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.2))
        start.press(forDuration: 0.05, thenDragTo: end)
        Thread.sleep(forTimeInterval: 1.5)
        attach(app, "1_portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 2)
        attach(app, "2_landscape")

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2)
        attach(app, "3_portrait_again")

        XCTAssertFalse(app.buttons["되돌리기"].isEnabled, "크기가 바뀐 뒤에는 되돌리기 기록을 비운다")
        // 새 획은 다시 되돌릴 수 있다.
        let canvas2 = app.descendants(matching: .any)["sketchCanvas"]
        canvas2.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7))
            .press(forDuration: 0.05, thenDragTo: canvas2.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7)))
        XCTAssertTrue(app.buttons["되돌리기"].waitForExistence(timeout: 2) && app.buttons["되돌리기"].isEnabled)
        app.buttons["되돌리기"].tap()
        Thread.sleep(forTimeInterval: 1)
        attach(app, "4_after_undo")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
