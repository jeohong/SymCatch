//
//  FlowLayout.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import SwiftUI

/// 줄바꿈 배치: 왼쪽부터 채우고 폭이 모자라면 다음 줄로(Duo 오른쪽 열의 최근 칩, DESIGN_NOTES 3.3).
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = fittedSize(subviews[index], maxWidth: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// 한 칸이 줄 폭보다 길면 줄 폭에 맞춘다(칩 이름은 말줄임).
    private func fittedSize(_ subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard ideal.width > maxWidth else { return ideal }
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = fittedSize(subviews[index], maxWidth: maxWidth)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

private func flowLayoutPreview() -> some View {
    FlowLayout {
        ForEach(["heart.fill", "magnifyingglass", "bell.fill", "star.fill", "cloud.fill"], id: \.self) { name in
            Label(name, systemImage: name)
                .font(DSFont.symbolNameSmall)
                .padding(Spacing.s)
                .background(DSColor.bgSecondary, in: RoundedRectangle(cornerRadius: Radius.button))
        }
    }
    .frame(width: 360)
    .padding()
    .background(DSColor.bgPrimary)
}

#Preview("라이트") { flowLayoutPreview().preferredColorScheme(.light) }
#Preview("다크") { flowLayoutPreview().preferredColorScheme(.dark) }
