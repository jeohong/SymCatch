//
//  ConfettiView.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 뱃지 획득 컨페티(DESIGN_NOTES 2.8). 기획서대로 1.5초, 마지막 0.5초는 서서히 사라진다.
/// 동작 줄이기에서는 그리지 않는다(부르는 쪽에서 판단).
struct ConfettiView: View {
    static let duration: TimeInterval = 1.5
    private static let fadeDuration: TimeInterval = 0.5
    private static let frameRate: Double = 60

    private let particles: [Particle]
    @State private var startDate = Date.now

    init(count: Int = 110) {
        var generator = SystemRandomNumberGenerator()
        particles = (0..<count).map { _ in Particle.random(using: &generator) }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            Canvas { context, size in
                guard elapsed < Self.duration else { return }
                let frames = elapsed * Self.frameRate
                let fadeStart = Self.duration - Self.fadeDuration
                context.opacity = elapsed < fadeStart ? 1 : max(0, 1 - (elapsed - fadeStart) / Self.fadeDuration)
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.32)

                for particle in particles {
                    // 프레임당 속도·중력(디자인 프로토타입과 같은 단위)
                    let x = origin.x + particle.offsetX + particle.vx * frames
                    let y = origin.y + particle.vy * frames + 0.5 * 0.32 * frames * frames
                    var copy = context
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .degrees(particle.spin * frames))
                    let rect = CGRect(x: -particle.width / 2, y: -particle.width / 4, width: particle.width, height: particle.width / 2)
                    copy.fill(Path(rect), with: .color(particle.color.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Particle {
        enum Tint: CaseIterable {
            case accent, gold, bronze, silver, danger

            var color: Color {
                switch self {
                case .accent: DSColor.accent
                case .gold: DSColor.gold
                case .bronze: DSColor.bronze
                case .silver: DSColor.silver
                case .danger: DSColor.danger
                }
            }
        }

        let offsetX: CGFloat
        let vx: CGFloat
        let vy: CGFloat
        let width: CGFloat
        let spin: Double
        let color: Tint

        static func random(using generator: inout some RandomNumberGenerator) -> Particle {
            Particle(
                offsetX: .random(in: -30...30, using: &generator),
                vx: .random(in: -4.5...4.5, using: &generator),
                vy: .random(in: -13 ... -3, using: &generator),
                width: .random(in: 3...9, using: &generator),
                spin: .random(in: -12...12, using: &generator),
                color: Tint.allCases.randomElement(using: &generator) ?? .accent
            )
        }
    }
}

#Preview("라이트") { ConfettiView().background(DSColor.bgPrimary).preferredColorScheme(.light) }
#Preview("다크") { ConfettiView().background(DSColor.bgPrimary).preferredColorScheme(.dark) }
