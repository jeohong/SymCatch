//
//  SymbolResultRow.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 검색 결과 한 줄: 순위 · 심볼 · 이름 · 유사도(DESIGN_NOTES 3.7).
/// 가장 큰 글자 크기에서는 세로로 배치를 바꾼다(기획서 6장 접근성).
struct SymbolResultRow: View {
    let rank: Int
    let match: SymbolMatch
    /// 뱃지 안내(획득 가능 · 보유 중 · 단순 심볼 제외)
    let badgeHint: BadgeHint

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var glyphSize = Metrics.rowGlyph
    @ScaledMetric(relativeTo: .title) private var tileSize = Metrics.rowTile

    var body: some View {
        content
            .padding(.vertical, Spacing.s + Spacing.xxs)
            .padding(.leading, Spacing.s)
            .padding(.trailing, Spacing.m)
            .background(DSColor.cellElevated, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(match.similarity >= 90 ? DSColor.gold : .clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.card))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.m) {
                    rankText
                    tile
                }
                nameAndLabels
                similarity
            }
        } else {
            HStack(spacing: Spacing.m) {
                rankText.frame(minWidth: 20)
                tile
                nameAndLabels
                Spacer(minLength: 0)
                similarity.frame(minWidth: 68, alignment: .trailing)
            }
        }
    }

    private var rankText: some View {
        Text("\(rank)")
            .font(DSFont.rank)
            .foregroundStyle(DSColor.textSecondary)
    }

    private var tile: some View {
        Image(systemName: match.name)
            .font(.system(size: glyphSize))
            .foregroundStyle(DSColor.textPrimary)
            .frame(width: tileSize, height: tileSize)
            .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.tile))
    }

    private var nameAndLabels: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(match.name)
                .font(DSFont.symbolName)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .truncationMode(.middle)
            HStack(spacing: Spacing.s - Spacing.xxs) {
                BadgeHintLabel(hint: badgeHint)
                if !match.variants.isEmpty {
                    Text("변형 \(match.variants.count)개")
                        .font(.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }

    private var similarity: some View {
        VStack(alignment: .trailing, spacing: Spacing.s - Spacing.xxs) {
            Text("\(match.similarity)%")
                .font(DSFont.similarity)
                .foregroundStyle(DSColor.textPrimary)
            SimilarityBar(percent: match.similarity)
                .frame(width: Metrics.barWidth)
        }
    }

    private var accessibilityText: String {
        var text = String(localized: "\(match.name), 유사도 \(match.similarity)퍼센트")
        text += badgeHint.accessibilitySuffix
        return text
    }
}

/// 결과 행의 뱃지 안내: "뱃지 획득 가능" 칩 · "보유 중 · {등급}" · "단순 심볼 · 뱃지 제외"
struct BadgeHintLabel: View {
    let hint: BadgeHint

    var body: some View {
        switch hint {
        case .eligible:
            Text("뱃지 획득 가능")
                .font(DSFont.chip)
                .foregroundStyle(DSColor.onBadge)
                .padding(.horizontal, Spacing.s - 1)
                .padding(.vertical, Spacing.xxs)
                .background(DSColor.gold, in: RoundedRectangle(cornerRadius: Radius.chip))
        case .owned(let tier):
            HStack(spacing: Spacing.xs) {
                BadgeDot(tier: tier, size: 10)
                Text("보유 중 · \(tier.displayName)")
            }
            .font(.caption)
            .foregroundStyle(DSColor.textSecondary)
        case .excluded:
            Text("단순 심볼 · 뱃지 제외")
                .font(.caption)
                .foregroundStyle(DSColor.textSecondary)
        case .none:
            EmptyView()
        }
    }
}

extension BadgeHint {
    /// VoiceOver 뒤에 붙일 말(기획서 6장: "heart.fill, 유사도 92퍼센트, 뱃지 획득 가능")
    var accessibilitySuffix: String {
        switch self {
        case .eligible: String(localized: ", 뱃지 획득 가능")
        case .owned: String(localized: ", 보유 중")
        case .excluded, .none: ""
        }
    }
}

private let previewMatches = [
    SymbolMatch(name: "heart", variants: ["heart.fill", "heart.circle"], similarity: 94),
    SymbolMatch(name: "suit.heart", variants: [], similarity: 81),
    SymbolMatch(name: "rectangle.and.hand.point.up.left.filled", variants: [], similarity: 42),
]

#Preview("라이트") {
    VStack(spacing: Spacing.s) {
        ForEach(Array(previewMatches.enumerated()), id: \.offset) { index, match in
            SymbolResultRow(rank: index + 1, match: match, badgeHint: BadgeHint.evaluate(match, owned: nil))
        }
    }
    .padding()
    .background(DSColor.bgSecondary)
    .preferredColorScheme(.light)
}

#Preview("다크") {
    VStack(spacing: Spacing.s) {
        ForEach(Array(previewMatches.enumerated()), id: \.offset) { index, match in
            SymbolResultRow(rank: index + 1, match: match, badgeHint: BadgeHint.evaluate(match, owned: nil))
        }
    }
    .padding()
    .background(DSColor.bgSecondary)
    .preferredColorScheme(.dark)
}
