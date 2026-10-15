//
//  SymbolSearchScreen.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/15/26.
//

import SwiftUI
import Domain

/// 심볼 검색(S9). 검색어가 없으면 카테고리 둘러보기, 있으면 결과 타일 격자(기획서 6장 S9).
struct SymbolSearchScreen: View {
    @Bindable var viewModel: SymbolSearchViewModel
    /// 시스템 검색 탭(iOS 26+ 좁은 창, 결정 24) 안이면 검색창을 기본 위치로 달아 시스템이 탭 바 자리로 옮기게 한다.
    /// 아니면(iOS 17~25, 넓은 창) 위쪽 내비게이션 바 아래에 항상 보이게 단다.
    var searchFieldInTabBar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if let category = viewModel.selectedCategory {
                    CategoryChip(name: SymbolCategoryNames.displayName(for: category)) { viewModel.clearCategory() }
                }
                content
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.m)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(DSColor.bgGrouped)
        .navigationTitle("심볼 검색")
        .modifier(SearchField(query: $viewModel.query, inTabBar: searchFieldInTabBar))
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .browsing:
            browse
        case .results(let items):
            results(items)
        case .noMatches:
            EmptyStateView(systemImage: "magnifyingglass",
                           message: String(localized: "‘\(viewModel.query)’와 일치하는 심볼이 없어요"),
                           actionTitle: String(localized: "그려서 찾아보세요")) { viewModel.goDraw() }
                .padding(.top, Spacing.xxl)
        case .failed(let message):
            EmptyStateView(systemImage: "exclamationmark.triangle", message: message)
                .padding(.top, Spacing.xxl)
        }
    }

    // MARK: - 카테고리 둘러보기

    private var browse: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("카테고리 둘러보기")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: Spacing.s + Spacing.xxs)], spacing: Spacing.s + Spacing.xxs) {
                ForEach(viewModel.categories) { summary in
                    Button { viewModel.selectCategory(summary.category) } label: {
                        CategoryTile(summary: summary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 결과

    private func results(_ items: [SymbolBrowseItem]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("결과 \(items.count)개")
                .font(DSFont.sectionHeader)
                .foregroundStyle(DSColor.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.s)], spacing: Spacing.s) {
                ForEach(items) { item in
                    Button { viewModel.select(item) } label: {
                        SymbolTile(item: item, badge: viewModel.badge(for: item))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// 카테고리 카드: 아이콘 · 한국어 이름 · 심볼 수
private struct CategoryTile: View {
    let summary: SymbolCategorySummary
    @ScaledMetric(relativeTo: .title) private var glyphSize: CGFloat = 22
    @ScaledMetric(relativeTo: .title) private var tileSize: CGFloat = 40

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: summary.category.icon)
                .font(.system(size: glyphSize))
                .foregroundStyle(DSColor.accent)
                .frame(width: tileSize, height: tileSize)
                .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.tile))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(SymbolCategoryNames.displayName(for: summary.category))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(2)
                Text("\(summary.count)개")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// 결과 타일: 글리프 · 이름(가운데 줄임) · 받은 뱃지 등급 점
private struct SymbolTile: View {
    let item: SymbolBrowseItem
    let badge: SymbolBadge?
    @ScaledMetric(relativeTo: .title) private var glyphSize: CGFloat = Metrics.rowGlyph

    var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: item.symbol.name)
                .font(.system(size: glyphSize))
                .foregroundStyle(DSColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: glyphSize * 1.6)
            // 점 뒤에서만 줄을 바꾼다(글자 중간에서 꺾이지 않게). 보이는 글자만 바꾸고 VoiceOver는 원래 이름.
            Text(verbatim: item.symbol.name.replacingOccurrences(of: ".", with: ".\u{200B}"))
                .font(DSFont.symbolNameSmall)
                .foregroundStyle(DSColor.textSecondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)
        }
        .padding(.top, Spacing.m)
        .padding(.horizontal, Spacing.s)
        .padding(.bottom, Spacing.s)
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.toolGroup))
        .overlay(alignment: .topTrailing) {
            if let badge { BadgeDot(tier: badge.tier, size: 10).padding(Spacing.s) }
        }
        .contentShape(RoundedRectangle(cornerRadius: Radius.toolGroup))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.map { String(localized: "\(item.symbol.name), \($0.tier.displayName) 뱃지") } ?? item.symbol.name)
        .accessibilityAddTraits(.isButton)
    }
}

/// 고른 카테고리 칩(누르면 해제)
private struct CategoryChip: View {
    let name: String
    let onClear: () -> Void

    var body: some View {
        Button(action: onClear) {
            HStack(spacing: Spacing.xs) {
                Text(name)
                Image(systemName: "xmark").font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DSColor.onAccent)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: 36)
            .background(DSColor.accent, in: Capsule())
            .frame(minHeight: Metrics.minTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "\(name) 카테고리 해제"))
    }
}

#if DEBUG
private struct PreviewBrowse: BrowseSymbolsUseCase {
    func categories() async throws -> [SymbolCategorySummary] {
        [SymbolCategorySummary(category: SymbolCategory(key: "health", label: "Health", icon: "heart"), count: 67),
         SymbolCategorySummary(category: SymbolCategory(key: "nature", label: "Nature", icon: "leaf"), count: 178),
         SymbolCategorySummary(category: SymbolCategory(key: "weather", label: "Weather", icon: "cloud.sun"), count: 97)]
    }

    func execute(query: String, category: String?) async throws -> [SymbolBrowseItem] {
        ["heart", "heart.circle", "suit.heart", "bolt.heart", "heart.text.square"].map {
            SymbolBrowseItem(symbol: SymbolMeta(name: $0, family: $0, categories: ["health"], keywords: [], minOS: "13.0"), variantCount: 2)
        }
    }
}

private struct PreviewBadges: FetchBadgesUseCase {
    func execute() async throws -> [String: SymbolBadge] {
        ["heart": SymbolBadge(symbolName: "heart", tier: .gold, bestSimilarity: 96, bestSketch: .empty, earnedAt: .now)]
    }
}

private func searchPreview(query: String) -> some View {
    let viewModel = SymbolSearchViewModel(browse: PreviewBrowse(), fetchBadges: PreviewBadges(), navigator: nil, debounce: .zero)
    viewModel.query = query
    return NavigationStack { SymbolSearchScreen(viewModel: viewModel) }
}

#Preview("라이트") { searchPreview(query: "").preferredColorScheme(.light) }
#Preview("다크") { searchPreview(query: "heart").preferredColorScheme(.dark) }
#endif

/// 검색창 위치: 탭 바 자리(시스템 검색 탭, iOS 26+ 좁은 창) 또는 위쪽 내비게이션 바 아래(iOS 17~25, 넓은 창)
private struct SearchField: ViewModifier {
    @Binding var query: String
    let inTabBar: Bool

    func body(content: Content) -> some View {
        Group {
            if inTabBar {
                content.searchable(text: $query, prompt: Text("하트, heart처럼 검색"))
            } else {
                content.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("하트, heart처럼 검색"))
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }
}
