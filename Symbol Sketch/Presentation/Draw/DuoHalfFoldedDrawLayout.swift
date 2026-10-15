//
//  DuoHalfFoldedDrawLayout.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import SwiftUI
import Domain

/// iPhone Duo 반쯤 접힘 + 가로 접힘선(기획서 8장, DESIGN_NOTES S1 "Duo 반쯤 접힘").
/// 위: Top 10 결과(5열×2행 카드) / 접힘 영역: 비움 / 아래: 캔버스 · 세로 도구 열 · 최근 칩과 찾기 버튼.
struct DuoHalfFoldedDrawLayout: View {
    @Bindable var viewModel: DrawViewModel
    let canvas: SketchCanvasController
    /// 접힘 위·아래 영역(그리기 화면 컨테이너 좌표)
    let top: CGRect
    let bottom: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            ResultsPane(viewModel: viewModel)
                .frame(width: top.width, height: top.height)
                .offset(x: top.minX, y: top.minY)
            DrawingPane(viewModel: viewModel, canvas: canvas)
                .frame(width: bottom.width, height: bottom.height)
                .offset(x: bottom.minX, y: bottom.minY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 접힌 반쪽 화면에 맞춘 고정 배치라, 접근성 글자 크기에서는 더 키우지 않는다(카드·버튼이 넘치지 않게).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// MARK: - 위: 결과

private struct ResultsPane: View {
    @Bindable var viewModel: DrawViewModel

    private let columns = 5
    private let rows = 2

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            header
            if viewModel.showsMatches {
                grid
            } else {
                DrawStatusView(viewModel: viewModel)
                    .padding(.horizontal, Spacing.l)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.card))
            }
        }
        .padding(.top, Spacing.xs + Spacing.xxs)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.m + Spacing.xxs)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text("검색 결과 Top 10").font(.headline).foregroundStyle(DSColor.textPrimary)
            Text("유사도순").font(.footnote).foregroundStyle(DSColor.textSecondary)
            Spacer(minLength: Spacing.s)
            Text("획을 멈추면 자동으로 찾아요")
                .font(.footnote)
                .foregroundStyle(DSColor.textSecondary)
                .lineLimit(1)
        }
    }

    /// 5열×2행이 영역 높이를 꽉 채운다(스크롤 없음, DESIGN_NOTES 3.8).
    private var grid: some View {
        let matches = Array(viewModel.matches.prefix(columns * rows))
        return Grid(horizontalSpacing: Spacing.s, verticalSpacing: Spacing.s) {
            ForEach(0..<rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < matches.count {
                            let match = matches[index]
                            Button { viewModel.select(match) } label: {
                                DuoResultCard(rank: index + 1, match: match, badgeHint: viewModel.badgeHint(for: match))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: matches.map(\.id))
    }
}

// MARK: - 아래: 그리기

private struct DrawingPane: View {
    @Bindable var viewModel: DrawViewModel
    let canvas: SketchCanvasController

    var body: some View {
        GeometryReader { proxy in
            let side = max(120, proxy.size.height)
            HStack(alignment: .top, spacing: Spacing.l) {
                DrawCanvasArea(
                    controller: canvas,
                    isEmpty: viewModel.sketch.isEmpty,
                    isTooSmall: viewModel.phase == .tooSmall,
                    onChange: { viewModel.sketchDidChange($0) }
                )
                .frame(width: side, height: side)

                SketchToolGroup(canvas: canvas, axis: .vertical, buttonSize: Metrics.duoToolButton)

                sideColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.top, Spacing.l)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
    }

    /// 목표 카드(도전 중) → 최근 찾은 심볼 칩 → (빈 공간) → 찾기 버튼
    private var sideColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.s + Spacing.xxs) {
            if let target = viewModel.challengeTarget {
                TargetBanner(symbolName: target, badge: viewModel.challengeBadge) { viewModel.endChallenge() }
            }
            if !viewModel.recentRecords.isEmpty {
                Text("최근 찾은 심볼")
                    .font(DSFont.sectionHeader)
                    .foregroundStyle(DSColor.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: Spacing.s) {
                    ForEach(viewModel.recentRecords) { record in
                        RecentChip(record: record) { viewModel.selectRecent(record) }
                    }
                }
            }
            Spacer(minLength: Spacing.s)
            FindButton(phase: viewModel.phase, isEnabled: viewModel.canSearch,
                       height: Metrics.largeButtonHeight, fillsWidth: true) {
                viewModel.searchNow()
            }
        }
    }
}

#if DEBUG
private func duoPreview() -> some View {
    let viewModel = DrawPreviewFixture.viewModel()
    return DuoHalfFoldedDrawLayout(
        viewModel: viewModel,
        canvas: SketchCanvasController(),
        top: CGRect(x: 0, y: 0, width: 890, height: 301),
        bottom: CGRect(x: 0, y: 325, width: 890, height: 301)
    )
    .frame(width: 890, height: 626)
    .background(DSColor.bgPrimary)
    .task { await viewModel.start() }
}

#Preview("라이트", traits: .fixedLayout(width: 890, height: 626)) { duoPreview().preferredColorScheme(.light) }
#Preview("다크", traits: .fixedLayout(width: 890, height: 626)) { duoPreview().preferredColorScheme(.dark) }
#endif
