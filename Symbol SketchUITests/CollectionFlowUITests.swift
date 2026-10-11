//
//  CollectionFlowUITests.swift
//  Symbol SketchUITests
//
//  Created by Hongjeongmin on 10/11/26.
//

import XCTest

/// M2: 뱃지를 받으면 콜렉션(S6)에 쌓이고, 메달 → 뱃지 상세(S7) → 도전하기로 그리기 화면에 목표가 뜬다.
final class CollectionFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_콜렉션에서_도전하기로_그리기_목표를_띄운다() throws {
        let app = launchWithInMemoryProgress()

        app.tabBars.buttons["콜렉션"].tap()
        XCTAssertTrue(app.staticTexts["유사도 90% 이상인 심볼을 고르면 뱃지를 얻어요"].waitForExistence(timeout: 10), "뱃지가 없으면 안내가 보여야 한다")
        attach(app, "collectionEmpty")

        // 시뮬레이터는 유사도가 늘 100%라 첫 결과를 고르면 골드 뱃지를 받는다.
        app.tabBars.buttons["그리기"].tap()
        drawAndSelectFirstResult(app)

        app.tabBars.buttons["콜렉션"].tap()
        XCTAssertTrue(app.staticTexts["명사수"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["유사도 90% 이상인 심볼을 고르면 뱃지를 얻어요"].exists, "뱃지를 받으면 안내가 사라져야 한다")
        attach(app, "collection")

        // 미획득 메달 → S7 → 그려서 도전하기
        let locked = app.buttons.matching(NSPredicate(format: "label ENDSWITH ', 미획득'")).firstMatch
        XCTAssertTrue(locked.waitForExistence(timeout: 5))
        let name = locked.label.replacingOccurrences(of: ", 미획득", with: "")
        locked.tap()
        let challenge = app.buttons["그려서 도전하기"]
        XCTAssertTrue(challenge.waitForExistence(timeout: 5))
        attach(app, "badgeDetail")
        challenge.tap()

        XCTAssertTrue(app.staticTexts["목표 · \(name)"].waitForExistence(timeout: 5), "그리기 화면에 목표 카드가 떠야 한다")
        attach(app, "challenge")
        app.buttons["목표 해제"].tap()
        XCTAssertFalse(app.staticTexts["목표 · \(name)"].waitForExistence(timeout: 1))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
