//
//  RecentStrip.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 홈 상단 최근 찾은 심볼 5개(DESIGN_NOTES 3.3). 기록이 없으면 부르는 쪽에서 숨긴다.
struct RecentStrip: View {
    let records: [FoundRecord]
    /// 좌우 여백(화면 가장자리면 16, iPad 캔버스 열 안이면 0)
    var leadingInset: CGFloat = Spacing.screen
    let onSelect: (FoundRecord) -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            Text("최근")
                .font(DSFont.sectionHeader)
                .foregroundStyle(DSColor.textSecondary)
                .padding(.leading, leadingInset)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(records) { record in
                        RecentChip(record: record) { onSelect(record) }
                    }
                }
                .padding(.trailing, leadingInset)
            }
        }
        .frame(minHeight: Metrics.minTapTarget)
    }
}

/// 최근 찾은 심볼 칩(홈 상단 스트립 · Duo 반쯤 접힘 오른쪽 열 공용, DESIGN_NOTES 3.3)
struct RecentChip: View {
    let record: FoundRecord
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 32

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: record.symbolName)
                    .font(.system(size: glyphSize))
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(width: tileSize, height: tileSize)
                    .background(DSColor.bgPrimary, in: RoundedRectangle(cornerRadius: Radius.chip + 2))
                Text(record.symbolName)
                    .font(DSFont.symbolNameSmall)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
            }
            .padding(.leading, Spacing.xs + Spacing.xxs)
            .padding(.trailing, Spacing.m)
            .frame(minHeight: Metrics.minTapTarget)
            .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(record.symbolName)
    }
}

private let previewRecords = ["heart", "star.fill", "cloud.sun", "bolt", "paperplane"].enumerated().map { index, name in
    FoundRecord(symbolName: name, sketch: .empty, similarity: 90 - index, foundAt: .now)
}

#Preview("라이트") { RecentStrip(records: previewRecords) { _ in }.preferredColorScheme(.light) }
#Preview("다크") { RecentStrip(records: previewRecords) { _ in }.background(DSColor.bgPrimary).preferredColorScheme(.dark) }
