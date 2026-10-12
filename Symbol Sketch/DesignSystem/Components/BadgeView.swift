//
//  BadgeView.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 메달: 등급색 링 + 안쪽 원 + 심볼 글리프(DESIGN_NOTES 3.10).
/// 크기·링 두께: 격자 56/3, 업적 48/3, S4 104/6, S7 136/7.
struct BadgeView: View {
    enum Style: Equatable {
        case tier(BadgeTier)
        /// 달성한 업적(accent 링)
        case achievement
        /// 미획득(단색 링, 흐린 글리프)
        case locked
    }

    let systemImage: String
    let style: Style
    var size: CGFloat = 56
    var ringWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle().fill(ring)
            Circle()
                .fill(DSColor.cell)
                .padding(ringWidth)
            Image(systemName: systemImage)
                .symbolVariant(.fill)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(style == .locked ? DSColor.lock : DSColor.textPrimary)
                .frame(width: size * 0.66, height: size * 0.66)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var ring: AnyShapeStyle {
        switch style {
        case .tier(let tier):
            AnyShapeStyle(DSColor.tierRing(tier))
        case .achievement:
            AnyShapeStyle(Self.gradient(DSColor.accent, DSColor.accentHi))
        case .locked:
            AnyShapeStyle(DSColor.bgTertiary)
        }
    }

    /// CSS `conic-gradient(from 210deg, base, hi, base, hi, base)`. SwiftUI 각도는 3시 기준이라 −90°.
    private static func gradient(_ base: Color, _ highlight: Color) -> AngularGradient {
        AngularGradient(colors: [base, highlight, base, highlight, base], center: .center,
                        startAngle: .degrees(120), endAngle: .degrees(480))
    }
}

/// 등급 점: 단색 링(DESIGN_NOTES 3.10 "등급 점 18·14·12·10")
struct BadgeDot: View {
    let tier: BadgeTier
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .strokeBorder(DSColor.tierRing(tier), lineWidth: max(2, size * 0.22))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// 등급 칩: 등급색 바탕 + 검정 글자(gold는 글자색으로 쓰지 않는다)
struct TierChip: View {
    let text: String
    let background: AnyShapeStyle

    init(text: String, background: some ShapeStyle) {
        self.text = text
        self.background = AnyShapeStyle(background)
    }

    var body: some View {
        Text(text)
            .font(DSFont.chip)
            .foregroundStyle(DSColor.onBadge)
            .padding(.horizontal, Spacing.s + 1)
            .padding(.vertical, Spacing.xxs + 1)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.chip))
    }
}

private struct BadgeViewPreview: View {
    var body: some View {
        VStack(spacing: Spacing.l) {
            HStack(spacing: Spacing.m) {
                BadgeView(systemImage: "heart", style: .tier(.bronze))
                BadgeView(systemImage: "star", style: .tier(.silver))
                BadgeView(systemImage: "bolt", style: .tier(.gold))
                BadgeView(systemImage: "crown", style: .tier(.legendary))
                BadgeView(systemImage: "cloud", style: .locked)
            }
            HStack(spacing: Spacing.m) {
                BadgeView(systemImage: "target", style: .achievement, size: 104, ringWidth: 6)
                BadgeDot(tier: .legendary, size: 18)
                TierChip(text: "레전더리 뱃지", background: DSColor.tierFill(.legendary))
            }
        }
        .padding()
        .background(DSColor.bgGrouped)
    }
}

#Preview("라이트") { BadgeViewPreview().preferredColorScheme(.light) }
#Preview("다크") { BadgeViewPreview().preferredColorScheme(.dark) }
