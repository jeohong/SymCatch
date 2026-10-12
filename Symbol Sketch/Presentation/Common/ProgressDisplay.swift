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
        }
    }

    /// 달성 조건
    var condition: String {
        switch self {
        case .firstStroke: String(localized: "첫 검색 완료")
        case .sharpshooter: String(localized: "심볼 뱃지 1개 획득")
        case .collector10: String(localized: "심볼 뱃지 10개 획득")
        }
    }

    /// 메달 안 글리프(DESIGN_NOTES 5.1: draw · target · stacks)
    var systemImage: String {
        switch self {
        case .firstStroke: "pencil.and.scribble"
        case .sharpshooter: "target"
        case .collector10: "square.stack.3d.up"
        }
    }
}

/// 뱃지·업적 날짜 "2026. 10. 10."
enum ProgressDateFormat {
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.defaultDigits).day())
    }
}
