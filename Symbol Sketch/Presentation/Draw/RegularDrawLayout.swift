//
//  RegularDrawLayout.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/15/26.
//

import SwiftUI
import Domain

/// 넓은 창(regular) 그리기 화면(기획서 8A.1, DESIGN_NOTES S1 "iPad 가로·세로").
/// 가로: 왼쪽 캔버스 열 + 오른쪽 결과 패널(1열). 세로: 위 캔버스 열 + 아래 결과 패널(2열 격자). 바텀시트 없음.
struct RegularDrawLayout: View {
    enum Arrangement { case landscape, portrait }

    @Bindable var viewModel: DrawViewModel
    let canvas: SketchCanvasController
    let arrangement: Arrangement
    let size: CGSize

    /// 최근 줄(또는 목표 카드) · 도구 바 높이(DESIGN_NOTES S1)
    private let stripHeight: CGFloat = 56
    private let toolbarHeight: CGFloat = 58
    /// 세로 배치에서 결과 패널이 최소한 차지할 높이(2열 × 3행 정도)
    private let minimumPortraitPanelHeight: CGFloat = 300

    var body: some View {
        Group {
            switch arrangement {
            case .landscape:
                HStack(alignment: .top, spacing: Spacing.l + Spacing.xs) {
                    // 그리기 열은 남는 높이의 세로 가운데(펼친 Duo 가로처럼 높이가 남을 때), 결과 패널은 전체 높이
                    canvasColumn
                        .frame(maxHeight: .infinity)
                    ResultPanel(viewModel: viewModel, columns: 1)
                }
            case .portrait:
                VStack(spacing: Spacing.l + Spacing.xs) {
                    canvasColumn
                    ResultPanel(viewModel: viewModel, columns: 2)
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private var showsStrip: Bool { viewModel.challengeTarget != nil || !viewModel.recentRecords.isEmpty }

    /// 캔버스는 정사각형, 짧은 변의 약 70%(기획서 8A.1). 결과 패널과 도구가 들어갈 자리는 남긴다.
    private var canvasSide: CGFloat {
        let chrome = (showsStrip ? stripHeight + Spacing.s : 0) + toolbarHeight + Spacing.xl
        let byShortSide = min(size.width, size.height) * 0.7
        switch arrangement {
        case .landscape:
            return max(200, min(byShortSide, size.height - chrome, size.width * 0.5))
        case .portrait:
            return max(200, min(byShortSide, size.height - chrome - minimumPortraitPanelHeight, size.width - Spacing.xl * 2))
        }
    }

    private var canvasColumn: some View {
        VStack(spacing: 0) {
            if let target = viewModel.challengeTarget {
                TargetBanner(symbolName: target, badge: viewModel.challengeBadge) { viewModel.endChallenge() }
                    .frame(height: stripHeight - Spacing.s)
                    .padding(.bottom, Spacing.s)
            } else if !viewModel.recentRecords.isEmpty {
                RecentStrip(records: viewModel.recentRecords, leadingInset: 0) { viewModel.selectRecent($0) }
                    .frame(height: stripHeight - Spacing.s)
                    .padding(.bottom, Spacing.s)
            }
            DrawCanvasArea(
                controller: canvas,
                isEmpty: viewModel.sketch.isEmpty,
                isTooSmall: viewModel.phase == .tooSmall,
                onChange: { viewModel.sketchDidChange($0) }
            )
            .frame(width: canvasSide, height: canvasSide)
            DrawToolbar(canvas: canvas, phase: viewModel.phase, canSearch: viewModel.canSearch) {
                viewModel.searchNow()
            }
            .frame(height: toolbarHeight)
        }
        .frame(width: canvasSide)
    }
}

// MARK: - 결과 패널

/// 넓은 창의 결과 패널(DESIGN_NOTES S1 regular): 머리글 · Top 10(1열 목록 또는 2열 격자) · 다시 그리기.
/// iPhone 가로(`CompactLandscapeDrawLayout`)도 1열로 같이 쓴다.
struct ResultPanel: View {
    @Bindable var viewModel: DrawViewModel
    let columns: Int
    /// 하드웨어 키보드가 흔한 넓은 창에서만 "⌘C 이름 복사"를 보여 준다.
    var showsShortcutHint = true
    /// 결과 행 대신 작은 카드(`DuoResultCard`)로 보여 준다. 한 줄 행이 들어가지 않는 좁은 열(Duo 바깥 화면 가로)용.
    var usesCards = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if viewModel.showsMatches {
                ScrollView {
                    results
                        .padding(.horizontal, Spacing.m)
                        .padding(.bottom, Spacing.m)
                }
            } else {
                DrawStatusView(viewModel: viewModel)
                    .padding(.horizontal, Spacing.l)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.panel))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text("검색 결과").font(.title3.weight(.semibold)).foregroundStyle(DSColor.textPrimary)
            Text("Top 10 · 유사도순").font(.footnote).foregroundStyle(DSColor.textSecondary)
            Spacer(minLength: Spacing.s)
            if showsShortcutHint {
                Text("⌘C 이름 복사")
                    .font(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, Spacing.l)
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.s + Spacing.xxs)
    }

    private var results: some View {
        VStack(spacing: Spacing.s) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: columns), spacing: Spacing.s) {
                ForEach(Array(viewModel.matches.enumerated()), id: \.element.id) { index, match in
                    Button { viewModel.select(match) } label: {
                        if usesCards {
                            DuoResultCard(rank: index + 1, match: match, badgeHint: viewModel.badgeHint(for: match),
                                          background: DSColor.cellElevated)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            SymbolResultRow(rank: index + 1, match: match, badgeHint: viewModel.badgeHint(for: match))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Button { viewModel.redraw() } label: {
                Label("찾는 심볼이 없나요? 다시 그리기", systemImage: "scribble")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: Metrics.largeButtonHeight)
                    .background(DSColor.cellElevated, in: RoundedRectangle(cornerRadius: Radius.button))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.matches.map(\.id))
    }
}

#if DEBUG
private func regularPreview(_ arrangement: RegularDrawLayout.Arrangement, size: CGSize) -> some View {
    let viewModel = DrawPreviewFixture.viewModel()
    return RegularDrawLayout(viewModel: viewModel, canvas: SketchCanvasController(), arrangement: arrangement, size: size)
        .background(DSColor.bgPrimary)
        .task { await viewModel.start() }
}

#Preview("라이트", traits: .fixedLayout(width: 1180, height: 760)) {
    regularPreview(.landscape, size: CGSize(width: 1180, height: 760)).preferredColorScheme(.light)
}
#Preview("다크", traits: .fixedLayout(width: 820, height: 1100)) {
    regularPreview(.portrait, size: CGSize(width: 820, height: 1100)).preferredColorScheme(.dark)
}
#endif
