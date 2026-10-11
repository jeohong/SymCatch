//
//  RecentScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 최근 찾은 심볼(S5). iPad·Duo 분할 화면은 M4.5에서 `NavigationSplitView`로 바꾼다.
struct RecentScreen: View {
    @Bindable var viewModel: RecentViewModel

    var body: some View {
        content
            .background(DSColor.bgPrimary)
            .navigationTitle("최근 찾은 심볼")
            .toolbar {
                if !viewModel.records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            viewModel.requestClearAll()
                        } label: {
                            Label("전체 삭제", systemImage: "trash")
                                .labelStyle(.titleOnly)
                        }
                        .tint(DSColor.danger)
                    }
                }
            }
            .alert("최근 찾은 심볼을 모두 지울까요?", isPresented: $viewModel.isConfirmingClear) {
                Button("취소", role: .cancel) {}
                Button("모두 지우기", role: .destructive) {
                    Task { await viewModel.confirmClearAll() }
                }
            } message: {
                Text("저장된 그림도 함께 지워져요. 뱃지는 그대로 남아요.")
            }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            EmptyStateView(systemImage: "exclamationmark.triangle", message: String(localized: "기록을 읽지 못했어요"),
                           actionTitle: String(localized: "다시 시도")) {
                Task { await viewModel.load() }
            }
            .frame(maxHeight: .infinity)
        case .loaded where viewModel.hasNoHistory:
            EmptyStateView(systemImage: "clock.arrow.circlepath", message: String(localized: "아직 찾은 심볼이 없어요"),
                           actionTitle: String(localized: "그리러 가기")) {
                viewModel.goDraw()
            }
            .frame(maxHeight: .infinity)
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            if viewModel.hasNoSearchResults {
                Text("‘\(viewModel.query)’와 일치하는 심볼이 없어요")
                    .font(.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxl)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.records) { record in
                        Button { viewModel.select(record) } label: {
                            RecentRow(record: record, badge: viewModel.badge(for: record), timeText: viewModel.timeText(for: record))
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(DSColor.bgPrimary)
                        .listRowSeparatorTint(DSColor.separator)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in Metrics.rowTile + Spacing.m }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(record) }
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(section.group.title)
                        .font(DSFont.sectionHeader)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("이름으로 검색"))
        .animation(.default, value: viewModel.sections)
    }
}

/// 최근 목록 한 행: 심볼 · 이름과 시각 · 당시 그림 · (뱃지 점) 유사도. DESIGN_NOTES S5
struct RecentRow: View {
    let record: FoundRecord
    let badge: SymbolBadge?
    let timeText: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var glyphSize = Metrics.rowGlyph
    @ScaledMetric(relativeTo: .title) private var tileSize = Metrics.rowTile

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: record.symbolName)
                .font(.system(size: glyphSize))
                .foregroundStyle(DSColor.textPrimary)
                .frame(width: tileSize, height: tileSize)
                .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.tile))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(record.symbolName)
                    .font(DSFont.symbolName)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .truncationMode(.middle)
                Text(timeText)
                    .font(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer(minLength: 0)
            SketchShape(sketch: record.sketch)
                .stroke(DSColor.canvasInk, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: tileSize, height: tileSize)
                .background(DSColor.canvasBackground, in: RoundedRectangle(cornerRadius: Radius.tile))
                .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(DSColor.separator, lineWidth: 1))
            HStack(spacing: Spacing.xs) {
                if let badge { BadgeDot(tier: badge.tier) }
                Text("\(record.similarity)%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(DSColor.textPrimary)
            }
            .frame(minWidth: 58, alignment: .trailing)
        }
        .padding(.vertical, Spacing.s + Spacing.xxs)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        var text = String(localized: "\(record.symbolName), 유사도 \(record.similarity)퍼센트, \(timeText)")
        if let badge { text += String(localized: ", \(badge.tier.displayName) 뱃지") }
        return text
    }
}

private struct PreviewRecent: FetchRecentRecordsUseCase, DeleteRecordsUseCase, ClearHistoryUseCase, FetchBadgesUseCase {
    var records: [FoundRecord]
    func execute(limit: Int?) async throws -> [FoundRecord] { records }
    func execute(ids: [UUID]) async throws {}
    func execute() async throws {}
    func execute() async throws -> [String: SymbolBadge] {
        ["heart": SymbolBadge(symbolName: "heart", tier: .silver, bestSimilarity: 96, bestSketch: .empty, earnedAt: .now)]
    }
}

private func previewViewModel(empty: Bool = false) -> RecentViewModel {
    let line = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.2), SketchPoint(x: 0.9, y: 0.8)]])
    let records = [("heart", 0.0), ("star", -3_600.0), ("cloud.sun", -86_400.0), ("bolt", -86_400.0 * 3), ("paperplane", -86_400.0 * 9)]
        .map { FoundRecord(symbolName: $0.0, sketch: line, similarity: 96, foundAt: .now.addingTimeInterval($0.1)) }
    let source = PreviewRecent(records: empty ? [] : records)
    return RecentViewModel(fetchRecent: source, deleteRecords: source, clearHistory: source, fetchBadges: source, navigator: nil)
}

#Preview("라이트") { NavigationStack { RecentScreen(viewModel: previewViewModel()) }.preferredColorScheme(.light) }
#Preview("다크") { NavigationStack { RecentScreen(viewModel: previewViewModel()) }.preferredColorScheme(.dark) }
#Preview("빈 상태") { NavigationStack { RecentScreen(viewModel: previewViewModel(empty: true)) } }
