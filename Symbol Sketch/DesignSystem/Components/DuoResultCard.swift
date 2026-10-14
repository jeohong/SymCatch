//
//  DuoResultCard.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import SwiftUI
import Domain

/// Duo 반쯤 접힘 결과 카드(DESIGN_NOTES 3.8). 5열×2행 격자에서 영역 높이를 채운다.
/// 1행: 글리프 | (뱃지 가능 골드 점) 순위 / 2행: 이름 / 3행: 유사도 + 막대.
struct DuoResultCard: View {
    let rank: Int
    let match: SymbolMatch
    let badgeHint: BadgeHint

    @ScaledMetric(relativeTo: .title) private var glyphSize = Metrics.rowGlyph

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top) {
                Image(systemName: match.name)
                    .font(.system(size: glyphSize))
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(height: glyphSize)
                Spacer(minLength: 0)
                if badgeHint.isEligible {
                    Circle().fill(DSColor.gold).frame(width: 8, height: 8)
                }
                Text("\(rank)")
                    .font(DSFont.rankSmall)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer(minLength: 0)
            Text(match.name)
                .font(DSFont.symbolNameSmall)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: Spacing.s) {
                Text("\(match.similarity)%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(DSColor.textPrimary)
                    .fixedSize()
                SimilarityBar(percent: match.similarity)
            }
        }
        .padding(.vertical, Spacing.s + 1)
        .padding(.horizontal, Spacing.s + Spacing.xxs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.toolGroup))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.toolGroup)
                .strokeBorder(match.similarity >= BadgeTierPolicy.threshold ? DSColor.gold : .clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.toolGroup))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(match.name), 유사도 \(match.similarity)퍼센트") + badgeHint.accessibilitySuffix)
        .accessibilityAddTraits(.isButton)
    }
}

private func duoResultCardPreview() -> some View {
    HStack(spacing: Spacing.s) {
        DuoResultCard(rank: 1, match: SymbolMatch(name: "heart.fill", variants: [], similarity: 96), badgeHint: .eligible(.gold))
        DuoResultCard(rank: 2, match: SymbolMatch(name: "bubble.left.fill", variants: [], similarity: 82), badgeHint: .none)
    }
    .frame(height: 110)
    .padding()
    .background(DSColor.bgPrimary)
}

#Preview("라이트") { duoResultCardPreview().preferredColorScheme(.light) }
#Preview("다크") { duoResultCardPreview().preferredColorScheme(.dark) }
