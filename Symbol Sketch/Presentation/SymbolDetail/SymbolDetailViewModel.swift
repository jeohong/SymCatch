//
//  SymbolDetailViewModel.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 심볼 상세(S3): 이름·코드 복사, 렌더링 모드·웨이트 미리보기, 변형 선택, 내 그림과 비교(기획서 2.3, 6장).
@MainActor @Observable
final class SymbolDetailViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded(SymbolDetail)
        case failed(String)
    }

    enum RenderingMode: CaseIterable, Identifiable {
        case monochrome, hierarchical, palette, multicolor
        var id: Self { self }
    }

    enum CompareMode: CaseIterable, Identifiable {
        case sideBySide, overlay
        var id: Self { self }
    }

    enum CopyKind: CaseIterable, Identifiable {
        case name, swiftUI, uiKit
        var id: Self { self }
    }

    /// 웨이트 9단계(Ultralight ~ Black). 기본 Regular.
    enum Weight: Int, CaseIterable {
        case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

        var displayName: String {
            switch self {
            case .ultraLight: "Ultralight"
            case .thin: "Thin"
            case .light: "Light"
            case .regular: "Regular"
            case .medium: "Medium"
            case .semibold: "Semibold"
            case .bold: "Bold"
            case .heavy: "Heavy"
            case .black: "Black"
            }
        }
    }

    let request: SymbolDetailRequest
    private(set) var loadState: LoadState = .loading
    /// 지금 보고 있는 변형 이름. 이름·복사 코드가 이 이름을 따른다.
    private(set) var selectedName: String
    var renderingMode: RenderingMode = .monochrome
    var weight: Weight = .regular
    var compareMode: CompareMode = .sideBySide
    var toast: ToastMessage?
    /// 방금 복사한 행(체크 표시용)
    private(set) var recentlyCopied: CopyKind?

    private let getDetail: any GetSymbolDetailUseCase
    private let fetchBadges: any FetchBadgesUseCase
    /// 심볼 이름 → 보유 뱃지
    private var badges: [String: SymbolBadge] = [:]
    private let pasteboard: any PasteboardClient
    private let haptics: any HapticsClient
    private var copiedResetTask: Task<Void, Never>?

    init(
        request: SymbolDetailRequest,
        getDetail: any GetSymbolDetailUseCase,
        fetchBadges: any FetchBadgesUseCase,
        pasteboard: any PasteboardClient,
        haptics: any HapticsClient
    ) {
        self.request = request
        self.selectedName = request.name
        self.getDetail = getDetail
        self.fetchBadges = fetchBadges
        self.pasteboard = pasteboard
        self.haptics = haptics
    }

    func load() async {
        // 뱃지를 못 읽어도 상세는 보여 준다.
        badges = (try? await fetchBadges.execute()) ?? [:]
        do {
            loadState = .loaded(try await getDetail.execute(name: request.name))
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    var detail: SymbolDetail? {
        if case .loaded(let detail) = loadState { detail } else { nil }
    }

    var selectedSymbol: SymbolMeta? {
        detail?.variants.first { $0.name == selectedName } ?? detail?.symbol
    }

    // MARK: - 변형

    func selectVariant(_ name: String) {
        guard detail?.variants.contains(where: { $0.name == name }) == true else { return }
        selectedName = name
        recentlyCopied = nil
    }

    // MARK: - 복사

    func code(for kind: CopyKind) -> String {
        switch kind {
        case .name: selectedName
        case .swiftUI: "Image(systemName: \"\(selectedName)\")"
        case .uiKit: "UIImage(systemName: \"\(selectedName)\")"
        }
    }

    func copy(_ kind: CopyKind) {
        pasteboard.copy(code(for: kind))
        haptics.lightImpact()
        toast = ToastMessage(text: String(localized: "복사했어요"))
        recentlyCopied = kind
        copiedResetTask?.cancel()
        copiedResetTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            recentlyCopied = nil
        }
    }

    // MARK: - 정보

    /// "건강 · iOS 13.0 이상"
    var summaryText: String {
        let os = String(localized: "iOS \(selectedSymbol?.minOS ?? "") 이상")
        guard let category = detail?.categories.first else { return os }
        return "\(SymbolCategoryNames.displayName(for: category)) · \(os)"
    }

    /// 지금 보고 있는 변형의 보유 뱃지
    var selectedBadge: SymbolBadge? { badges[selectedName] }

    /// "실버 뱃지 보유 · 최고 92%". 뱃지가 없으면 nil.
    var badgeText: String? {
        guard let badge = selectedBadge else { return nil }
        return String(localized: "\(badge.tier.displayName) 뱃지 보유 · 최고 \(badge.bestSimilarity.percentText)")
    }

    var categoryNames: [String] {
        detail?.categories.map(SymbolCategoryNames.displayName(for:)) ?? []
    }

    // MARK: - 내 그림과 비교

    var hasSketch: Bool { request.sketch.map { !$0.isEmpty } ?? false }

    /// 비교 영역 아래 설명(기획서 3.1 등급 구간)
    var similarityCaption: String? {
        guard let similarity = request.similarity else { return nil }
        guard let tier = BadgeTierPolicy.tier(for: similarity) else {
            return String(localized: "뱃지까지 \((BadgeTierPolicy.threshold - similarity).percentText) 남았어요")
        }
        return String(localized: "\(tier.displayName) 등급 구간이에요")
    }
}
