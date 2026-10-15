//
//  EvaluationRunUITests.swift
//  SymCatchUITests
//
//  Created by Hongjeongmin on 10/11/26.
//

import XCTest

/// 개발 도구 → 평가 실행: 화면이 열리고 실행 결과(또는 안내)가 나온다. 수치는 실기기에서만 의미가 있다.
final class EvaluationRunUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_평가_실행_화면이_열리고_실행된다() throws {
        let app = launchWithInMemoryProgress()
        app.openDeveloperTool("평가 실행")

        let run = app.buttons["평가 실행"]
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()

        let outcomes = [
            app.staticTexts["그림이 부족해 보정값을 계산하지 못했어요"],
            app.staticTexts["심볼 준비가 끝나지 않았어요. 그리기 탭에서 준비를 마친 뒤 실행하세요."],
            app.staticTexts["추천 보정값"],
        ]
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline, !outcomes.contains(where: \.exists) {
            _ = outcomes[0].waitForExistence(timeout: 1)
        }
        XCTAssertTrue(outcomes.contains(where: \.exists), "실행 결과나 안내가 보여야 한다")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "evaluationRun"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
