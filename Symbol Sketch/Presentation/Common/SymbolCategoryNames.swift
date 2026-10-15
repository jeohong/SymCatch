//
//  SymbolCategoryNames.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// SF Symbols 카테고리 키 → 화면에 보일 이름. symbols.json의 라벨은 영어라서 한국어 이름을 여기서 붙인다.
enum SymbolCategoryNames {
    static func displayName(for category: SymbolCategory) -> String {
        displayName(for: category.key, fallback: category.label)
    }

    /// 키만 알 때(업적 등). 모르는 키는 키 그대로 보여 준다.
    static func displayName(for key: String, fallback: String? = nil) -> String {
        switch key {
        case "communication": String(localized: "커뮤니케이션")
        case "weather": String(localized: "날씨")
        case "maps": String(localized: "지도")
        case "objectsandtools": String(localized: "사물 및 도구")
        case "devices": String(localized: "기기")
        case "cameraandphotos": String(localized: "카메라 및 사진")
        case "gaming": String(localized: "게임")
        case "connectivity": String(localized: "연결")
        case "transportation": String(localized: "교통")
        case "automotive": String(localized: "자동차")
        case "accessibility": String(localized: "손쉬운 사용")
        case "privacyandsecurity": String(localized: "개인정보 보호 및 보안")
        case "human": String(localized: "사람")
        case "home": String(localized: "홈")
        case "fitness": String(localized: "피트니스")
        case "nature": String(localized: "자연")
        case "editing": String(localized: "편집")
        case "textformatting": String(localized: "텍스트 서식")
        case "media": String(localized: "미디어")
        case "keyboard": String(localized: "키보드")
        case "commerce": String(localized: "상거래")
        case "time": String(localized: "시간")
        case "health": String(localized: "건강")
        case "shapes": String(localized: "도형")
        case "arrows": String(localized: "화살표")
        case "indices": String(localized: "번호")
        case "math": String(localized: "수학")
        case SymbolCategory.uncategorized.key: String(localized: "기타")
        default: fallback ?? key
        }
    }
}
