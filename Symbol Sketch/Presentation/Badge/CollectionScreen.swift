//
//  CollectionScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 콜렉션(S6). iPad·Duo 분할 화면은 M4.5에서 `NavigationSplitView`로 바꾼다.
struct CollectionScreen: View {
    @Bindable var viewModel: CollectionViewModel

    var body: some View {
        content
            .background(DSColor.bgGrouped)
            .navigationTitle("콜렉션")
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            EmptyStateView(systemImage: "exclamationmark.triangle", message: String(localized: "콜렉션을 읽지 못했어요"),
                           actionTitle: String(localized: "다시 시도")) {
                Task { await viewModel.load() }
            }
            .frame(maxHeight: .infinity)
        case .loaded(let summary):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    Text("길게 눌러 이름 보기")
                        .font(.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                        .padding(.horizontal, Spacing.screen)
                        .padding(.bottom, -Spacing.m)
                    SummaryCard(summary: summary, progress: viewModel.progress)
                        .padding(.horizontal, Spacing.screen)
                    if summary.badges.isEmpty {
                        emptyHint
                    }
                    achievements(summary.achievements)
                    ForEach(summary.categories, id: \.category.key) { category in
                        CategorySection(category: category, viewModel: viewModel)
                    }
                }
                .padding(.vertical, Spacing.m)
            }
        }
    }

    /// 뱃지가 하나도 없을 때(DESIGN_NOTES 7.2 권장: 안내 1줄 + 그리러 가기)
    private var emptyHint: some View {
        VStack(spacing: Spacing.m) {
            Text("유사도 \(BadgeTierPolicy.threshold)% 이상인 심볼을 고르면 뱃지를 얻어요")
                .font(.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("그리러 가기") { viewModel.goDraw() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screen)
    }

    private func achievements(_ achievements: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("업적")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DSColor.textPrimary)
                .padding(.horizontal, Spacing.screen)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Spacing.s + Spacing.xxs) {
                    ForEach(achievements) { achievement in
                        AchievementCard(achievement: achievement, status: viewModel.statusText(for: achievement))
                    }
                }
                .padding(.horizontal, Spacing.screen)
            }
        }
    }
}

// MARK: - 요약 카드

private struct SummaryCard: View {
    let summary: CollectionSummary
    let progress: Double
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text("\(summary.badges.count)")
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(DSColor.textPrimary)
                Text("/ \(summary.totalSymbolCount.formatted()) 심볼 뱃지")
                    .font(.body)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            ProgressView(value: progress)
                .progressViewStyle(BarProgressStyle())
                .accessibilityHidden(true)
            // 등급 4개를 2×2로 둔다. 한 줄에 3~4개를 두면 좁은 화면(iPhone 13 등)에서 이름이 "브..."로 잘렸다.
            // 가장 큰 글자 크기에서는 한 줄에 하나씩.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s),
                                     count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                      spacing: Spacing.s) {
                ForEach(BadgeTier.allCases.reversed(), id: \.self) { tier in
                    TierCountChip(tier: tier, count: summary.count(of: tier))
                }
            }
        }
        .padding(Spacing.l)
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

/// 등급별 개수 칩: 등급 점 · 이름 · 개수. 이름은 줄이지 않고, 넘치면 줄을 바꾼다.
private struct TierCountChip: View {
    let tier: BadgeTier
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.s) {
            BadgeDot(tier: tier, size: 18)
            Text(tier.displayName)
                .font(.footnote)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)
            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(DSColor.textPrimary)
        }
        .padding(.vertical, Spacing.s)
        .padding(.horizontal, Spacing.s + Spacing.xxs)
        .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
        // 디자인은 bg2지만 다크에서 카드(cell)와 같은 색이라 칩이 사라져 fill을 쓴다.
        .background(DSColor.fill, in: RoundedRectangle(cornerRadius: Radius.button))
        .accessibilityElement(children: .combine)
    }
}

/// accent 진행 막대(높이 6, r3)
struct BarProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DSColor.bgTertiary)
                Capsule().fill(DSColor.accent)
                    .frame(width: proxy.size.width * (configuration.fractionCompleted ?? 0))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - 업적 카드

private struct AchievementCard: View {
    let achievement: Achievement
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            BadgeView(systemImage: achievement.id.systemImage, style: achievement.isUnlocked ? .achievement : .locked, size: 48)
            Text(achievement.id.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSColor.textPrimary)
            Text(achievement.id.condition)
                .font(.caption)
                .foregroundStyle(DSColor.textSecondary)
                .frame(minHeight: 32, alignment: .top)
            ProgressView(value: Double(min(achievement.progress, achievement.goal)), total: Double(achievement.goal))
                .tint(DSColor.accent)
            Text(status)
                .font(.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .padding(Spacing.m + Spacing.xxs)
        .frame(width: 150, alignment: .leading)
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 카테고리 격자

private struct CategorySection: View {
    let category: CategorySymbols
    let viewModel: CollectionViewModel
    @State private var peekName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(SymbolCategoryNames.displayName(for: category.category))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Text("\(viewModel.earnedCount(in: category)) / \(category.names.count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(.horizontal, Spacing.screen)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: Spacing.m)], spacing: Spacing.m) {
                ForEach(category.names, id: \.self) { name in
                    MedalCell(name: name, badge: viewModel.badge(for: name), isPeeking: peekName == name,
                              onTap: { viewModel.select(symbolName: name) },
                              onPeek: { peekName = name })
                        .zIndex(peekName == name ? 1 : 0)
                }
            }
            .padding(Spacing.m + Spacing.xxs)
            .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
            .padding(.horizontal, Spacing.screen)
        }
        .task(id: peekName) {
            // 손을 떼고 잠시 뒤 말풍선을 내린다(디자인: 900ms).
            guard peekName != nil else { return }
            try? await Task.sleep(for: .milliseconds(1_300))
            peekName = nil
        }
    }
}

/// 메달 한 칸. 탭 → S7, 길게 누르기 → 이름 말풍선
private struct MedalCell: View {
    let name: String
    let badge: SymbolBadge?
    let isPeeking: Bool
    let onTap: () -> Void
    let onPeek: () -> Void

    var body: some View {
        BadgeView(systemImage: name, style: badge.map { .tier($0.tier) } ?? .locked, size: 56)
            .frame(maxWidth: .infinity)
            .contentShape(Circle())
            .onTapGesture(perform: onTap)
            .onLongPressGesture(minimumDuration: 0.42, perform: onPeek)
            .overlay(alignment: .top) {
                if isPeeking { bubble.offset(y: -48).transition(.scale(scale: 0.94).combined(with: .opacity)) }
            }
            .animation(.easeOut(duration: 0.18), value: isPeeking)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(badge.map { String(localized: "\(name), \($0.tier.displayName) 뱃지") } ?? String(localized: "\(name), 미획득"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onTap() }
    }

    private var bubble: some View {
        VStack(spacing: Spacing.xxs) {
            Text(name).font(DSFont.symbolNameSmall)
            Text(badge.map { "\($0.tier.displayName) · \($0.bestSimilarity)%" } ?? String(localized: "미획득"))
                .font(.caption2)
                .opacity(0.75)
        }
        .foregroundStyle(DSColor.bgPrimary)
        .fixedSize()
        .padding(.vertical, Spacing.s - 1)
        .padding(.horizontal, Spacing.m - 1)
        .background(DSColor.textPrimary, in: RoundedRectangle(cornerRadius: Radius.tile))
        .shadow(color: .black.opacity(0.22), radius: 10, y: 8)
    }
}

private struct PreviewCollection: FetchCollectionUseCase {
    func execute() async throws -> CollectionSummary {
        let badges = [
            SymbolBadge(symbolName: "heart", tier: .gold, bestSimilarity: 99, bestSketch: .empty, earnedAt: .now),
            SymbolBadge(symbolName: "sun.max", tier: .legendary, bestSimilarity: 100, bestSketch: .empty, earnedAt: .now),
            SymbolBadge(symbolName: "cloud.sun", tier: .silver, bestSimilarity: 96, bestSketch: .empty, earnedAt: .now),
        ]
        return CollectionSummary(
            badges: badges,
            achievements: [Achievement(id: .firstStroke, progress: 1, unlockedAt: .now), Achievement(id: .sharpshooter, progress: 1, unlockedAt: .now),
                           Achievement(id: .collector10, progress: 2)],
            totalSymbolCount: 1_234,  // 미리보기 예시 값(실제 값은 기기 OS에 따라 계산)
            categories: [
                CategorySymbols(category: SymbolCategory(key: "weather", label: "Weather", icon: "cloud"),
                                names: ["cloud", "cloud.sun", "sun.max", "moon", "snowflake", "wind", "bolt", "drop"]),
                CategorySymbols(category: SymbolCategory(key: "health", label: "Health", icon: "heart"), names: ["heart", "cross", "pills"]),
            ]
        )
    }
}

#Preview("라이트") { NavigationStack { CollectionScreen(viewModel: CollectionViewModel(fetchCollection: PreviewCollection(), navigator: nil)) }.preferredColorScheme(.light) }
#Preview("다크") { NavigationStack { CollectionScreen(viewModel: CollectionViewModel(fetchCollection: PreviewCollection(), navigator: nil)) }.preferredColorScheme(.dark) }
