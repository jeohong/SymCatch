//
//  BadgeCard.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 뱃지 카드 한 장에 담을 내용. 축하 모달(S4)과 공유 이미지가 같은 값을 쓴다.
enum BadgeCardContent: Hashable {
    case badge(symbolName: String, tier: BadgeTier, isUpgrade: Bool, similarity: Int, sketch: Sketch, date: Date)
    case achievement(AchievementID, unlockedAt: Date)
}

/// 뱃지 카드 본문(DESIGN_NOTES 3.11): 메달 · 칩 · 제목 · 이름 · 비교 · 유사도.
/// 버튼과 "1 / 2" 표시는 담지 않는다(공유 이미지에도 그대로 쓰기 위해).
struct BadgeCard: View {
    let content: BadgeCardContent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: Spacing.m) {
            switch content {
            case let .badge(symbolName, tier, isUpgrade, similarity, sketch, date):
                BadgeView(systemImage: symbolName, style: .tier(tier), size: 104, ringWidth: 6)
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
                TierChip(text: isUpgrade ? String(localized: "승급") : String(localized: "새 뱃지"), background: DSColor.tierFill(tier))
                Text(isUpgrade ? "\(tier.displayName)로 승급했어요" : "\(tier.displayName) 뱃지를 얻었어요")
                    .font(.title2.bold())
                    .foregroundStyle(DSColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(symbolName)
                    .font(DSFont.symbolName)
                    .foregroundStyle(DSColor.textSecondary)
                    .padding(.top, -Spacing.s + Spacing.xxs)
                comparison(symbolName: symbolName, sketch: sketch)
                // 큰 글자에서는 유사도와 등급·날짜를 두 줄로 나눈다.
                let isLargeText = dynamicTypeSize.isAccessibilitySize
                let layout = isLargeText
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                layout {
                    HStack(alignment: .firstTextBaseline) {
                        Text("유사도").font(.subheadline).foregroundStyle(DSColor.textSecondary)
                        Text("\(similarity)%").font(DSFont.similarity).foregroundStyle(DSColor.textPrimary)
                    }
                    if !isLargeText { Spacer(minLength: Spacing.s) }
                    Text("\(tier.displayName) · \(ProgressDateFormat.day(date))")
                        .font(.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

            case let .achievement(id, unlockedAt):
                BadgeView(systemImage: id.systemImage, style: .achievement, size: 104, ringWidth: 6)
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
                TierChip(text: String(localized: "업적 달성"), background: DSColor.accent)
                Text(id.displayName)
                    .font(.title2.bold())
                    .foregroundStyle(DSColor.textPrimary)
                Text(id.condition)
                    .font(.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                Text(ProgressDateFormat.day(unlockedAt))
                    .font(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func comparison(symbolName: String, sketch: Sketch) -> some View {
        HStack(spacing: Spacing.s + Spacing.xxs) {
            tile(caption: "내 그림") {
                SketchShape(sketch: sketch)
                    .stroke(DSColor.canvasInk, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            tile(caption: "심볼") {
                GeometryReader { proxy in
                    Image(systemName: symbolName)
                        .font(.system(size: proxy.size.width * 0.55))
                        .foregroundStyle(DSColor.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func tile(caption: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: Spacing.xs + Spacing.xxs) {
            content()
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(DSColor.canvasBackground, in: RoundedRectangle(cornerRadius: Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(DSColor.separator, lineWidth: 1))
            Text(caption).font(.caption).foregroundStyle(DSColor.textSecondary)
        }
    }
}

private let previewSketch = Sketch(strokes: [
    (0...24).map { step in
        let t = Double(step) / 24 * 2 * .pi
        return SketchPoint(x: 0.5 + 0.3 * pow(sin(t), 3), y: 0.45 - 0.25 * (13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) / 16)
    },
])

private struct BadgeCardPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                BadgeCard(content: .badge(symbolName: "heart", tier: .silver, isUpgrade: false, similarity: 96, sketch: previewSketch, date: .now))
                BadgeCard(content: .achievement(.sharpshooter, unlockedAt: .now))
            }
            .padding(Spacing.xl)
            .background(DSColor.cell, in: RoundedRectangle(cornerRadius: 28))
            .padding()
        }
        .background(DSColor.bgGrouped)
    }
}

#Preview("라이트") { BadgeCardPreview().preferredColorScheme(.light) }
#Preview("다크") { BadgeCardPreview().preferredColorScheme(.dark) }
