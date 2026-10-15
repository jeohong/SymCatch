//
//  EvaluationTargetPicker.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// 평가셋 수집 모드에서 다음에 그릴 심볼을 고른다(기획서 9.4: 대표 심볼 100개 × 2~3장).
public enum EvaluationTargetPicker {
    /// 사람마다 심볼당 모을 그림 수
    public static let samplesPerTarget = 3

    /// 평가용 대표 심볼 100개. 자주 쓰고 모양이 뚜렷하며 iOS 17에서 그릴 수 있는 심볼.
    /// 뱃지 제외 기준을 정하기 위해 단순한 도형(circle, minus, checkmark 등)도 일부러 넣었다.
    public static let representativeSymbols: [String] = [
        // 도형·기호
        "circle", "square", "triangle", "diamond", "hexagon", "plus", "minus", "checkmark", "xmark", "star",
        "heart", "bolt", "drop", "flame", "leaf", "moon", "sun.max", "cloud", "cloud.rain", "snowflake",
        // 화살표·재생
        "arrow.up", "arrow.down", "arrow.left", "arrow.right", "arrow.clockwise", "play", "pause", "forward", "music.note", "link",
        // 사물
        "house", "bell", "gearshape", "trash", "folder", "paperplane", "bookmark", "tag", "camera", "phone",
        "envelope", "lock", "key", "flag", "map", "pencil", "scissors", "cart", "gift", "globe",
        "umbrella", "cup.and.saucer", "fork.knife", "magnifyingglass", "headphones", "mic", "speaker.wave.2", "lightbulb", "tv", "iphone",
        "gamecontroller", "puzzlepiece", "crown", "trophy", "medal", "graduationcap", "briefcase", "bag", "creditcard", "paperclip",
        "pin", "mappin", "location", "wifi", "hourglass", "alarm", "clock", "calendar", "book", "doc",
        // 사람·소통
        "person", "person.2", "hand.thumbsup", "hand.raised", "eye", "face.smiling", "message", "bubble.left", "chart.bar", "tornado",
        // 탈것·동물
        "car", "bicycle", "airplane", "bus", "tram", "hare", "tortoise", "fish", "pawprint", "ant",
    ]

    /// 그린 수가 가장 적은 심볼을 고른다. 같으면 목록 순서. 모두 목표에 닿았으면 nil.
    /// - Parameters:
    ///   - counts: 심볼 이름별로 이 사람이 이미 그린 수
    ///   - excluding: 방금 건너뛴 심볼처럼 이번에는 고르지 않을 이름
    public static func next(
        from targets: [String] = representativeSymbols,
        counts: [String: Int],
        excluding: Set<String> = [],
        goal: Int = samplesPerTarget
    ) -> String? {
        let remaining = targets.filter { (counts[$0] ?? 0) < goal }
        let candidates = remaining.filter { !excluding.contains($0) }
        let pool = candidates.isEmpty ? remaining : candidates
        return pool.min { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
    }
}
