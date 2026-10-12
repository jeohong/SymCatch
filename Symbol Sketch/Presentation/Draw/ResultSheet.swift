//
//  ResultSheet.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 캔버스 아래 결과 시트. 접힘 = Top 3 카드(S1), 펼침 = Top 10 목록(S2). DESIGN_NOTES 3.5
/// 위로 끌거나 "모두 보기"로 펼치고, 아래로 끌거나 "접기"로 접는다.
struct ResultSheet: View {
    @Bindable var viewModel: DrawViewModel

    var body: some View {
        VStack(spacing: 0) {
            grabber
            header
            ScrollView {
                content
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
            }
            .scrollDisabled(!viewModel.isSheetExpanded)
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
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text("검색 결과").font(.headline).foregroundStyle(DSColor.textPrimary)
            Text("Top 10 · 유사도순").font(.footnote).foregroundStyle(DSColor.textSecondary)
            Spacer(minLength: 0)
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
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        switch viewModel.preparation {
        case .checking, .preparing:
            preparing
        case .failed:
            failure(String(localized: "심볼 인덱스를 읽지 못했어요")) {
                Button("다시 준비하기") { viewModel.retryPreparation() }
                    .buttonStyle(InvertedButtonStyle())
            }
        case .ready:
            readyContent
        }
    }

    @ViewBuilder
    private var readyContent: some View {
        switch viewModel.phase {
        case .tooSmall:
            message(String(localized: "조금 더 크게 그려 주세요"), detail: String(localized: "그림이 너무 작거나 획이 적어서 찾지 않았어요"))
        case .failed(let reason):
            message(String(localized: "찾지 못했어요"), detail: reason)
        case .searching(showsSkeleton: true) where viewModel.matches.isEmpty:
            SkeletonRows()
        default:
            if viewModel.matches.isEmpty {
                #if DEBUG
                if let seconds = viewModel.preparationSeconds {
                    // 개발용: 실기기 준비 시간 측정(출시 빌드에는 없음)
                    Text(verbatim: "[DEBUG] 심볼 준비 시간 \(String(format: "%.1f", seconds))초")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(DSColor.danger)
                        .accessibilityIdentifier("debugPreparationSeconds")
                }
                #endif
                message(String(localized: "그림을 그리면 비슷한 심볼이\n여기에 나타나요"), detail: nil)
            } else if viewModel.isSheetExpanded {
                expandedList
            } else {
                topThree
            }
        }
    }

    private var topThree: some View {
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

    private var preparing: some View {
        let progress: Double = if case .preparing(let value) = viewModel.preparation { value } else { 0 }
        return VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("심볼 준비 중").font(.subheadline)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.monospacedDigit())
            }
            .foregroundStyle(DSColor.textPrimary)
            ProgressView(value: progress)
                .tint(DSColor.accent)
            Text("처음 한 번만 기기 안에서 심볼을 준비해요")
                .font(.footnote)
                .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.top, Spacing.s)
        .accessibilityElement(children: .combine)
    }

    private func message(_ title: String, detail: String?) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(.subheadline.weight(detail == nil ? .regular : .semibold))
                .foregroundStyle(detail == nil ? DSColor.textSecondary : DSColor.textPrimary)
            if let detail {
                Text(detail).font(.footnote).foregroundStyle(DSColor.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.l)
    }

    private func failure(_ title: String, @ViewBuilder action: () -> some View) -> some View {
        VStack(spacing: Spacing.m) {
            Text(title).font(.subheadline).foregroundStyle(DSColor.textPrimary)
            action()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.l)
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

/// 검색이 0.3초를 넘길 때 보여 주는 자리 표시 3행
private struct SkeletonRows: View {
    @State private var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: Spacing.m) {
                    RoundedRectangle(cornerRadius: Radius.tile).fill(DSColor.bgTertiary).frame(width: Metrics.rowTile, height: Metrics.rowTile)
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Capsule().fill(DSColor.bgTertiary).frame(width: 140, height: 12)
                        Capsule().fill(DSColor.bgTertiary).frame(width: 80, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: Radius.chip).fill(DSColor.bgTertiary).frame(width: 48, height: 20)
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

