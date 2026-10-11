//
//  BadgeDetailScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 뱃지 상세(S7)
struct BadgeDetailScreen: View {
    @State var viewModel: BadgeDetailViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                header
                if let badge = viewModel.badge {
                    info(badge)
                    pastSketch(badge)
                }
                actions
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xxl)
            .frame(maxWidth: .infinity)
        }
        .background(DSColor.bgGrouped)
        .navigationTitle(viewModel.symbolName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var header: some View {
        VStack(spacing: Spacing.m) {
            BadgeView(systemImage: viewModel.symbolName, style: viewModel.badge.map { .tier($0.tier) } ?? .locked, size: 136, ringWidth: 7)
                .shadow(color: .black.opacity(0.14), radius: 16, y: 12)
            if let badge = viewModel.badge {
                TierChip(text: String(localized: "\(badge.tier.displayName) 뱃지"), background: DSColor.tier(badge.tier))
            } else {
                Text("미획득")
                    .font(DSFont.chip)
                    .foregroundStyle(DSColor.textSecondary)
                    .padding(.horizontal, Spacing.s + 1)
                    .padding(.vertical, Spacing.xxs + 1)
                    .background(DSColor.fill, in: RoundedRectangle(cornerRadius: Radius.chip))
            }
            Text(viewModel.symbolName)
                .font(DSFont.symbolNameLarge)
                .foregroundStyle(DSColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(viewModel.goalText)
                .font(.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private func info(_ badge: SymbolBadge) -> some View {
        VStack(spacing: 0) {
            row("획득일", value: ProgressDateFormat.day(badge.earnedAt))
            Divider().overlay(DSColor.separator)
            row("등급", value: badge.tier.displayName)
            Divider().overlay(DSColor.separator)
            row("최고 유사도", value: "\(badge.bestSimilarity)%", emphasized: true)
            Divider().overlay(DSColor.separator)
            row("최근 승급", value: badge.upgradedAt.map(ProgressDateFormat.day) ?? String(localized: "없음"))
        }
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func row(_ title: LocalizedStringKey, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(title).foregroundStyle(DSColor.textPrimary)
            Spacer()
            Text(value)
                .fontWeight(emphasized ? .semibold : .regular)
                .foregroundStyle(emphasized ? DSColor.textPrimary : DSColor.textSecondary)
        }
        .font(.body)
        .padding(.horizontal, Spacing.l)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }

    private func pastSketch(_ badge: SymbolBadge) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("당시 그림")
                .font(DSFont.sectionHeader)
                .foregroundStyle(DSColor.textSecondary)
                .padding(.horizontal, Spacing.xs)
            HStack(spacing: Spacing.s + Spacing.xxs) {
                tile {
                    SketchShape(sketch: badge.bestSketch)
                        .stroke(DSColor.canvasInk, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                tile {
                    GeometryReader { proxy in
                        Image(systemName: badge.symbolName)
                            .font(.system(size: proxy.size.width * 0.5))
                            .foregroundStyle(DSColor.textPrimary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("당시 그림과 \(badge.symbolName) 비교"))
        }
        .padding(.top, Spacing.xs)
    }

    private func tile(@ViewBuilder content: () -> some View) -> some View {
        content()
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(DSColor.canvasBackground, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(DSColor.separator, lineWidth: 1))
    }

    private var actions: some View {
        VStack(spacing: Spacing.s + Spacing.xxs) {
            if viewModel.canChallenge {
                Button { viewModel.challenge() } label: {
                    Label(viewModel.challengeTitle, systemImage: "scribble.variable")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            Button { viewModel.showSymbolDetail() } label: {
                Label("심볼 상세 보기", systemImage: "info.circle")
                    .font(.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: Metrics.largeButtonHeight)
                    .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.button))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, Spacing.s)
    }
}

private struct PreviewBadges: FetchBadgesUseCase {
    var badge: SymbolBadge?
    func execute() async throws -> [String: SymbolBadge] { badge.map { [$0.symbolName: $0] } ?? [:] }
}

private let previewBadge = SymbolBadge(
    symbolName: "heart", tier: .silver, bestSimilarity: 96,
    bestSketch: Sketch(strokes: [[SketchPoint(x: 0.2, y: 0.3), SketchPoint(x: 0.5, y: 0.8), SketchPoint(x: 0.8, y: 0.3)]]),
    earnedAt: .now
)

#Preview("라이트") {
    NavigationStack { BadgeDetailScreen(viewModel: BadgeDetailViewModel(symbolName: "heart", fetchBadges: PreviewBadges(badge: previewBadge), navigator: nil)) }
        .preferredColorScheme(.light)
}

#Preview("다크") {
    NavigationStack { BadgeDetailScreen(viewModel: BadgeDetailViewModel(symbolName: "heart", fetchBadges: PreviewBadges(badge: previewBadge), navigator: nil)) }
        .preferredColorScheme(.dark)
}

#Preview("미획득") {
    NavigationStack { BadgeDetailScreen(viewModel: BadgeDetailViewModel(symbolName: "cloud", fetchBadges: PreviewBadges(), navigator: nil)) }
}
