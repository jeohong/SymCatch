//
//  BadgeDetailViewModel.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 뱃지 상세(S7): 등급·획득일·최고 유사도·당시 그림, 다음 등급 안내, 도전하기(DESIGN_NOTES S7).
@MainActor @Observable
final class BadgeDetailViewModel {
    let symbolName: String
    /// 받은 뱃지. nil이면 미획득(실루엣)
    private(set) var badge: SymbolBadge?
    private(set) var isLoaded = false

    private let fetchBadges: any FetchBadgesUseCase
    private weak var navigator: (any CollectionNavigating)?

    init(symbolName: String, fetchBadges: any FetchBadgesUseCase, navigator: (any CollectionNavigating)?) {
        self.symbolName = symbolName
        self.fetchBadges = fetchBadges
        self.navigator = navigator
    }

    func load() async {
        badge = try? await fetchBadges.execute()[symbolName]
        isLoaded = true
    }

    // MARK: - 표시용 값

    /// 다음 등급 안내
    var goalText: String {
        guard let tier = badge?.tier else {
            return String(localized: "유사도 \(BadgeTier.bronze.minimumSimilarity.percentText) 이상이면 브론즈 뱃지를 얻어요")
        }
        guard let next = tier.next else { return String(localized: "최고 등급을 달성했어요") }
        if next.minimumSimilarity >= 100 {
            return String(localized: "\(next.minimumSimilarity.percentText)를 달성하면 \(next.displayName)로 승급해요")
        }
        return String(localized: "\(next.minimumSimilarity.percentText) 이상이면 \(next.displayName)로 승급해요")
    }

    /// 최고 등급(레전더리)이면 더 도전할 등급이 없다.
    var canChallenge: Bool { badge.map { $0.tier.next != nil } ?? true }

    var challengeTitle: String {
        badge == nil ? String(localized: "그려서 도전하기") : String(localized: "더 높은 등급에 도전")
    }

    // MARK: - 입력

    /// 도전하기: 그리기 탭으로 가서 이 심볼을 목표로 띄운다.
    func challenge() {
        navigator?.startChallenge(symbolName: symbolName)
    }

    /// 심볼 상세(S3)로. 뱃지가 있으면 그때 그림과 유사도를 함께 넘긴다(계획서 7장 결정 6).
    func showSymbolDetail() {
        navigator?.showCollectionSymbolDetail(SymbolDetailRequest(
            name: symbolName,
            sketch: badge?.bestSketch,
            similarity: badge?.bestSimilarity,
            isPastSketch: badge != nil
        ))
    }
}
