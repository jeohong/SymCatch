//
//  ScreenshotDemo.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/16/26.
//

#if DEBUG
import Foundation
import Domain

/// App Store 스크린샷용 데모 모드(실행 인자 `-ScreenshotDemo`). DEBUG 빌드에만 있다.
///
/// 시뮬레이터의 Vision은 특징 벡터가 거의 같아 검색 결과가 의미 없다(CLAUDE.md 2.3).
/// 그래서 실기기에서 하트를 그렸을 때와 같은 결과를 돌려주고, 캔버스에 손그림 하트를 미리 그려 둔다.
/// 기록은 메모리에만 두고 최근 기록·뱃지·연속 출석을 채워 넣는다.
enum ScreenshotDemo {
    static let argument = "-ScreenshotDemo"

    static var isOn: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    /// 캔버스에 미리 그려 둘 손그림 하트
    static let heartSketch = DemoShapes.heart

    /// 하트를 그렸을 때 실기기에서 나오는 결과와 비슷한 Top 10
    nonisolated static let heartResults: [SymbolMatch] = [
        SymbolMatch(name: "heart", variants: ["heart.fill"], similarity: 96),
        SymbolMatch(name: "suit.heart", variants: ["suit.heart.fill"], similarity: 91),
        SymbolMatch(name: "heart.circle", variants: ["heart.circle.fill"], similarity: 83),
        SymbolMatch(name: "heart.square", variants: ["heart.square.fill"], similarity: 78),
        SymbolMatch(name: "heart.rectangle", variants: ["heart.rectangle.fill"], similarity: 72),
        SymbolMatch(name: "heart.text.square", variants: ["heart.text.square.fill"], similarity: 68),
        SymbolMatch(name: "bubble.left", variants: ["bubble.left.fill"], similarity: 61),
        SymbolMatch(name: "drop", variants: ["drop.fill"], similarity: 57),
        SymbolMatch(name: "shield", variants: ["shield.fill"], similarity: 54),
        SymbolMatch(name: "seal", variants: ["seal.fill"], similarity: 50),
    ]

    /// 준비가 바로 끝난 것처럼 답한다(시뮬레이터에서 인덱스를 만드는 시간을 건너뛴다).
    nonisolated struct Prepare: PrepareSymbolIndexUseCase {
        func status() async -> SymbolIndexStatus { .ready(symbolCount: 8092) }

        func execute() -> AsyncThrowingStream<Double, Error> {
            AsyncThrowingStream { continuation in
                continuation.yield(1)
                continuation.finish()
            }
        }
    }

    /// 그림과 관계없이 하트 결과를 돌려준다.
    nonisolated struct Search: SearchSymbolsUseCase {
        func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome {
            sketch.isEmpty ? .empty : .results(Array(ScreenshotDemo.heartResults.prefix(limit)))
        }
    }

    /// 최근 기록·뱃지·통계를 채운다. 업적은 앱 시작 때 뱃지·통계로 다시 계산된다.
    static func seed(records: any FoundRecordRepository, badges: any BadgeRepository, stats: any UserStatsRepository,
                     now: Date = .now) async {
        let recent: [(String, Int, Sketch)] = [
            ("star", 97, DemoShapes.star),
            ("bolt", 95, DemoShapes.bolt),
            ("moon", 92, DemoShapes.moon),
            ("house", 90, DemoShapes.house),
            ("cloud", 88, DemoShapes.cloud),
            ("envelope", 93, DemoShapes.envelope),
            ("arrow.right", 100, DemoShapes.arrowRight),
            ("sun.max", 86, DemoShapes.sun),
        ]
        for (offset, item) in recent.enumerated() {
            let date = now.addingTimeInterval(-Double(offset + 1) * 3_600 * 5)
            try? await records.save(FoundRecord(symbolName: item.0, sketch: item.2, similarity: item.1, foundAt: date))
            try? await badges.save(badge(item.0, item.1, item.2, date))
        }

        // 콜렉션을 채우는 나머지 뱃지(등급을 고루 섞는다)
        let more: [(String, Int)] = [
            ("leaf", 96), ("flame", 91), ("drop", 87), ("bell", 94), ("cart", 89), ("gift", 98), ("camera", 90),
            ("music.note", 95), ("paperplane", 93), ("lock", 86), ("key", 92), ("magnifyingglass", 100), ("pencil", 88),
            ("trash", 97), ("bookmark", 91), ("flag", 99), ("tag", 85), ("globe", 90), ("airplane", 94), ("car", 87),
            ("umbrella", 96), ("snowflake", 92), ("pawprint", 89), ("fish", 95), ("crown", 100), ("trophy", 93),
            ("gamecontroller", 86), ("headphones", 91), ("lightbulb", 98), ("sparkles", 90), ("tortoise", 88),
            ("hare", 94), ("bird", 87), ("bicycle", 85), ("balloon", 97), ("birthday.cake", 92),
        ]
        for (offset, item) in more.enumerated() {
            let date = now.addingTimeInterval(-Double(offset + 9) * 3_600 * 9)
            try? await badges.save(badge(item.0, item.1, DemoShapes.star, date))
        }

        try? await stats.save(UserStats(totalSelections: 86, streakDays: 12, lastActiveDay: now))
    }

    private static func badge(_ name: String, _ similarity: Int, _ sketch: Sketch, _ date: Date) -> SymbolBadge {
        SymbolBadge(symbolName: name, tier: BadgeTierPolicy.tier(for: similarity) ?? .bronze, bestSimilarity: similarity,
                    bestSketch: sketch, earnedAt: date)
    }
}

/// 손으로 그린 것처럼 조금씩 흔들리는 도형(정규화 좌표 0...1, 캔버스 한 변 기준)
private enum DemoShapes {
    static let heart: Sketch = {
        let points = (0...120).map { step -> SketchPoint in
            let t = Double(step) / 120 * 2 * .pi
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            return SketchPoint(x: 0.5 + x / 38, y: 0.47 - y / 38)
        }
        return Sketch(strokes: [wobble(points, seed: 1)])
    }()

    static let star: Sketch = {
        let points = (0...10).map { index -> SketchPoint in
            let angle = -Double.pi / 2 + Double(index) * .pi / 5
            let radius = index.isMultiple(of: 2) ? 0.34 : 0.14
            return SketchPoint(x: 0.5 + radius * cos(angle), y: 0.52 + radius * sin(angle))
        }
        return Sketch(strokes: [wobble(densify(points), seed: 2)])
    }()

    static let bolt = Sketch(strokes: [wobble(densify([
        SketchPoint(x: 0.58, y: 0.14), SketchPoint(x: 0.32, y: 0.54), SketchPoint(x: 0.5, y: 0.54),
        SketchPoint(x: 0.42, y: 0.86), SketchPoint(x: 0.7, y: 0.42), SketchPoint(x: 0.52, y: 0.42),
        SketchPoint(x: 0.58, y: 0.14),
    ]), seed: 3)])

    /// 초승달: 바깥 호(왼쪽으로 불룩) → 안쪽 호로 돌아오는 한 획
    static let moon: Sketch = {
        let outer = (0...40).map { step -> SketchPoint in
            let angle = (60 + Double(step) / 40 * 240) * .pi / 180
            return SketchPoint(x: 0.5 + 0.32 * cos(angle), y: 0.5 + 0.32 * sin(angle))
        }
        let start = atan2(-0.277, -0.12), end = atan2(0.277, -0.12)
        let inner = (0...30).map { step -> SketchPoint in
            let angle = start - Double(step) / 30 * (2 * .pi - (end - start))
            return SketchPoint(x: 0.78 + 0.302 * cos(angle), y: 0.5 + 0.302 * sin(angle))
        }
        return Sketch(strokes: [wobble(outer + inner, seed: 4)])
    }()

    static let house = Sketch(strokes: [
        wobble(densify([
            SketchPoint(x: 0.18, y: 0.5), SketchPoint(x: 0.5, y: 0.2), SketchPoint(x: 0.82, y: 0.5),
        ]), seed: 6),
        wobble(densify([
            SketchPoint(x: 0.28, y: 0.42), SketchPoint(x: 0.28, y: 0.82), SketchPoint(x: 0.72, y: 0.82),
            SketchPoint(x: 0.72, y: 0.42),
        ]), seed: 7),
        wobble(densify([
            SketchPoint(x: 0.44, y: 0.82), SketchPoint(x: 0.44, y: 0.62), SketchPoint(x: 0.56, y: 0.62),
            SketchPoint(x: 0.56, y: 0.82),
        ]), seed: 8),
    ])

    static let cloud: Sketch = {
        var points: [SketchPoint] = []
        let bumps: [(Double, Double, Double)] = [(0.3, 0.6, 0.12), (0.45, 0.45, 0.16), (0.63, 0.5, 0.13), (0.74, 0.62, 0.09)]
        for (cx, cy, r) in bumps {
            points += (0...14).map { step in
                let angle = .pi + Double(step) / 14 * .pi
                return SketchPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            }
        }
        points += densify([SketchPoint(x: 0.83, y: 0.7), SketchPoint(x: 0.2, y: 0.7), SketchPoint(x: 0.18, y: 0.6)])
        return Sketch(strokes: [wobble(points, seed: 9)])
    }()

    static let envelope = Sketch(strokes: [
        wobble(densify([
            SketchPoint(x: 0.18, y: 0.3), SketchPoint(x: 0.82, y: 0.3), SketchPoint(x: 0.82, y: 0.72),
            SketchPoint(x: 0.18, y: 0.72), SketchPoint(x: 0.18, y: 0.3),
        ]), seed: 10),
        wobble(densify([SketchPoint(x: 0.19, y: 0.32), SketchPoint(x: 0.5, y: 0.55), SketchPoint(x: 0.81, y: 0.32)]), seed: 11),
    ])

    static let arrowRight = Sketch(strokes: [
        wobble(densify([SketchPoint(x: 0.18, y: 0.5), SketchPoint(x: 0.8, y: 0.5)]), seed: 12),
        wobble(densify([SketchPoint(x: 0.58, y: 0.28), SketchPoint(x: 0.8, y: 0.5), SketchPoint(x: 0.58, y: 0.72)]), seed: 13),
    ])

    static let sun: Sketch = {
        let ring = (0...40).map { step -> SketchPoint in
            let angle = Double(step) / 40 * 2 * .pi
            return SketchPoint(x: 0.5 + 0.16 * cos(angle), y: 0.5 + 0.16 * sin(angle))
        }
        let rays = (0..<8).map { index -> [SketchPoint] in
            let angle = Double(index) * .pi / 4
            return densify([
                SketchPoint(x: 0.5 + 0.24 * cos(angle), y: 0.5 + 0.24 * sin(angle)),
                SketchPoint(x: 0.5 + 0.34 * cos(angle), y: 0.5 + 0.34 * sin(angle)),
            ])
        }
        return Sketch(strokes: [wobble(ring, seed: 14)] + rays.enumerated().map { wobble($1, seed: 15 + $0) })
    }()

    /// 꼭짓점 사이를 촘촘히 채운다(손으로 그린 선처럼 점이 많게).
    private static func densify(_ corners: [SketchPoint]) -> [SketchPoint] {
        guard let first = corners.first else { return [] }
        var points = [first]
        for (a, b) in zip(corners, corners.dropFirst()) {
            let steps = max(2, Int(hypot(b.x - a.x, b.y - a.y) / 0.01))
            points += (1...steps).map { step in
                let t = Double(step) / Double(steps)
                return SketchPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
        }
        return points
    }

    /// 느리게 흔들리는 작은 오차를 더한다(손떨림처럼).
    private static func wobble(_ points: [SketchPoint], seed: Int) -> [SketchPoint] {
        let phase = Double(seed) * 1.7
        return points.enumerated().map { index, point in
            let t = Double(index) / Double(max(points.count - 1, 1))
            let dx = 0.006 * sin(t * 9 + phase) + 0.003 * sin(t * 23 + phase * 2)
            let dy = 0.006 * cos(t * 7 + phase) + 0.003 * cos(t * 19 + phase * 3)
            return SketchPoint(x: point.x + dx, y: point.y + dy)
        }
    }
}
#endif
