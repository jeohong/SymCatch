//
//  ProgressDisplay.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 뱃지 등급·업적의 화면 표시용 이름(DESIGN_NOTES 6장 문자열)
extension BadgeTier {
    var displayName: String {
        switch self {
        case .bronze: String(localized: "브론즈")
        case .silver: String(localized: "실버")
        case .gold: String(localized: "골드")
        case .legendary: String(localized: "레전더리")
        }
    }
}

extension AchievementID {
    var displayName: String {
        switch self {
        case .firstStroke: String(localized: "첫 번째 획")
        case .sharpshooter: String(localized: "명사수")
        case .collector10: String(localized: "수집가 10")
        case .collector50: String(localized: "수집가 50")
        case .collector100: String(localized: "수집가 100")
        case .oneStroke: String(localized: "한 붓에")
        case .goldHand: String(localized: "골드 핸드")
        case .streak7: String(localized: "연속 출석 7일")
        case .categoryStarter(let key): CategoryAchievementNames.starter(for: key)
        case .categoryMaster(let key): CategoryAchievementNames.master(for: key)
        }
    }

    /// 달성 조건
    var condition: String {
        switch self {
        case .firstStroke: String(localized: "첫 검색 완료")
        case .sharpshooter: String(localized: "심볼 뱃지 1개 획득")
        case .collector10: String(localized: "심볼 뱃지 10개 획득")
        case .collector50: String(localized: "심볼 뱃지 50개 획득")
        case .collector100: String(localized: "심볼 뱃지 100개 획득")
        case .oneStroke: String(localized: "한 획으로 그려서 \(BadgeTierPolicy.threshold.percentText) 이상")
        case .goldHand: String(localized: "골드 이상 뱃지 5개 획득")
        case .streak7: String(localized: "7일 연속으로 그려서 찾기")
        case .categoryStarter(let key):
            String(localized: "\(SymbolCategoryNames.displayName(for: key)) 뱃지 \(AchievementID.categoryStarterGoal)개 획득")
        case .categoryMaster(let key):
            String(localized: "\(SymbolCategoryNames.displayName(for: key)) 뱃지 모두 획득")
        }
    }

    /// 메달 안 글리프(DESIGN_NOTES 5.1). 카테고리 업적은 카테고리 아이콘.
    var systemImage: String {
        switch self {
        case .firstStroke: "pencil.and.scribble"
        case .sharpshooter: "target"
        case .collector10: "square.stack.3d.up"
        case .collector50: "square.stack.3d.up.fill"
        case .collector100: "crown"
        case .oneStroke: "scribble"
        case .goldHand: "hand.raised"
        case .streak7: "flame"
        case .categoryStarter(let key), .categoryMaster(let key): CategoryAchievementNames.icon(for: key)
        }
    }

    /// 카테고리 업적 단계 이름("입문" · "전설"). 일반 업적은 nil.
    var categoryTierName: String? {
        switch self {
        case .categoryStarter: String(localized: "입문")
        case .categoryMaster: String(localized: "전설")
        default: nil
        }
    }
}

/// 카테고리 업적의 유쾌한 이름(기획서 3.2 표, 계획서 7장 결정 20)과 메달 아이콘(카탈로그 카테고리 아이콘)
enum CategoryAchievementNames {
    static func starter(for key: String) -> String {
        switch key {
        case "communication": String(localized: "수다 입문")
        case "weather": String(localized: "기상캐스터 지망생")
        case "maps": String(localized: "길치 탈출")
        case "objectsandtools": String(localized: "공구함 개봉")
        case "devices": String(localized: "얼리어답터")
        case "cameraandphotos": String(localized: "찰칵 입문")
        case "gaming": String(localized: "튜토리얼 클리어")
        case "connectivity": String(localized: "와이파이 잡았다")
        case "transportation": String(localized: "첫차 탑승")
        case "automotive": String(localized: "초보 운전")
        case "accessibility": String(localized: "배려 한 스푼")
        case "privacyandsecurity": String(localized: "자물쇠 챙김")
        case "human": String(localized: "사람 구경")
        case "home": String(localized: "집들이")
        case "fitness": String(localized: "오운완")
        case "nature": String(localized: "산책 시작")
        case "editing": String(localized: "실행 취소 입문")
        case "textformatting": String(localized: "볼드체 입문")
        case "media": String(localized: "재생 버튼 눌렀다")
        case "keyboard": String(localized: "독수리 타법")
        case "commerce": String(localized: "장바구니 담기")
        case "time": String(localized: "시계 볼 줄 앎")
        case "health": String(localized: "비타민 챙김")
        case "shapes": String(localized: "동그라미 그리기")
        case "arrows": String(localized: "이정표 발견")
        case "indices": String(localized: "숫자 세기")
        case "math": String(localized: "구구단 외움")
        // 새 SF Symbols 카테고리가 생기면 이름을 정할 때까지 카테고리 이름으로 보여 준다.
        default: String(localized: "\(SymbolCategoryNames.displayName(for: key)) 입문")
        }
    }

    static func master(for key: String) -> String {
        switch key {
        case "communication": String(localized: "인싸 오브 인싸")
        case "weather": String(localized: "날씨의 신")
        case "maps": String(localized: "인간 내비게이션")
        case "objectsandtools": String(localized: "맥가이버")
        case "devices": String(localized: "가젯 덕후 끝판왕")
        case "cameraandphotos": String(localized: "인생샷 장인")
        case "gaming": String(localized: "만렙 게이머")
        case "connectivity": String(localized: "초연결 인간")
        case "transportation": String(localized: "환승의 달인")
        case "automotive": String(localized: "카센터 사장님")
        case "accessibility": String(localized: "모두를 위한 손")
        case "privacyandsecurity": String(localized: "철통 보안")
        case "human": String(localized: "인류학 박사")
        case "home": String(localized: "살림 9단")
        case "fitness": String(localized: "근손실 제로")
        case "nature": String(localized: "대자연의 힘!")
        case "editing": String(localized: "편집의 신")
        case "textformatting": String(localized: "타이포 장인")
        case "media": String(localized: "미디어 재벌")
        case "keyboard": String(localized: "키보드 워리어")
        case "commerce": String(localized: "큰손")
        case "time": String(localized: "시간의 지배자")
        case "health": String(localized: "만수무강")
        case "shapes": String(localized: "피타고라스")
        case "arrows": String(localized: "방향 감각 만렙")
        case "indices": String(localized: "번호표 수집왕")
        case "math": String(localized: "수학의 정석")
        default: String(localized: "\(SymbolCategoryNames.displayName(for: key)) 전설")
        }
    }

    /// 카탈로그(symbols.json)의 카테고리 아이콘과 같은 값
    static func icon(for key: String) -> String {
        switch key {
        case "communication": "message"
        case "weather": "cloud.sun"
        case "maps": "map"
        case "objectsandtools": "folder"
        case "devices": "desktopcomputer"
        case "cameraandphotos": "camera"
        case "gaming": "gamecontroller"
        case "connectivity": "antenna.radiowaves.left.and.right"
        case "transportation": "car.fill"
        case "automotive": "steeringwheel"
        case "accessibility": "accessibility"
        case "privacyandsecurity": "lock"
        case "human": "person.crop.circle"
        case "home": "house"
        case "fitness": "figure.run"
        case "nature": "leaf"
        case "editing": "slider.horizontal.3"
        case "textformatting": "textformat"
        case "media": "playpause"
        case "keyboard": "command"
        case "commerce": "cart"
        case "time": "timer"
        case "health": "heart"
        case "shapes": "square.on.circle"
        case "arrows": "arrow.forward"
        case "indices": "a.circle"
        case "math": "x.squareroot"
        default: "square.grid.2x2"
        }
    }
}

/// 뱃지·업적 날짜 "2026. 10. 10."
enum ProgressDateFormat {
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.defaultDigits).day())
    }
}
