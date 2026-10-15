//
//  SettingsFlowUITests.swift
//  SymCatchUITests
//
//  Created by Hongjeongmin on 10/14/26.
//

import XCTest

/// M3: 콜렉션 톱니 → 설정(S8). 기록 초기화(확인 알림), 심볼 다시 준비하기(그리기 탭으로 이동).
final class SettingsFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_설정에서_초기화하고_다시_준비하기() throws {
        let app = launchWithInMemoryProgress()
        drawAndSelectFirstResult(app)

        app.tabBars.buttons["콜렉션"].tap()
        app.buttons["설정"].tap()
        XCTAssertTrue(app.staticTexts["심볼 인덱스"].waitForExistence(timeout: 5))
        attach(app, "settings")

        // 기록 초기화: 알림에서 초기화하면 콜렉션이 비어 안내가 보인다.
        app.buttons["기록 초기화"].tap()
        XCTAssertTrue(app.alerts["기록을 초기화할까요?"].waitForExistence(timeout: 3))
        attach(app, "resetAlert")
        app.alerts.buttons["초기화"].tap()
        XCTAssertTrue(app.staticTexts["기록을 초기화했어요"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["유사도 85% 이상인 심볼을 고르면 뱃지를 얻어요"].waitForExistence(timeout: 5), "초기화 후 콜렉션이 비어야 한다")

        // 심볼 다시 준비하기 → 그리기 탭에서 준비가 시작된다.
        app.buttons["설정"].tap()
        app.buttons["심볼 다시 준비하기"].tap()
        XCTAssertTrue(app.staticTexts["심볼 준비 중"].waitForExistence(timeout: 5), "그리기 탭에서 준비 중이 보여야 한다")
        attach(app, "rebuilding")
    }

    /// 설정에서 테마를 라이트 ↔ 다크로 바꿔도 앱이 멈추지 않는다(10-14 실기기 신고).
    @MainActor
    func test_테마를_바꿔도_멈추지_않는다() throws {
        let app = launchWithInMemoryProgress()
        app.tabBars.buttons["콜렉션"].tap()
        app.buttons["설정"].tap()
        XCTAssertTrue(app.staticTexts["심볼 인덱스"].waitForExistence(timeout: 5))

        for title in ["라이트", "다크", "라이트", "시스템"] {
            app.buttons[title].tap()
            // 멈추면 다음 탭이 응답하지 않아 여기서 실패한다.
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5), "\(title)로 바꾼 뒤에도 화면이 응답해야 한다")
            attach(app, "theme_\(title)")
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["그리기"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["sketchCanvas"].waitForExistence(timeout: 5), "다른 탭으로도 이동할 수 있어야 한다")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
