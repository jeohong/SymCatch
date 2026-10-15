//
//  ResultSheet.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 캔버스 아래 결과 시트. 접힘 = Top 3 카드(S1), 펼침 = Top 10 목록(S2). DESIGN_NOTES 3.5
/// 위로 끌거나 "모두 보기"로 펼치고, 아래로 끌거나 "접기"로 접는다.
struct ResultSheet: View {
    @Bindable var viewModel: DrawViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 접근성 글자 크기: 머리글을 세로로 쌓고, Top 3를 카드 대신 결과 행으로 보여 준다(기획서 6장 접근성).
    private var isLargeText: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            header
            ScrollView {
                content
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
            }
            .scrollDisabled(!viewModel.isSheetExpanded && !isLargeText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DSColor.bgSecondary)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.card, topTrailingRadius: Radius.card))
        .shadow(color: .black.opacity(0.08), radius: 15, y: -10)
        .gesture(dragToResize)
    }

    // MARK: - 머리

    private var grabber: some View {
        Capsule()
            .fill(DSColor.grab)
            .frame(width: Metrics.grabberWidth, height: Metrics.grabberHeight)
            .frame(maxWidth: .infinity, minHeight: 20)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            .accessibilityHidden(true)
    }

    private var header: some View {
        let layout = isLargeText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.s))
        return layout {
            Text("검색 결과").font(.headline).foregroundStyle(DSColor.textPrimary)
            Text("Top 10 · 유사도순").font(.footnote).foregroundStyle(DSColor.textSecondary)
            if !isLargeText { Spacer(minLength: 0) }
            if !viewModel.matches.isEmpty {
                Button { toggle() } label: {
                    Label(viewModel.isSheetExpanded ? "접기" : "모두 보기",
                          systemImage: viewModel.isSheetExpanded ? "chevron.down" : "chevron.up")
                        .labelStyle(TrailingIconLabelStyle())
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: Metrics.minTapTarget)
                }
                .tint(DSColor.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        if viewModel.showsMatches {
            if viewModel.isSheetExpanded { expandedList } else { topThree }
        } else {
            DrawStatusView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var topThree: some View {
        if isLargeText {
            // 큰 글자에서는 카드 3칸이 너무 좁아 결과 행(세로 배치 지원)으로 보여 준다.
            VStack(spacing: Spacing.s) {
                ForEach(Array(viewModel.previewMatches.enumerated()), id: \.element.id) { index, match in
                    Button { viewModel.select(match) } label: {
                        SymbolResultRow(rank: index + 1, match: match, badgeHint: viewModel.badgeHint(for: match))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            topThreeCards
        }
    }

    private var topThreeCards: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            ForEach(Array(viewModel.previewMatches.enumerated()), id: \.element.id) { index, match in
                Button { viewModel.select(match) } label: {
                    ResultCard(rank: index + 1, match: match, badgeHint: viewModel.badgeHint(for: match))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.previewMatches.map(\.id))
    }

    private var expandedList: some View {
        VStack(spacing: Spacing.s) {
            ForEach(Array(viewModel.matches.enumerated()), id: \.element.id) { index, match in
                Button { viewModel.select(match) } label: {
                    SymbolResultRow(rank: index + 1, match: match, badgeHint: viewModel.badgeHint(for: match))
                }
                .buttonStyle(.plain)
            }
            Button { viewModel.redraw() } label: {
                Label("찾는 심볼이 없나요? 다시 그리기", systemImage: "scribble")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: Metrics.largeButtonHeight)
                    .background(DSColor.cellElevated, in: RoundedRectangle(cornerRadius: Radius.button))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.s)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.matches.map(\.id))
    }

    // MARK: - 펼치기·접기

    private func toggle() {
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.34)) {
            viewModel.isSheetExpanded.toggle()
        }
    }

    private var dragToResize: some Gesture {
        DragGesture(minimumDistance: 16).onEnded { value in
            let expand = value.translation.height < -16
            let collapse = value.translation.height > 16
            guard expand || collapse, !viewModel.matches.isEmpty || collapse else { return }
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.34)) {
                viewModel.isSheetExpanded = expand
            }
        }
    }
}

/// 검색이 0.3초를 넘길 때 보여 주는 자리 표시 3행(그리기·온보딩 연습 공용)
struct SkeletonRows: View {
    @State private var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: Spacing.m) {
                    RoundedRectangle(cornerRadius: Radius.tile).fill(DSColor.skeleton).frame(width: Metrics.rowTile, height: Metrics.rowTile)
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Capsule().fill(DSColor.skeleton).frame(width: 140, height: 12)
                        Capsule().fill(DSColor.skeleton).frame(width: 80, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: Radius.chip).fill(DSColor.skeleton).frame(width: 48, height: 20)
                }
                .padding(Spacing.m)
                .frame(height: 64)
                .background(DSColor.cellElevated, in: RoundedRectangle(cornerRadius: Radius.card))
            }
        }
        .opacity(dimmed ? 0.5 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever()) { dimmed = true }
        }
        .accessibilityElement()
        .accessibilityLabel("찾는 중")
    }
}

/// 아이콘을 글자 뒤에 붙이는 라벨("모두 보기 ⌃")
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xs) {
            configuration.title
            configuration.icon
        }
    }
}

/// 반전색 버튼(오류 화면의 "다시 준비하기")
struct InvertedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DSColor.bgPrimary)
            .padding(.horizontal, Spacing.l + Spacing.xs)
            .frame(minHeight: Metrics.minTapTarget)
            .background(DSColor.textPrimary, in: RoundedRectangle(cornerRadius: Radius.button))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

#if DEBUG
private func resultSheetPreview() -> some View {
    let viewModel = DrawPreviewFixture.viewModel()
    return ResultSheet(viewModel: viewModel)
        .frame(height: 320)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .task { await viewModel.start() }
}

#Preview("라이트") { resultSheetPreview().preferredColorScheme(.light) }
#Preview("다크") { resultSheetPreview().preferredColorScheme(.dark) }
#endif
