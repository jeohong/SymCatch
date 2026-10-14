//
//  CelebrationOverlay.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 뱃지 획득 모달(S4). 화면 전체를 어둡게 덮고 가운데 카드 한 장을 띄운다(iPhone·iPad·Duo 공통 340pt).
/// 컨페티 1.5초, 동작 줄이기에서는 컨페티 없이 카드를 페이드로 보여 준다(기획서 3.1, 6장).
struct CelebrationOverlay: View {
    @State var viewModel: CelebrationViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isShown = false
    @State private var shareImage: Image?

    var body: some View {
        ZStack {
            DSColor.scrim
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // 큰 글자에서 카드가 화면보다 길면 스크롤한다(글자가 잘리지 않게).
            ViewThatFits(in: .vertical) {
                card
                ScrollView {
                    card.padding(.vertical, Spacing.xl)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
                .id(viewModel.index)
                .scaleEffect(isShown || reduceMotion ? 1 : 0.86)
                .offset(y: isShown || reduceMotion ? 0 : 28)
                .opacity(isShown ? 1 : 0)
                .padding(Spacing.l + Spacing.xs)

            if !reduceMotion {
                ConfettiView()
                    .ignoresSafeArea()
                    .id(viewModel.index)
            }
        }
        .onAppear {
            viewModel.appeared()
            show()
        }
        .onChange(of: viewModel.index) {
            isShown = false
            show()
        }
        .task(id: viewModel.index) { renderShareImage() }
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(spacing: Spacing.m) {
            if viewModel.pageCount > 1 {
                Text("\(viewModel.index + 1) / \(viewModel.pageCount)")
                    .font(.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, -Spacing.m)
            }
            BadgeCard(content: viewModel.current)
            buttons
        }
        .padding(.top, Spacing.xl)
        .padding(.horizontal, Spacing.l + Spacing.xs)
        .padding(.bottom, Spacing.l + Spacing.xs)
        .frame(maxWidth: 340)
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.3), radius: 40, y: 30)
    }

    private var buttons: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.s + Spacing.xxs))
            : AnyLayout(HStackLayout(spacing: Spacing.s + Spacing.xxs))
        return layout {
            if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview(shareTitle, image: shareImage)) {
                    Label("공유하기", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(DSColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: Metrics.largeButtonHeight)
                        .background(DSColor.bgTertiary, in: RoundedRectangle(cornerRadius: Radius.button))
                }
            }
            Button {
                viewModel.advance()
            } label: {
                Text(viewModel.isLastPage ? "확인" : "다음")
                    .font(.headline)
                    .foregroundStyle(DSColor.onAccent)
                    .frame(maxWidth: .infinity, minHeight: Metrics.largeButtonHeight)
                    .background(DSColor.accent, in: RoundedRectangle(cornerRadius: Radius.button))
            }
            .buttonStyle(.plain)
        }
    }

    private var shareTitle: String {
        switch viewModel.current {
        case .badge(let name, let tier, _, _, _, _): "\(name) · \(tier.displayName)"
        case .achievement(let id, _): id.displayName
        }
    }

    private func show() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { isShown = true }
        } else {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { isShown = true }
        }
    }

    /// 공유 이미지: 지금 테마로 카드 본문만 그린다(기획서 3.1).
    private func renderShareImage() {
        let content = BadgeCard(content: viewModel.current)
            .padding(Spacing.xl)
            .frame(width: 340)
            .background(DSColor.cell)
            .environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        shareImage = renderer.uiImage.map { Image(uiImage: $0) }
    }
}

private let previewSketch = Sketch(strokes: [[SketchPoint(x: 0.2, y: 0.2), SketchPoint(x: 0.8, y: 0.5), SketchPoint(x: 0.2, y: 0.8)]])

private struct PreviewHaptics: HapticsClient {
    func lightImpact() {}
    func success() {}
}

private func previewViewModel() -> CelebrationViewModel {
    let badge = SymbolBadge(symbolName: "play", tier: .gold, bestSimilarity: 98, bestSketch: previewSketch, earnedAt: .now)
    let outcome = SelectionOutcome(
        record: FoundRecord(symbolName: "play", sketch: previewSketch, similarity: 98, foundAt: .now),
        badgeAward: .newBadge(badge),
        newAchievements: [Achievement(id: .sharpshooter, progress: 1, unlockedAt: .now)]
    )
    return CelebrationViewModel(celebration: Celebration(outcome: outcome, sketch: previewSketch)!, haptics: PreviewHaptics()) {}
}

#Preview("라이트") { CelebrationOverlay(viewModel: previewViewModel()).preferredColorScheme(.light) }
#Preview("다크") { CelebrationOverlay(viewModel: previewViewModel()).preferredColorScheme(.dark) }
