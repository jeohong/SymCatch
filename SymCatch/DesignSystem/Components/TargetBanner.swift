//
//  TargetBanner.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 도전 모드 목표 카드(DESIGN_NOTES 3.4). 최근 스트립 자리에 반전색으로 표시한다.
struct TargetBanner: View {
    let symbolName: String
    /// 이미 받은 뱃지(없으면 미보유)
    let badge: SymbolBadge?
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 34

    var body: some View {
        HStack(spacing: Spacing.s + Spacing.xxs) {
            Image(systemName: symbolName)
                .font(.system(size: glyphSize))
                .foregroundStyle(DSColor.textPrimary)
                .frame(width: tileSize, height: tileSize)
                .background(DSColor.bgPrimary, in: RoundedRectangle(cornerRadius: Radius.chip + 3))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("목표 · \(symbolName)")
                    .font(DSFont.symbolNameSmall)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption)
                    .opacity(0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(DSColor.bgPrimary)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DSColor.bgPrimary)
                    .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
            }
            .accessibilityLabel("목표 해제")
        }
        .padding(.leading, Spacing.s)
        .padding(.trailing, Spacing.xs + Spacing.xxs)
        .frame(minHeight: Metrics.minTapTarget + Spacing.xs)
        .background(DSColor.textPrimary, in: RoundedRectangle(cornerRadius: Radius.button))
    }

    private var subtitle: String {
        guard let badge else { return String(localized: "아직 없는 뱃지 · \(BadgeTierPolicy.threshold.percentText) 이상으로 그려 보세요") }
        guard let next = badge.tier.next else { return String(localized: "현재 \(badge.tier.displayName) \(badge.bestSimilarity.percentText)") }
        return String(localized: "현재 \(badge.tier.displayName) \(badge.bestSimilarity.percentText) · \(next.displayName) \(next.minimumSimilarity.percentText)에 도전")
    }
}

private struct TargetBannerPreview: View {
    var body: some View {
        VStack(spacing: Spacing.m) {
            TargetBanner(symbolName: "heart", badge: nil) {}
            TargetBanner(symbolName: "star.fill",
                         badge: SymbolBadge(symbolName: "star.fill", tier: .bronze, bestSimilarity: 92, bestSketch: .empty, earnedAt: .now)) {}
        }
        .padding()
        .background(DSColor.bgPrimary)
    }
}

#Preview("라이트") { TargetBannerPreview().preferredColorScheme(.light) }
#Preview("다크") { TargetBannerPreview().preferredColorScheme(.dark) }
