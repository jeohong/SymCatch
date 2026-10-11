//
//  ResultCard.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 접힌 결과 시트의 Top 3 카드(DESIGN_NOTES 3.6).
struct ResultCard: View {
    let rank: Int
    let match: SymbolMatch
    let badgeHint: BadgeHint

    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize = Metrics.cardGlyph

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s - Spacing.xxs) {
            HStack(alignment: .top) {
                Image(systemName: match.name)
                    .font(.system(size: glyphSize))
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(height: glyphSize)
                Spacer(minLength: 0)
                if badgeHint.isEligible {
                    Text("뱃지")
                        .font(DSFont.chip)
                        .foregroundStyle(DSColor.onBadge)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 1)
                        .background(DSColor.gold, in: RoundedRectangle(cornerRadius: Radius.chip))
                }
                Text("\(rank)")
                    .font(DSFont.rankSmall)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Text(match.name)
                .font(DSFont.symbolNameSmall)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("\(match.similarity)%")
                .font(DSFont.similarity)
                .foregroundStyle(DSColor.textPrimary)
            SimilarityBar(percent: match.similarity)
        }
        .padding(Spacing.s + Spacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.cellElevated, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(match.similarity >= 90 ? DSColor.gold : .clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(match.name), 유사도 \(match.similarity)퍼센트") + badgeHint.accessibilitySuffix)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("라이트") {
    HStack(spacing: Spacing.s) {
        ResultCard(rank: 1, match: SymbolMatch(name: "heart", variants: [], similarity: 94), badgeHint: .eligible(.bronze))
        ResultCard(rank: 2, match: SymbolMatch(name: "suit.heart", variants: [], similarity: 81), badgeHint: .none)
        ResultCard(rank: 3, match: SymbolMatch(name: "drop", variants: [], similarity: 61), badgeHint: .none)
    }
    .padding()
    .background(DSColor.bgSecondary)
    .preferredColorScheme(.light)
}

#Preview("다크") {
    HStack(spacing: Spacing.s) {
        ResultCard(rank: 1, match: SymbolMatch(name: "heart", variants: [], similarity: 94), badgeHint: .eligible(.bronze))
        ResultCard(rank: 2, match: SymbolMatch(name: "suit.heart", variants: [], similarity: 81), badgeHint: .none)
        ResultCard(rank: 3, match: SymbolMatch(name: "drop", variants: [], similarity: 61), badgeHint: .none)
    }
    .padding()
    .background(DSColor.bgSecondary)
    .preferredColorScheme(.dark)
}
