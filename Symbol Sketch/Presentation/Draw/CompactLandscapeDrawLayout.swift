//
//  CompactLandscapeDrawLayout.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/15/26.
//

import SwiftUI
import Domain

/// iPhone 가로(가로가 긴 compact 컨테이너, 결정 23): 왼쪽 캔버스 · 세로 도구 열 · 오른쪽 최근 줄과 Top 10 목록.
/// 세로로 쌓으면 높이가 모자라 캔버스가 너무 작아지므로 캔버스를 높이에 맞춘 정사각형으로 두고 결과를 옆에 둔다. 바텀시트 없음.
struct CompactLandscapeDrawLayout: View {
    @Bindable var viewModel: DrawViewModel
    let canvas: SketchCanvasController
    let size: CGSize

    /// 최근 줄(또는 목표 카드) 높이(아래 간격 포함)
    private let stripHeight: CGFloat = 56
    /// 결과 행(순위·아이콘·이름·유사도 한 줄)이 들어가는 최소 열 폭
    private let minimumRowColumnWidth: CGFloat = 320

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.l) {
            // 캔버스가 높이보다 작으면(폭에 맞춘 경우: Duo 가로) 세로 가운데에 둔다.
            HStack(spacing: Spacing.l) {
                DrawCanvasArea(
                    controller: canvas,
                    isEmpty: viewModel.sketch.isEmpty,
                    isTooSmall: viewModel.phase == .tooSmall,
                    onChange: { viewModel.sketchDidChange($0) }
                )
                .frame(width: canvasSide, height: canvasSide)

                toolColumn
                    .frame(height: canvasSide)
            }
            .frame(maxHeight: .infinity)

            sideColumn
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// 높이에 맞춘 정사각형. 오른쪽 열이 최소 폭보다 좁아지지 않게 한다(판정과 같은 계산).
    private var canvasSide: CGFloat {
        max(160, DrawLayoutResolver.landscapeCanvasSide(in: size))
    }

    /// 오른쪽 최근·결과 열 폭
    private var sideColumnWidth: CGFloat {
        size.width - DrawLayoutResolver.landscapeHorizontalChrome - canvasSide
    }

    /// 되돌리기 · 다시 하기 · 지우개 · 전체 지우기 → (빈 공간) → 찾기
    private var toolColumn: some View {
        VStack(spacing: Spacing.xs) {
            SketchToolGroup(canvas: canvas, axis: .vertical)
            Spacer(minLength: Spacing.s)
            FindButton(phase: viewModel.phase, isEnabled: viewModel.canSearch, height: Metrics.toolButton, iconOnly: true) {
                viewModel.searchNow()
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    /// 목표 카드(도전 중) 또는 최근 줄 → 결과 패널
    private var sideColumn: some View {
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
            // 한 줄 결과 행이 들어가지 않을 만큼 좁으면(Duo 바깥 화면 가로) 작은 카드 2열
            let isNarrow = sideColumnWidth < minimumRowColumnWidth
            ResultPanel(viewModel: viewModel, columns: isNarrow ? 2 : 1, showsShortcutHint: false, usesCards: isNarrow)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
/// 라이트: iPhone 가로(결과 행) · 다크: Duo 바깥 화면 가로(좁은 열, 카드 2열)
private func compactLandscapePreview(size: CGSize) -> some View {
    let viewModel = DrawPreviewFixture.viewModel()
    return CompactLandscapeDrawLayout(viewModel: viewModel, canvas: SketchCanvasController(), size: size)
        .background(DSColor.bgPrimary)
        .task { await viewModel.start() }
}

#Preview("라이트", traits: .fixedLayout(width: 750, height: 276)) {
    compactLandscapePreview(size: CGSize(width: 750, height: 276)).preferredColorScheme(.light)
}
#Preview("다크", traits: .fixedLayout(width: 594, height: 432)) {
    compactLandscapePreview(size: CGSize(width: 594, height: 432)).preferredColorScheme(.dark)
}
#endif
