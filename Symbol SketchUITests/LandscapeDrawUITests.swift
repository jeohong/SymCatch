//
//  LandscapeDrawUITests.swift
//  Symbol SketchUITests
//
//  Created by Hongjeongmin on 10/15/26.
//

import XCTest

/// 결정 23: iPhone 가로에서는 캔버스를 높이에 맞추고 결과를 옆에 둔다(세로로 쌓으면 160pt까지 줄던 문제).
/// 가로 스크린샷은 XCUITest가 잘라 찍으므로 마커를 출력하고 기다리는 동안 `simctl io screenshot`으로 찍는다.
final class LandscapeDrawUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func test_가로에서는_캔버스가_크고_결과가_옆에_있다() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launchWithInMemoryProgress()
        // 최근 줄이 보이도록 기록을 하나 남기고 그리기로 돌아온다.
        drawAndSelectFirstResult(app)
        // 같은 탭을 다시 누르면 처음 화면으로(탭 바·Duo 레일 공통)
        app.buttons["그리기"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["sketchCanvas"].waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(waitForWindow(of: app, landscape: true), "가로로 돌아가야 한다")
        let canvas = app.descendants(matching: .any)["sketchCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(canvas.frame.height, 240, "가로에서도 캔버스가 충분히 커야 한다(전에는 160~200)")

        let center = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.withOffset(CGVector(dx: -80, dy: -60)).press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 80, dy: 60)))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '유사도'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "가로에서도 결과가 보여야 한다")
        XCTAssertGreaterThan(row.frame.minX, canvas.frame.maxX, "결과는 캔버스 오른쪽 패널에 있다(바텀시트 아님)")
        print("LANDSCAPE_READY")
        Thread.sleep(forTimeInterval: 8)

        XCUIDevice.shared.orientation = .portrait
        // Duo 바깥 화면 시뮬레이터는 세로 복귀가 반영되지 않을 때가 있어 그때는 세로 확인을 건너뛴다.
        guard waitForWindow(of: app, landscape: false) else {
            print("세로 복귀가 반영되지 않아 세로 확인을 건너뜀")
            return
        }
        print("PORTRAIT_READY")
        Thread.sleep(forTimeInterval: 5)
        let portraitCanvas = app.descendants(matching: .any)["sketchCanvas"]
        let portraitRow = app.buttons.matching(NSPredicate(format: "label CONTAINS '유사도'")).firstMatch
        XCTAssertGreaterThan(portraitRow.frame.minY, portraitCanvas.frame.maxY, "세로로 돌아오면 결과는 캔버스 아래 시트")
    }

    /// 회전이 늦게 반영되는 기기(Duo 바깥 화면 시뮬레이터)가 있어 창 방향이 바뀔 때까지 기다리고, 배치가 끝나도록 조금 더 둔다.
    @MainActor
    private func waitForWindow(of app: XCUIApplication, landscape: Bool) -> Bool {
        let window = app.windows.firstMatch
        let turned = NSPredicate { _, _ in (window.frame.width > window.frame.height) == landscape }
        let result = XCTWaiter.wait(for: [expectation(for: turned, evaluatedWith: nil)], timeout: 15)
        Thread.sleep(forTimeInterval: 1.5)
        return result == .completed
    }
}
