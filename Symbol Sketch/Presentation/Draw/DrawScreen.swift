//
//  DrawScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 그리기 화면(S1) + 결과(S2). 배치는 `DrawLayoutResolver`가 고른다(CLAUDE.md 4장).
/// compact(일반 iPhone, 좁은 창) · Duo 반쯤 접힘(M4) · iPad 넓은 창 가로·세로(M4.5).
struct DrawScreen: View {
    @Bindable var viewModel: DrawViewModel
    @State private var canvas = SketchCanvasController()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 캔버스 아래 도구 바 높이
    private let toolbarHeight: CGFloat = 58
    /// 접힌 결과 시트가 최소한 차지할 높이(Top 3 카드가 보이도록)
    private let minimumSheetHeight: CGFloat = 200
    /// 상단 최근 스트립 높이(DESIGN_NOTES 3.3: 56 = 위 여백 6 + 칩 44 + 아래 6)
    private let recentStripHeight: CGFloat = 56

    var body: some View {
        GeometryReader { proxy in
            let layout = DrawLayoutResolver.resolve(
                size: proxy.size,
                horizontalSizeClass: horizontalSizeClass,
                fold: FoldRegionReader.horizontalFold(in: proxy)
            )
            switch layout {
            case .duoHalfFolded(let top, let bottom):
                DuoHalfFoldedDrawLayout(viewModel: viewModel, canvas: canvas, top: top, bottom: bottom)
            case .regularLandscape:
                RegularDrawLayout(viewModel: viewModel, canvas: canvas, arrangement: .landscape, size: proxy.size)
            case .regularPortrait:
                RegularDrawLayout(viewModel: viewModel, canvas: canvas, arrangement: .portrait, size: proxy.size)
            case .compact:
                compactLayout(proxy)
            }
        }
        .background(DSColor.bgPrimary)
        .background {
            // ⌘C: 1위 결과 이름 복사. 보이지 않는 버튼으로 단축키만 건다(⌘ 길게 누르면 목록에 보인다).
            Button("1위 이름 복사") { viewModel.copyTopResultName() }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(!viewModel.showsMatches)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .toast($viewModel.toast)
        .navigationTitle("그리기")  // 상세 화면의 뒤로 버튼 이름
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.start() }
        .task { await viewModel.refreshProgress() }  // 탭을 오갈 때마다 다시 읽는다
        .onChange(of: viewModel.canvasResetCount) {
            canvas.clear()
            canvas.select(.pen)
        }
    }

    /// 위 최근 · 캔버스 · 도구 바 · 하단 결과 시트(일반 iPhone, Duo 닫힘·펼침)
    @ViewBuilder
    private func compactLayout(_ proxy: GeometryProxy) -> some View {
        let showsStrip = viewModel.challengeTarget != nil || !viewModel.recentRecords.isEmpty
        let stripHeight = showsStrip ? recentStripHeight : 0
        let canvasSide = max(160, min(proxy.size.width - Spacing.screen * 2,
                                      proxy.size.height - stripHeight - Spacing.s - toolbarHeight - minimumSheetHeight))
        let collapsedSheetTop = stripHeight + Spacing.s + canvasSide + toolbarHeight

        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // 도전 중이면 목표 카드가 최근 스트립 자리를 대신한다(DESIGN_NOTES 3.3).
                if let target = viewModel.challengeTarget {
                    TargetBanner(symbolName: target, badge: viewModel.challengeBadge) { viewModel.endChallenge() }
                        .padding(.horizontal, Spacing.screen)
                        .frame(height: recentStripHeight)
                } else if !viewModel.recentRecords.isEmpty {
                    RecentStrip(records: viewModel.recentRecords) { viewModel.selectRecent($0) }
                        .frame(height: recentStripHeight)
                }
                DrawCanvasArea(
                    controller: canvas,
                    isEmpty: viewModel.sketch.isEmpty,
                    isTooSmall: viewModel.phase == .tooSmall,
                    onChange: { viewModel.sketchDidChange($0) }
                )
                .frame(width: canvasSide, height: canvasSide)
                .padding(.top, Spacing.s)

                DrawToolbar(canvas: canvas, phase: viewModel.phase, canSearch: viewModel.canSearch) {
                    viewModel.searchNow()
                }
                .padding(.horizontal, Spacing.screen)
                .frame(height: toolbarHeight)
            }
            .frame(maxWidth: .infinity)

            ResultSheet(viewModel: viewModel)
                .padding(.top, viewModel.isSheetExpanded ? Spacing.s : collapsedSheetTop)
        }
    }
}

#if DEBUG
#Preview("라이트") { DrawScreen(viewModel: DrawPreviewFixture.viewModel()).preferredColorScheme(.light) }
#Preview("다크") { DrawScreen(viewModel: DrawPreviewFixture.viewModel()).preferredColorScheme(.dark) }
#endif
