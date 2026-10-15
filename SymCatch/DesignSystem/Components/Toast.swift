//
//  Toast.swift
//  SymCatch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 화면 아래에 잠깐 뜨는 알림(예: "복사했어요"). 1.6초 뒤 사라진다(DESIGN_NOTES 3.13).
struct ToastMessage: Equatable, Identifiable {
    let id = UUID()
    let text: String
    var systemImage = "checkmark.circle.fill"
}

private struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Label(message.text, systemImage: message.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSColor.bgPrimary)
                    .padding(.vertical, Spacing.m - 1)
                    .padding(.horizontal, Spacing.l + Spacing.xxs)
                    .background(DSColor.textPrimary, in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 8)
                    .padding(.bottom, Spacing.l)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
                    .task(id: message.id) {
                        AccessibilityNotification.Announcement(message.text).post()
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.easeOut(duration: 0.25)) { self.message = nil }
                    }
            }
        }
        .animation(.easeOut(duration: 0.25), value: message)
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

#Preview("라이트") {
    Color.clear.toast(.constant(ToastMessage(text: "복사했어요"))).preferredColorScheme(.light)
}

#Preview("다크") {
    Color.clear.toast(.constant(ToastMessage(text: "복사했어요"))).preferredColorScheme(.dark)
}
