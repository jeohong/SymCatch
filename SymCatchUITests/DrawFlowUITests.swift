//
//  DrawFlowUITests.swift
//  SymCatchUITests
//
//  Created by Hongjeongmin on 10/11/26.
//

import XCTest

/// M1 수용 기준: 그리기에서 복사까지 3탭 이내(그리기 → 결과 탭 → 복사 탭).
/// M2: 결과를 탭하면 기록이 저장되고, 첫 선택이면 축하 모달(S4)이 뜬다. 기록은 메모리에만 둬서 매번 빈 상태로 시작한다.
final class DrawFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_그리고_결과를_탭해_이름을_복사한다() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryProgress", "-UITestingSkipOnboarding"]
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

        // 탭 1: 결과 → 상세. 첫 선택이라 "첫 번째 획" 업적 축하 모달이 상세 위에 뜬다.
        card.tap()
        let confirm = app.buttons["확인"]
        let next = app.buttons["다음"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5) || next.exists, "첫 선택이면 축하 모달이 떠야 한다")
        attach(app, "celebration")
        while next.exists { next.tap() }
        confirm.tap()
        XCTAssertFalse(confirm.waitForExistence(timeout: 1), "확인을 누르면 모달이 닫혀야 한다")

        let copyName = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '이름 복사'")).firstMatch
        XCTAssertTrue(copyName.waitForExistence(timeout: 10), "상세 화면이 열려야 한다")
        attach(app, "detail")

        // 탭 2: 이름 복사
        copyName.tap()
        XCTAssertTrue(app.staticTexts["복사했어요"].waitForExistence(timeout: 3) || app.descendants(matching: .any)["복사했어요"].exists)
        attach(app, "copied")

        // 뒤로 가면 상단에 방금 찾은 심볼이 최근 칩으로 보인다.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["최근"].waitForExistence(timeout: 5), "최근 스트립이 보여야 한다")
        attach(app, "recentStrip")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
