//
//  AchievementsScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/15/26.
//

import SwiftUI
import Domain

/// 업적 전체 보기(기획서 3.2): 달성 요약 · 일반 업적 격자 · 카테고리마다 입문·전설.
/// 콜렉션 "업적" 제목 옆 "전체 보기"로 들어온다(넓은 창은 분할 화면 오른쪽).
struct AchievementsScreen: View {
    @Bindable var viewModel: CollectionViewModel

    var body: some View {
        Group {
            if let summary = viewModel.summary {
                content(summary)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DSColor.bgGrouped)
        .navigationTitle("업적")
        .task { await viewModel.load() }
    }

    private func content(_ summary: CollectionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                summaryCard
                section("일반") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s + Spacing.xxs)],
                              spacing: Spacing.s + Spacing.xxs) {
                        ForEach(viewModel.generalAchievements) { achievement in
                            AchievementCard(achievement: achievement, status: viewModel.statusText(for: achievement), fixedWidth: nil)
                        }
                    }
                }
                section("카테고리") {
                    VStack(spacing: Spacing.s + Spacing.xxs) {
                        ForEach(summary.categories, id: \.category.key) { category in
                            let achievements = viewModel.categoryAchievements(for: category.category.key)
                            if !achievements.isEmpty {
                                CategoryAchievementRow(category: category, earned: viewModel.earnedCount(in: category),
                                                       achievements: achievements, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.m)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text("\(viewModel.unlockedAchievementCount)")
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(DSColor.textPrimary)
                Text("/ \(viewModel.achievementCount) 업적 달성")
                    .font(.body)
                    .foregroundStyle(DSColor.textSecondary)
            }
            ProgressView(value: Double(viewModel.unlockedAchievementCount), total: Double(max(viewModel.achievementCount, 1)))
                .tint(DSColor.accent)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// 카테고리 한 칸: 위 줄 이름 ↔ 모은 수, 아래 줄 입문·전설 메달(반반, 가운데 정렬).
/// 폭과 이름 길이에 관계없이 모든 칸이 같은 모양이 되게 한다(Duo 바깥 화면처럼 좁을 때도).
private struct CategoryAchievementRow: View {
    let category: CategorySymbols
    let earned: Int
    let achievements: [Achievement]
    let viewModel: CollectionViewModel

    var body: some View {
        VStack(spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(SymbolCategoryNames.displayName(for: category.category))
                    .font(.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer(minLength: Spacing.s)
                Text("\(earned) / \(category.names.count) 뱃지")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(DSColor.textSecondary)
            }
            .accessibilityElement(children: .combine)

            HStack(alignment: .top, spacing: Spacing.s) {
                ForEach(achievements) { achievement in
                    medal(achievement)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Spacing.m + Spacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func medal(_ achievement: Achievement) -> some View {
        VStack(spacing: Spacing.xs) {
            BadgeView(systemImage: achievement.id.systemImage,
                      style: achievement.isUnlocked ? .achievement : .locked, size: 44)
            Text(achievement.id.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(achievement.id.categoryTierName ?? "") · \(viewModel.statusText(for: achievement))")
                .font(.caption2)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
private struct PreviewCollection: FetchCollectionUseCase {
    func execute() async throws -> CollectionSummary {
        let date = Date.now
        return CollectionSummary(
            badges: [SymbolBadge(symbolName: "leaf", tier: .gold, bestSimilarity: 96, bestSketch: .empty, earnedAt: date)],
            achievements: AchievementID.general.map { Achievement(id: $0, progress: $0 == .firstStroke ? 1 : 0, unlockedAt: $0 == .firstStroke ? date : nil) }
                + [Achievement(id: .categoryStarter("nature"), progress: 10, unlockedAt: date, goal: 10),
                   Achievement(id: .categoryMaster("nature"), progress: 10, goal: 178),
                   Achievement(id: .categoryStarter("health"), progress: 3, goal: 10),
                   Achievement(id: .categoryMaster("health"), progress: 3, goal: 67)],
            totalSymbolCount: 5342,
            categories: [CategorySymbols(category: SymbolCategory(key: "nature", label: "Nature", icon: "leaf"), names: ["leaf"]),
                         CategorySymbols(category: SymbolCategory(key: "health", label: "Health", icon: "heart"), names: ["heart"])]
        )
    }
}

private func achievementsPreview() -> some View {
    NavigationStack {
        AchievementsScreen(viewModel: CollectionViewModel(fetchCollection: PreviewCollection(), navigator: nil))
    }
}

#Preview("라이트") { achievementsPreview().preferredColorScheme(.light) }
#Preview("다크") { achievementsPreview().preferredColorScheme(.dark) }
#endif
