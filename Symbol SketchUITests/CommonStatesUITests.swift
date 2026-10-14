//
//  CommonStatesUITests.swift
//  Symbol SketchUITests
//
//  Created by Hongjeongmin on 10/14/26.
//

import XCTest

/// M3: 공통 상태 5종(기획서 6장) — 최초 준비 · 검색 중 · 빈 상태 · 그림 부족 · 오류.
/// 오류·느린 준비·느린 검색은 DEBUG 실행 인자로 만든다(`UITestingStates`).
final class CommonStatesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_빈_상태와_그림_부족() throws {
        let app = launch()
        waitUntilReady(app)
        XCTAssertTrue(app.staticTexts["그림을 그리면 비슷한 심볼이\n여기에 나타나요"].exists, "그리기 빈 상태")
        attach(app, "draw_empty")

        // 아주 짧은 획은 찾지 않는다.
        let center = canvas(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 6, dy: 0)))
        XCTAssertTrue(app.staticTexts["그림이 너무 작거나 획이 적어서 찾지 않았어요"].waitForExistence(timeout: 5), "그림 부족")
        attach(app, "draw_too_small")

        app.tabBars.buttons["최근"].tap()
        XCTAssertTrue(app.staticTexts["아직 찾은 심볼이 없어요"].waitForExistence(timeout: 5))
        attach(app, "recent_empty")

        app.tabBars.buttons["콜렉션"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        attach(app, "collection_empty")
    }

    @MainActor
    func test_검색이_느리면_스켈레톤과_찾는_중() throws {
        let app = launch("-UITestingSlowSearch")
        waitUntilReady(app)

        let center = canvas(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.withOffset(CGVector(dx: -80, dy: -60)).press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 80, dy: 60)))
        XCTAssertTrue(app.staticTexts["찾는 중"].waitForExistence(timeout: 3) || app.buttons["찾는 중"].exists, "검색 중 표시")
        attach(app, "draw_searching")

        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '유사도'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "느려도 결과는 나온다")
    }

    @MainActor
    func test_준비_중에는_진행률을_보이고_끝나면_빈_상태() throws {
        let app = launch("-UITestingSlowPrepare")
        let preparing = app.staticTexts["심볼 준비 중"]
        XCTAssertTrue(preparing.waitForExistence(timeout: 5), "준비 중 표시")
        attach(app, "draw_preparing")
        waitUntilReady(app)
        XCTAssertTrue(app.staticTexts["그림을 그리면 비슷한 심볼이\n여기에 나타나요"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_온보딩_연습에서_준비_진행률() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryProgress", "-UITestingShowOnboarding", "-UITestingSlowPrepare"]
        app.launch()
        app.buttons["다음"].tap()
        app.buttons["다음"].tap()
        app.buttons["연습해 보기"].tap()
        let progress = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '심볼 준비 중'")).firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "연습 화면에 준비 진행률")
        attach(app, "onboarding_preparing")
    }

    @MainActor
    func test_준비에_실패하면_다시_준비하기() throws {
        let app = launch("-UITestingIndexFailure")
        XCTAssertTrue(app.staticTexts["심볼 인덱스를 읽지 못했어요"].waitForExistence(timeout: 10), "오류 표시")
        attach(app, "draw_error")

        app.buttons["다시 준비하기"].tap()
        waitUntilReady(app)
        XCTAssertTrue(app.staticTexts["그림을 그리면 비슷한 심볼이\n여기에 나타나요"].waitForExistence(timeout: 5), "다시 준비하면 빈 상태로")
    }

    // MARK: - 도우미

    @MainActor
    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryProgress", "-UITestingSkipOnboarding"] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func canvas(_ app: XCUIApplication) -> XCUIElement {
        let canvas = app.descendants(matching: .any)["sketchCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        return canvas
    }

    /// 심볼 준비가 끝날 때까지(시뮬레이터에 인덱스가 없으면 수 분)
    @MainActor
    private func waitUntilReady(_ app: XCUIApplication) {
        let preparing = app.staticTexts["심볼 준비 중"]
        _ = preparing.waitForExistence(timeout: 1)
        if preparing.exists {
            let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: preparing)
            wait(for: [gone], timeout: 900)
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
