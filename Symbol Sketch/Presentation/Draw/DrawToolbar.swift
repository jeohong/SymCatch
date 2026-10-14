//
//  DrawToolbar.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 캔버스 아래 도구 바: 되돌리기 · 다시 하기 · 지우개 · 전체 지우기 + 찾기 버튼(DESIGN_NOTES 3.2).
struct DrawToolbar: View {
    let canvas: SketchCanvasController
    let phase: DrawViewModel.Phase
    let canSearch: Bool
    let onSearch: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            SketchToolGroup(canvas: canvas)
            Spacer(minLength: 0)

            FindButton(phase: phase, isEnabled: canSearch, action: onSearch)
        }
        // 아이콘 위주의 바라 접근성 글자 크기에서는 더 키우지 않고, 길게 누르면 크게 보여 준다(Large Content Viewer).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// 도구 묶음: 되돌리기 · 다시 하기 · 지우개 · 전체 지우기(그리기·온보딩 연습 공용).
/// Duo 반쯤 접힘에서는 캔버스 오른쪽 세로 열(48pt, 묶음 바탕 없음, DESIGN_NOTES 3.2).
struct SketchToolGroup: View {
    let canvas: SketchCanvasController
    var axis: Axis = .horizontal
    var buttonSize: CGFloat = Metrics.toolButton

    var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 0))
            : AnyLayout(VStackLayout(spacing: Spacing.xs))
        layout {
            ToolButton(title: "되돌리기", systemImage: "arrow.uturn.backward", size: buttonSize, isEnabled: canvas.canUndo) { canvas.undo() }
            ToolButton(title: "다시 하기", systemImage: "arrow.uturn.forward", size: buttonSize, isEnabled: canvas.canRedo) { canvas.redo() }
            ToolButton(title: "지우개", systemImage: "eraser", size: buttonSize, isOn: canvas.tool == .eraser) { canvas.toggleTool() }
            ToolButton(title: "전체 지우기", systemImage: "trash", size: buttonSize, isEnabled: !canvas.isEmpty) { canvas.clear() }
        }
        .padding(axis == .horizontal ? Spacing.xxs : 0)
        .background(axis == .horizontal ? DSColor.bgSecondary : .clear, in: RoundedRectangle(cornerRadius: Radius.toolGroup))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

private struct ToolButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var size: CGFloat = Metrics.toolButton
    var isEnabled = true
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(isOn ? DSColor.bgPrimary : DSColor.textPrimary)
                .frame(width: size, height: size)
                .background(isOn ? DSColor.textPrimary : .clear, in: RoundedRectangle(cornerRadius: Radius.button))
                .opacity(isEnabled ? 1 : 0.3)
                // 배경이 투명해도 44pt 틀 전체가 눌리게 한다.
                .contentShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer()
        .disabled(!isEnabled)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isOn)
    }
}

/// 찾기 버튼: 찾기 / 곧 찾아요(0.6초 채움) / 찾는 중 / 비활성.
/// Duo 반쯤 접힘에서는 오른쪽 열 아래 전체 폭, 높이 50(DESIGN_NOTES 3.2).
struct FindButton: View {
    let phase: DrawViewModel.Phase
    let isEnabled: Bool
    var height: CGFloat = Metrics.primaryButtonHeight
    var fillsWidth = false
    let action: () -> Void

    @State private var pendingFill: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s - 1) {
                if case .searching = phase {
                    ProgressView().tint(DSColor.onAccent)
                } else {
                    Image(systemName: "magnifyingglass")
                }
                Text(title)
            }
            .font(.headline)
            .padding(.leading, Spacing.l)
            .padding(.trailing, Spacing.l + Spacing.xs)
            .frame(minWidth: 104, maxWidth: fillsWidth ? .infinity : nil, minHeight: height)
            .foregroundStyle(isEnabled ? DSColor.onAccent : DSColor.textSecondary)
            .background(alignment: .leading) {
                ZStack(alignment: .leading) {
                    isEnabled ? DSColor.accent : DSColor.bgTertiary
                    if phase == .waiting {
                        GeometryReader { proxy in
                            DSColor.pending.frame(width: proxy.size.width * pendingFill)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.toolGroup))
            }
            .shadow(color: isEnabled ? DSColor.accent.opacity(0.3) : .clear, radius: 8, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityShowsLargeContentViewer {
            Label(title, systemImage: "magnifyingglass")
        }
        .onChange(of: phase) { _, newPhase in
            guard newPhase == .waiting else { return }
            pendingFill = 0
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 0.6)) { pendingFill = 1 }
        }
    }

    private var title: LocalizedStringKey {
        switch phase {
        case .waiting: "곧 찾아요"
        case .searching: "찾는 중"
        default: "찾기"
        }
    }
}

private func drawToolbarPreview() -> some View {
    VStack(spacing: Spacing.l) {
        DrawToolbar(canvas: SketchCanvasController(), phase: .idle, canSearch: false) {}
        DrawToolbar(canvas: SketchCanvasController(), phase: .waiting, canSearch: true) {}
        DrawToolbar(canvas: SketchCanvasController(), phase: .searching(showsSkeleton: true), canSearch: true) {}
    }
    .padding(Spacing.screen)
    .background(DSColor.bgPrimary)
}

#Preview("라이트") { drawToolbarPreview().preferredColorScheme(.light) }
#Preview("다크") { drawToolbarPreview().preferredColorScheme(.dark) }
