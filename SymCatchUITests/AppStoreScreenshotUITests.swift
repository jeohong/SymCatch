//
//  AppStoreScreenshotUITests.swift
//  SymCatchUITests
//
//  Created by Hongjeongmin on 10/16/26.
//

import XCTest

/// App Store 스크린샷 촬영용. 데모 모드(`-ScreenshotDemo`)로 앱을 열고 장면마다 `SHOT:<이름>`을 출력한 뒤 잠시 멈춘다.
/// 실제 촬영은 바깥 스크립트(`Tools/appstore/capture.sh`)가 표시를 보고 `simctl io screenshot`으로 한다
/// (Duo 반쯤 접힘에서는 XCUITest 스크린샷이 검게 나오기 때문).
///
/// 환경 변수(xcodebuild에 `TEST_RUNNER_` 접두로 넘긴다)
/// - `SHOT_LANG`: `ko`(기본) 또는 `en`
/// - `SHOT_SCENES`: 찍을 장면, 쉼표로 구분(기본 전체). draw, top10, celebration, detail, collection, recent, search
/// - `SHOT_ORIENTATION`: `portrait`(기본), `landscape`, `keep`(기기 방향 그대로)
final class AppStoreScreenshotUITests: XCTestCase {
    private let environment = ProcessInfo.processInfo.environment
    private var isEnglish: Bool { environment["SHOT_LANG"] == "en" }
    private var scenes: Set<String> {
        let all: Set = ["draw", "top10", "celebration", "detail", "collection", "recent", "search"]
        guard let list = environment["SHOT_SCENES"], !list.isEmpty else { return all }
        return Set(list.split(separator: ",").map(String.init))
    }

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test_appStoreScreenshots() throws {
        // keep: 기기(시뮬레이터)에서 돌려 둔 방향을 그대로 쓴다(Duo 바깥 화면 가로 등).
        switch environment["SHOT_ORIENTATION"] {
        case "landscape": XCUIDevice.shared.orientation = .landscapeLeft
        case "keep": break
        default: XCUIDevice.shared.orientation = .portrait
        }
        let app = XCUIApplication()
        app.launchArguments += ["-ScreenshotDemo"]
        app.launchArguments += isEnglish ? ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
                                         : ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text("유사도", "similar"))).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "데모 결과가 나와야 한다")
        sleep(2)
        shot("draw")

        if scenes.contains("top10") {
            // 결과 시트를 펼쳐 Top 10을 보인다(시트가 있는 배치에서만 버튼이 있다).
            let seeAll = app.buttons[text("모두 보기", "See All")]
            if seeAll.exists { seeAll.tap() }
            sleep(2)
            shot("top10")
        }

        guard scenes.contains("celebration") || scenes.contains("detail") || scenes.contains("collection")
                || scenes.contains("recent") || scenes.contains("search") else { return }

        // 1위(heart 96%)를 고르면 상세로 가고 골드 뱃지 축하가 뜬다.
        card.tap()
        let next = app.buttons[text("다음", "Next")]
        let confirm = app.buttons[text("확인", "OK")]
        if confirm.waitForExistence(timeout: 5) || next.exists {
            sleep(2)
            shot("celebration")
            while next.exists { next.tap() }
            if confirm.exists { confirm.tap() }
        }
        sleep(2)
        shot("detail")

        if scenes.contains("collection") {
            openTab(app, text("콜렉션", "Collection"))
            sleep(3)
            shot("collection")
        }
        if scenes.contains("recent") {
            openTab(app, text("최근", "Recent"))
            sleep(3)
            shot("recent")
        }
        if scenes.contains("search") {
            openTab(app, text("검색", "Search"))
            let field = app.searchFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            field.tap()
            field.typeText(text("하트", "heart") + "\n")
            sleep(3)
            shot("search")
        }
    }

    private func text(_ korean: String, _ english: String) -> String {
        isEnglish ? english : korean
    }

    @MainActor
    private func openTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name]
        (tab.exists ? tab : app.buttons[name].firstMatch).tap()
    }

    /// 바깥 스크립트가 이 표시를 보고 화면을 찍는다.
    private func shot(_ name: String) {
        print("SHOT:\(name)")
        sleep(4)
    }
}
