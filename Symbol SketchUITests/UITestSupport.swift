//
//  UITestSupport.swift
//  Symbol SketchUITests
//
//  Created by Hongjeongmin on 10/11/26.
//

import XCTest

extension XCUIApplication {
    /// 콜렉션 탭 → 개발 도구 → 해당 화면
    @MainActor
    func openDeveloperTool(_ title: String) {
        tabBars.buttons["콜렉션"].tap()
        buttons["개발 도구"].tap()
        buttons[title].tap()
    }
}
