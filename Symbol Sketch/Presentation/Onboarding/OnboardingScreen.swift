//
//  OnboardingScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import SwiftUI
import Domain

/// 온보딩(S0). 첫 실행에만 전체 화면으로 덮는다(DESIGN_NOTES S0).
struct OnboardingScreen: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            switch viewModel.step {
            case .intro:
                IntroPages(viewModel: viewModel)
            case .practice:
                PracticeView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .background(DSColor.bgPrimary)
        .task { await viewModel.start() }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(viewModel.step == .practice ? "나중에 할게요" : "건너뛰기") { viewModel.skip() }
                .foregroundStyle(DSColor.textSecondary)
                .frame(minHeight: Metrics.minTapTarget)
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - 소개 3장

private struct IntroPages: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: Binding(get: { viewModel.introIndex }, set: { viewModel.showIntro($0) })) {
                IntroPage(title: String(localized: "그려서 찾기"),
                          message: String(localized: "이름이 떠오르지 않아도 괜찮아요. 모양을 대충 그리면 비슷한 SF Symbol을 찾아 드려요.")) {
                    DrawToFindIllustration()
                }
                .tag(0)
                IntroPage(title: String(localized: "유사도로 비교하기"),
                          message: String(localized: "그림과 가장 비슷한 심볼 10개를 유사도 순서로 보여 줘요. 원하는 심볼을 탭하면 이름과 코드를 바로 복사할 수 있어요.")) {
                    SimilarityIllustration()
                }
                .tag(1)
                IntroPage(title: String(localized: "\(BadgeTierPolicy.threshold.percentText) 넘으면 뱃지"),
                          message: String(localized: "유사도 \(BadgeTier.bronze.minimumSimilarity.percentText) 이상인 심볼을 고르면 뱃지를 얻어요. \(BadgeTier.silver.minimumSimilarity.percentText)는 실버, \(BadgeTier.gold.minimumSimilarity.percentText)는 골드, \(BadgeTier.legendary.minimumSimilarity.percentText)는 레전더리로 승급해요.")) {
                    BadgeTiersIllustration()
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeOut(duration: 0.25), value: viewModel.introIndex)

            // 큰 글자에서는 버튼을 페이지 표시 아래 전체 폭으로 내린다(버튼 글자가 잘리지 않게).
            let isLargeText = dynamicTypeSize.isAccessibilitySize
            let layout = isLargeText
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.m))
                : AnyLayout(HStackLayout())
            layout {
                PageDots(count: OnboardingViewModel.introCount, current: viewModel.introIndex)
                if !isLargeText { Spacer() }
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { viewModel.next() }
                } label: {
                    Text(viewModel.isLastIntro ? "연습해 보기" : "다음")
                        .frame(maxWidth: isLargeText ? .infinity : nil)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
    }
}

private struct IntroPage<Illustration: View>: View {
    let title: String
    let message: String
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                illustration()
                    // 장식 그림이라 접근성 글자 크기에서는 더 키우지 않는다(가로로 넘치지 않게).
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(maxWidth: .infinity, minHeight: 240)
                VStack(alignment: .leading, spacing: Spacing.s + Spacing.xxs) {
                    Text(title)
                        .font(.title.bold())
                        .foregroundStyle(DSColor.textPrimary)
                    Text(message)
                        .font(.body)
                        .lineSpacing(Spacing.xs)
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: Spacing.s - Spacing.xxs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? DSColor.textPrimary : DSColor.bgTertiary)
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.easeOut(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel(Text("\(current + 1) / \(count)"))
        .accessibilityAddTraits(.isStaticText)
    }
}

/// 1장: 손그림 하트 → heart.fill
private struct DrawToFindIllustration: View {
    @ScaledMetric(relativeTo: .largeTitle) private var tile: CGFloat = 132
    @ScaledMetric(relativeTo: .largeTitle) private var glyph: CGFloat = 64

    var body: some View {
        HStack(spacing: Spacing.m + Spacing.xxs) {
            ZStack {
                DotGrid(spacing: 18)
                SketchShape(sketch: .exampleHeart, marginRatio: 0.18)
                    .stroke(DSColor.canvasInk, style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
            }
            .frame(width: tile, height: tile)
            .background(DSColor.canvasBackground, in: RoundedRectangle(cornerRadius: Radius.canvas))
            .overlay(RoundedRectangle(cornerRadius: Radius.canvas).strokeBorder(DSColor.separator))

            Image(systemName: "arrow.right")
                .font(.title.weight(.semibold))
                .foregroundStyle(DSColor.textSecondary)

            VStack(spacing: Spacing.s) {
                Image(systemName: "heart.fill")
                    .font(.system(size: glyph))
                Text(verbatim: "heart.fill")
                    .font(DSFont.symbolNameSmall)
            }
            .foregroundStyle(DSColor.bgPrimary)
            .frame(width: tile, height: tile)
            .background(DSColor.textPrimary, in: RoundedRectangle(cornerRadius: Radius.canvas))
        }
        .accessibilityHidden(true)
    }
}

/// 2장: 유사도 순 결과 예시
private struct SimilarityIllustration: View {
    private let samples = [
        SymbolMatch(name: "heart.fill", variants: [], similarity: 92),
        SymbolMatch(name: "suit.heart.fill", variants: [], similarity: 88),
        SymbolMatch(name: "drop.fill", variants: [], similarity: 61),
    ]

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(Array(samples.enumerated()), id: \.offset) { index, match in
                SymbolResultRow(rank: index + 1, match: match, badgeHint: .none)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: 340)
        .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.panel))
        .accessibilityHidden(true)
    }
}

/// 3장: 등급 메달 4개. 좁거나 글자가 크면 2×2로.
private struct BadgeTiersIllustration: View {
    @ScaledMetric(relativeTo: .largeTitle) private var medal: CGFloat = 64

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.m) { medals }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.l) { medals }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var medals: some View {
        ForEach(BadgeTier.allCases, id: \.self) { tier in
            VStack(spacing: Spacing.s) {
                BadgeView(systemImage: "heart", style: .tier(tier), size: medal, ringWidth: 4)
                Text(tier.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .fixedSize()
                Text(tier.next == nil ? "\(tier.minimumSimilarity.percentText)" : "\(tier.minimumSimilarity.percentText) 이상")
                    .font(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize()
            }
        }
    }
}

// MARK: - 하트 연습

private struct PracticeView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var canvas = SketchCanvasController()
    @ScaledMetric(relativeTo: .body) private var canvasSide: CGFloat = 300

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("하트를 그려 보세요")
                        .font(.title.bold())
                        .foregroundStyle(DSColor.textPrimary)
                    Text("손을 떼면 0.6초 뒤에 자동으로 찾아요.")
                        .font(.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                }
                PreparationStatus(preparation: viewModel.indexPreparation)

                VStack(spacing: Spacing.m) {
                    DrawCanvasArea(controller: canvas, isEmpty: viewModel.sketch.isEmpty,
                                   isTooSmall: viewModel.phase == .tooSmall) { viewModel.sketchDidChange($0) }
                        .frame(width: min(canvasSide, 360), height: min(canvasSide, 360))
                    SketchToolGroup(canvas: canvas)
                }
                .frame(maxWidth: .infinity)

                results
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDisabled(true)
    }

    @ViewBuilder
    private var results: some View {
        switch viewModel.phase {
        case .idle, .waiting:
            EmptyView()
        case .waitingForIndex:
            hint(Text("심볼 준비가 끝나면 바로 찾을게요"))
        case .tooSmall:
            hint(Text("조금 더 크게 그려 주세요"))
        case .searching(let showsSkeleton):
            if showsSkeleton { SkeletonRows() }
        case .failed(let message):
            hint(Text(message))
        case .results:
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("찾은 심볼을 탭해 확인하세요")
                    .font(DSFont.sectionHeader)
                    .foregroundStyle(DSColor.textSecondary)
                VStack(spacing: Spacing.s) {
                    ForEach(Array(viewModel.matches.enumerated()), id: \.element.id) { index, match in
                        Button { viewModel.select(match) } label: {
                            SymbolResultRow(rank: index + 1, match: match, badgeHint: BadgeHint.evaluate(match, owned: nil))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.s)
                .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.panel))
            }
        }
    }

    private func hint(_ text: Text) -> some View {
        text
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity)
    }
}

/// "심볼 준비 중 · 62%" 막대 / "심볼 8,092개 준비 완료"
private struct PreparationStatus: View {
    let preparation: SymbolIndexPreparation

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s - Spacing.xxs) {
            switch preparation.state {
            case .checking, .preparing:
                let progress: Double = if case .preparing(let value) = preparation.state { value } else { 0 }
                Text("심볼 준비 중 · \(Int((progress * 100).rounded()).percentText)")
                    .font(DSFont.sectionHeader)
                    .foregroundStyle(DSColor.textSecondary)
                ProgressView(value: progress)
                    .tint(DSColor.accent)
            case .ready:
                Label(preparation.symbolCount.map { String(localized: "심볼 \($0.formatted())개 준비 완료") } ?? String(localized: "심볼 준비 완료"),
                      systemImage: "checkmark.circle.fill")
                    .font(DSFont.sectionHeader)
                    .foregroundStyle(DSColor.textSecondary)
            case .failed:
                HStack {
                    Text("심볼 인덱스를 읽지 못했어요")
                        .font(DSFont.sectionHeader)
                        .foregroundStyle(DSColor.danger)
                    Spacer()
                    Button("다시 준비하기") { preparation.retry() }
                        .font(DSFont.sectionHeader)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PreviewPrepare: PrepareSymbolIndexUseCase {
    func status() async -> SymbolIndexStatus { .missing }
    func execute() -> AsyncThrowingStream<Double, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(0.62)
        }
    }
}

private struct PreviewSearch: SearchSymbolsUseCase {
    func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome { .results([]) }
}

private struct PreviewSelect: SelectSymbolUseCase {
    func execute(match: SymbolMatch, sketch: Sketch, now: Date) async throws -> SelectionOutcome {
        SelectionOutcome(record: FoundRecord(symbolName: match.name, sketch: sketch, similarity: match.similarity, foundAt: now),
                         badgeAward: .none, newAchievements: [])
    }
}

private func previewViewModel() -> OnboardingViewModel {
    OnboardingViewModel(indexPreparation: SymbolIndexPreparation(prepareIndex: PreviewPrepare()), searchSymbols: PreviewSearch(),
                        selectSymbol: PreviewSelect(), navigator: nil)
}

#Preview("라이트") { OnboardingScreen(viewModel: previewViewModel()).preferredColorScheme(.light) }
#Preview("다크") { OnboardingScreen(viewModel: previewViewModel()).preferredColorScheme(.dark) }
