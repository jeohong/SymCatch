//
//  AccessibilityUITests.swift
//  SymCatchUITests
//
//  Created by Hongjeongmin on 10/14/26.
//

import XCTest

/// M3 접근성: 화면마다 Xcode 접근성 감사(대비·탭 영역·글자 잘림·레이블)를 돌리고 스크린샷을 남긴다.
/// 기본 글자 크기와 가장 큰 접근성 글자 크기(AX5) 두 번 돈다. 감사 결과는 "A11Y" 첨부로 모은다.
final class AccessibilityUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_기본_글자_크기() throws {
        try walkAllScreens(arguments: [], tag: "default")
    }

    @MainActor
    func test_가장_큰_글자_크기() throws {
        try walkAllScreens(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"], tag: "ax5")
    }

    @MainActor
    func test_온보딩() throws {
        for (arguments, tag) in [([String](), "default"), (["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"], "ax5")] {
            let app = XCUIApplication()
            app.launchArguments += ["-UITestingInMemoryProgress", "-UITestingShowOnboarding"] + arguments
            app.launch()
            XCTAssertTrue(app.buttons["건너뛰기"].waitForExistence(timeout: 10))
            try check(app, "\(tag)_S0_intro1")
            app.buttons["다음"].tap()
            try check(app, "\(tag)_S0_intro2")
            app.buttons["다음"].tap()
            try check(app, "\(tag)_S0_intro3")
            app.buttons["연습해 보기"].tap()
            XCTAssertTrue(app.staticTexts["하트를 그려 보세요"].waitForExistence(timeout: 5))
            try check(app, "\(tag)_S0_practice")
            app.terminate()
        }
    }

    // MARK: - 화면 순회

    @MainActor
    private func walkAllScreens(arguments: [String], tag: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestingInMemoryProgress", "-UITestingSkipOnboarding"] + arguments
        app.launch()

        // S1 빈 상태
        let canvas = app.descendants(matching: .any)["sketchCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        let preparing = app.staticTexts["심볼 준비 중"]
        if preparing.exists {
            wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: preparing)], timeout: 900)
        }
        try check(app, "\(tag)_S1_empty")

        // S1 결과 → S2 펼침
        let center = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.withOffset(CGVector(dx: -60, dy: -40)).press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 60, dy: 60)))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '유사도'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        try check(app, "\(tag)_S1_results")
        let expand = app.buttons["모두 보기"]
        if expand.waitForExistence(timeout: 3) {
            expand.tap()
            try check(app, "\(tag)_S2_expanded")
        }

        // S4 축하 → S3 상세
        row.tap()
        let next = app.buttons["다음"], confirm = app.buttons["확인"]
        if confirm.waitForExistence(timeout: 5) || next.exists {
            try check(app, "\(tag)_S4_celebration")
            while next.exists { next.tap() }
            confirm.tap()
        }
        XCTAssertTrue(app.staticTexts["복사"].waitForExistence(timeout: 5))
        try check(app, "\(tag)_S3_detail")
        app.swipeUp()
        try check(app, "\(tag)_S3_detail_bottom")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // S5 최근
        app.tabBars.buttons["최근"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS '유사도'")).firstMatch.waitForExistence(timeout: 5))
        try check(app, "\(tag)_S5_recent")

        // S6 콜렉션 → S7 뱃지 상세(획득 · 미획득)
        app.tabBars.buttons["콜렉션"].tap()
        XCTAssertTrue(app.staticTexts["명사수"].waitForExistence(timeout: 10))
        try check(app, "\(tag)_S6_collection")
        let earned = app.buttons.matching(NSPredicate(format: "label ENDSWITH ' 뱃지' AND NOT (label CONTAINS '미획득')")).firstMatch
        if scrollUntilHittable(earned, in: app, attempts: 150) {
            earned.tap()
            XCTAssertTrue(app.staticTexts["당시 그림"].waitForExistence(timeout: 5))
            try check(app, "\(tag)_S7_earned")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        let locked = app.buttons.matching(NSPredicate(format: "label ENDSWITH ', 미획득'")).firstMatch
        if scrollUntilHittable(locked, in: app) {
            locked.tap()
            XCTAssertTrue(app.buttons["그려서 도전하기"].waitForExistence(timeout: 5))
            try check(app, "\(tag)_S7_locked")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // S8 설정(톱니는 콜렉션 맨 위)
        app.tabBars.buttons["콜렉션"].tap()
        app.tabBars.buttons["콜렉션"].tap()
        XCTAssertTrue(app.buttons["설정"].waitForExistence(timeout: 5))
        app.buttons["설정"].tap()
        XCTAssertTrue(app.staticTexts["심볼 인덱스"].waitForExistence(timeout: 5))
        try check(app, "\(tag)_S8_settings")
    }

    /// 콜렉션 격자는 화면에 들어온 칸만 그려지므로, 찾을 때까지 위로 민다.
    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 25) -> Bool {
        for _ in 0..<attempts {
            if element.exists, element.isHittable { return true }
            // 이미 지나쳐 위에 있으면 아래로, 아직 아래에 있으면(또는 아직 안 그려졌으면) 위로 민다.
            if element.exists, element.frame.maxY < app.frame.midY {
                app.swipeDown()
            } else {
                app.swipeUp(velocity: .fast)
            }
        }
        return element.exists && element.isHittable
    }

    // MARK: - 감사 + 스크린샷

    @MainActor
    private func check(_ app: XCUIApplication, _ name: String) throws {
        Thread.sleep(forTimeInterval: 1)   // 화면 전환 애니메이션이 끝난 뒤 찍는다.
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)

        var issues: [String] = []
        try app.performAccessibilityAudit(for: .all) { issue in
            let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' id=\($0.identifier)" } ?? "-"
            issues.append("[\(issue.auditType)] \(issue.compactDescription) | \(element)")
            return true   // 테스트를 멈추지 않고 목록으로 모은다.
        }
        let report = XCTAttachment(string: issues.isEmpty ? "문제 없음" : issues.joined(separator: "\n"))
        report.name = "A11Y_\(name)"
        report.lifetime = .keepAlways
        add(report)
        print("A11Y \(name): \(issues.count)건")
        issues.forEach { print("A11Y   \($0)") }
    }
}
