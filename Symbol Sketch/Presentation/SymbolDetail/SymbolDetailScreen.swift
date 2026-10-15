//
//  SymbolDetailScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 심볼 상세(S3). DESIGN_NOTES 4장 S3. 즐겨찾기 버튼은 넣지 않는다(계획서 7장 결정 1).
struct SymbolDetailScreen: View {
    @State private var viewModel: SymbolDetailViewModel

    init(viewModel: SymbolDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                EmptyStateView(systemImage: "exclamationmark.triangle", message: message)
            case .loaded(let detail):
                content(detail)
            }
        }
        .background(DSColor.bgGrouped)
        .navigationTitle(viewModel.selectedName)
        .navigationBarTitleDisplayMode(.inline)
        .toast($viewModel.toast)
        .task { await viewModel.load() }
    }

    private func content(_ detail: SymbolDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                PreviewCard(viewModel: viewModel)
                section("복사") { CopySection(viewModel: viewModel) }
                if viewModel.hasSketch, let sketch = viewModel.request.sketch {
                    section("내 그림과 비교") { CompareSection(viewModel: viewModel, sketch: sketch) }
                }
                if detail.variants.count > 1 {
                    section("변형") { VariantChips(viewModel: viewModel, variants: detail.variants) }
                }
                section("정보") { InfoSection(viewModel: viewModel) }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xxl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(DSFont.sectionHeader)
                .foregroundStyle(DSColor.textSecondary)
                .padding(.horizontal, Spacing.xs)
                .padding(.top, Spacing.m)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

// MARK: - 미리보기

private struct PreviewCard: View {
    @Bindable var viewModel: SymbolDetailViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize = Metrics.previewGlyph

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                DotGrid(spacing: 22)
                SymbolGlyph(name: viewModel.selectedName, mode: viewModel.renderingMode, weight: viewModel.weight)
                    .font(.system(size: glyphSize))
            }
            .frame(height: Metrics.previewHeight)
            .clipped()

            Divider().overlay(DSColor.separator)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // 이름 ↔ 보유 뱃지. 한 줄에 안 들어가면 뱃지를 이름 아래로 내린다.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                        name
                        Spacer(minLength: 0)
                        badgeLine
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        name
                        badgeLine
                    }
                }
                Text(viewModel.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(Spacing.l)

            VStack(alignment: .leading, spacing: Spacing.m) {
                Picker("렌더링 모드", selection: $viewModel.renderingMode) {
                    ForEach(SymbolDetailViewModel.RenderingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if dynamicTypeSize.isAccessibilitySize {
                    // 큰 글자: 이름·값을 위에, 슬라이더를 아래 전체 폭으로.
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        HStack {
                            weightLabel
                            Spacer(minLength: Spacing.s)
                            weightValue
                        }
                        weightSlider
                    }
                } else {
                    HStack(spacing: Spacing.m) {
                        weightLabel
                        weightSlider
                        weightValue.frame(minWidth: 78, alignment: .trailing)
                    }
                }
            }
            .padding([.horizontal, .bottom], Spacing.l)
        }
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.canvas))
    }

    private var weightLabel: some View {
        Text("웨이트").font(.subheadline).foregroundStyle(DSColor.textPrimary)
    }

    private var weightValue: some View {
        Text(viewModel.weight.displayName)
            .font(DSFont.code)
            .foregroundStyle(DSColor.textSecondary)
    }

    private var weightSlider: some View {
        Slider(
            value: Binding(
                get: { Double(viewModel.weight.rawValue) },
                set: { viewModel.weight = .init(rawValue: Int($0.rounded())) ?? .regular }
            ),
            in: 0...Double(SymbolDetailViewModel.Weight.allCases.count - 1),
            step: 1
        )
        .tint(DSColor.accent)
        .accessibilityLabel("웨이트")
        .accessibilityValue(viewModel.weight.displayName)
    }

    private var name: some View {
        Text(viewModel.selectedName)
            .font(DSFont.symbolNameLarge)
            .foregroundStyle(DSColor.textPrimary)
            .textSelection(.enabled)
    }

    /// "{등급} 뱃지 보유 · 최고 {n}%" + 14pt 등급 점(DESIGN_NOTES S3)
    @ViewBuilder private var badgeLine: some View {
        if let badge = viewModel.selectedBadge, let text = viewModel.badgeText {
            HStack(spacing: Spacing.xs) {
                BadgeDot(tier: badge.tier, size: 14)
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize()
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// 렌더링 모드·웨이트를 적용한 심볼 글리프
struct SymbolGlyph: View {
    let name: String
    var mode: SymbolDetailViewModel.RenderingMode = .monochrome
    var weight: SymbolDetailViewModel.Weight = .regular

    var body: some View {
        let image = Image(systemName: name).fontWeight(weight.fontWeight)
        switch mode {
        case .monochrome:
            image.symbolRenderingMode(.monochrome).foregroundStyle(DSColor.textPrimary)
        case .hierarchical:
            image.symbolRenderingMode(.hierarchical).foregroundStyle(DSColor.textPrimary)
        case .palette:
            image.symbolRenderingMode(.palette).foregroundStyle(DSColor.accent, DSColor.gold)
        case .multicolor:
            image.symbolRenderingMode(.multicolor).foregroundStyle(DSColor.accent)
        }
    }
}

// MARK: - 복사

private struct CopySection: View {
    let viewModel: SymbolDetailViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            ForEach(SymbolDetailViewModel.CopyKind.allCases) { kind in
                Button { viewModel.copy(kind) } label: {
                    HStack(spacing: Spacing.m) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(kind.title).font(.subheadline).foregroundStyle(DSColor.textSecondary)
                            Text(viewModel.code(for: kind))
                                .font(DSFont.code)
                                .foregroundStyle(DSColor.textPrimary)
                                // 큰 글자에서는 코드를 줄여 보이지 않고 여러 줄로 다 보여 준다.
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 0)
                        let copied = viewModel.recentlyCopied == kind
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(copied ? DSColor.onAccent : DSColor.accent)
                            .frame(width: 36, height: 36)
                            .background(copied ? DSColor.accent : DSColor.fill, in: Circle())
                            .animation(.easeOut(duration: 0.2), value: copied)
                    }
                    .padding(.horizontal, Spacing.l)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(kind.title) 복사: \(viewModel.code(for: kind))"))
                if kind != SymbolDetailViewModel.CopyKind.allCases.last {
                    Divider().overlay(DSColor.separator).padding(.leading, Spacing.l)
                }
            }
        }
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

// MARK: - 내 그림과 비교

private struct CompareSection: View {
    @Bindable var viewModel: SymbolDetailViewModel
    let sketch: Sketch
    @ScaledMetric(relativeTo: .largeTitle) private var compareGlyph = Metrics.compareGlyph

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Picker("비교 방식", selection: $viewModel.compareMode) {
                ForEach(SymbolDetailViewModel.CompareMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch viewModel.compareMode {
            case .sideBySide:
                HStack(spacing: Spacing.s + Spacing.xxs) {
                    tile(caption: viewModel.request.isPastSketch ? "당시 그림" : "내 그림") { sketchView(lineWidth: 4) }
                    tile(caption: "심볼") {
                        Image(systemName: viewModel.selectedName)
                            .font(.system(size: compareGlyph))
                            .foregroundStyle(DSColor.textPrimary)
                    }
                }
            case .overlay:
                ZStack {
                    Image(systemName: viewModel.selectedName)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(DSColor.accent.opacity(0.28))
                        .padding(Spacing.xxl)
                    sketchView(lineWidth: 4)
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 280)
                .background(DSColor.canvasBackground, in: RoundedRectangle(cornerRadius: Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(DSColor.separator))
                .frame(maxWidth: .infinity)
                .accessibilityElement()
                .accessibilityLabel(Text("내 그림과 \(viewModel.selectedName) 겹쳐 보기"))
            }

            if let similarity = viewModel.request.similarity {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(similarity.percentText)
                        .font(DSFont.similarityLarge)
                        .foregroundStyle(DSColor.textPrimary)
                    SimilarityBar(percent: similarity, height: 6)
                    if let caption = viewModel.similarityCaption {
                        Text(caption).font(.footnote).foregroundStyle(DSColor.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Spacing.l)
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func sketchView(lineWidth: CGFloat) -> some View {
        SketchShape(sketch: sketch)
            .stroke(DSColor.canvasInk, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    private func tile(caption: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: Spacing.xs) {
            content()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(DSColor.canvasBackground, in: RoundedRectangle(cornerRadius: Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(DSColor.separator))
            Text(caption).font(.caption).foregroundStyle(DSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 변형

private struct VariantChips: View {
    let viewModel: SymbolDetailViewModel
    let variants: [SymbolMeta]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(variants) { variant in
                    let isSelected = variant.name == viewModel.selectedName
                    Button { viewModel.selectVariant(variant.name) } label: {
                        Label(variant.name, systemImage: variant.name)
                            .font(DSFont.code.weight(.semibold))
                            .foregroundStyle(isSelected ? DSColor.bgPrimary : DSColor.textPrimary)
                            .padding(.horizontal, Spacing.m)
                            .frame(minHeight: Metrics.minTapTarget)
                            .background(isSelected ? DSColor.textPrimary : DSColor.fill, in: RoundedRectangle(cornerRadius: Radius.tile))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - 정보

private struct InfoSection: View {
    let viewModel: SymbolDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            row("카테고리") {
                Text(viewModel.categoryNames.isEmpty ? String(localized: "없음") : viewModel.categoryNames.joined(separator: ", "))
            }
            Divider().overlay(DSColor.separator).padding(.leading, Spacing.l)
            if let keywords = viewModel.selectedSymbol?.keywords, !keywords.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("키워드").font(.body).foregroundStyle(DSColor.textPrimary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs + Spacing.xxs) {
                            ForEach(keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.footnote)
                                    .foregroundStyle(DSColor.textPrimary)
                                    .padding(.horizontal, Spacing.s)
                                    .padding(.vertical, Spacing.xxs + 1)
                                    .background(DSColor.fill, in: RoundedRectangle(cornerRadius: Radius.chip))
                            }
                        }
                    }
                }
                .padding(Spacing.l)
                Divider().overlay(DSColor.separator).padding(.leading, Spacing.l)
            }
            row("최소 지원 OS") {
                Text("iOS \(viewModel.selectedSymbol?.minOS ?? "")")
            }
        }
        .background(DSColor.cell, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func row(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(title).foregroundStyle(DSColor.textPrimary)
            Spacer()
            value().foregroundStyle(DSColor.textSecondary).multilineTextAlignment(.trailing)
        }
        .font(.body)
        .padding(.horizontal, Spacing.l)
        .frame(minHeight: Metrics.minTapTarget + 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 표시 이름

extension SymbolDetailViewModel.RenderingMode {
    var title: LocalizedStringKey {
        switch self {
        case .monochrome: "모노크롬"
        case .hierarchical: "계층"
        case .palette: "팔레트"
        case .multicolor: "멀티컬러"
        }
    }
}

extension SymbolDetailViewModel.CompareMode {
    var title: LocalizedStringKey {
        switch self {
        case .sideBySide: "나란히"
        case .overlay: "겹쳐 보기"
        }
    }
}

extension SymbolDetailViewModel.CopyKind {
    var title: String {
        switch self {
        case .name: String(localized: "이름")
        case .swiftUI: "SwiftUI"
        case .uiKit: "UIKit"
        }
    }
}

extension SymbolDetailViewModel.Weight {
    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

// MARK: - Preview

private struct PreviewDetail: GetSymbolDetailUseCase {
    func execute(name: String) async throws -> SymbolDetail {
        let heart = SymbolMeta(name: "heart", family: "heart", categories: ["health"], keywords: ["love", "medical"], minOS: "13.0")
        let fill = SymbolMeta(name: "heart.fill", family: "heart", categories: ["health"], keywords: ["love", "medical"], minOS: "13.0")
        return SymbolDetail(symbol: heart, variants: [heart, fill], categories: [SymbolCategory(key: "health", label: "Health", icon: "heart")])
    }
}

private struct PreviewBadges: FetchBadgesUseCase {
    func execute() async throws -> [String: SymbolBadge] {
        ["heart": SymbolBadge(symbolName: "heart", tier: .silver, bestSimilarity: 92, bestSketch: .empty, earnedAt: .now)]
    }
}

private struct PreviewPasteboard: PasteboardClient { func copy(_ text: String) {} }
private struct PreviewHaptics: HapticsClient { func lightImpact() {}; func success() {} }

private func previewScreen() -> some View {
    NavigationStack {
        SymbolDetailScreen(viewModel: SymbolDetailViewModel(
            request: SymbolDetailRequest(name: "heart", sketch: .exampleHeart, similarity: 92),
            getDetail: PreviewDetail(),
            fetchBadges: PreviewBadges(),
            pasteboard: PreviewPasteboard(),
            haptics: PreviewHaptics()
        ))
    }
}

#Preview("라이트") { previewScreen().preferredColorScheme(.light) }
#Preview("다크") { previewScreen().preferredColorScheme(.dark) }
