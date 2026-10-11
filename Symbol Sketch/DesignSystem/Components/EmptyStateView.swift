//
//  EmptyStateView.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 빈 상태: 안내 1줄 + 행동 버튼 1개(기획서 6장 공통 상태)
struct EmptyStateView: View {
    let systemImage: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(DSColor.textSecondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .foregroundStyle(DSColor.textPrimary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

/// accent 바탕의 주 버튼(높이 50, r12)
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? DSColor.onAccent : DSColor.textSecondary)
            .padding(.horizontal, Spacing.xl)
            .frame(minHeight: Metrics.largeButtonHeight)
            .background(isEnabled ? DSColor.accent : DSColor.bgTertiary, in: RoundedRectangle(cornerRadius: Radius.button))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("라이트") {
    EmptyStateView(systemImage: "clock.arrow.circlepath", message: "아직 찾은 심볼이 없어요", actionTitle: "그리러 가기") {}
        .preferredColorScheme(.light)
}

#Preview("다크") {
    EmptyStateView(systemImage: "clock.arrow.circlepath", message: "아직 찾은 심볼이 없어요", actionTitle: "그리러 가기") {}
        .preferredColorScheme(.dark)
}
