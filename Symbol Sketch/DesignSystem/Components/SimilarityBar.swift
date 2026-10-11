//
//  SimilarityBar.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 0~100% 유사도 막대. 90% 미만 accent, 이상 gold(기획서 7.3).
struct SimilarityBar: View {
    let percent: Int
    var height: CGFloat = Metrics.barHeight

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DSColor.bgTertiary)
                Capsule()
                    .fill(DSColor.similarity(percent))
                    .frame(width: proxy.size.width * CGFloat(min(max(percent, 0), 100)) / 100)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

#Preview("라이트") {
    VStack(spacing: Spacing.m) {
        SimilarityBar(percent: 45)
        SimilarityBar(percent: 92)
    }
    .frame(width: Metrics.barWidth)
    .padding()
    .preferredColorScheme(.light)
}

#Preview("다크") {
    VStack(spacing: Spacing.m) {
        SimilarityBar(percent: 45)
        SimilarityBar(percent: 92)
    }
    .frame(width: Metrics.barWidth)
    .padding()
    .preferredColorScheme(.dark)
}
