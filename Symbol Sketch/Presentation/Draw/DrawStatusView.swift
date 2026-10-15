//
//  DrawStatusView.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import SwiftUI
import Domain

/// 결과 영역의 상태 표시(기획서 6장 공통 상태): 준비 중 · 오류 · 그림 부족 · 검색 실패 · 스켈레톤 · 빈 상태.
/// 결과 시트(compact)와 Duo 반쯤 접힘 결과 영역이 함께 쓴다. 결과 목록은 각 배치가 직접 그린다.
struct DrawStatusView: View {
    let viewModel: DrawViewModel

    var body: some View {
        switch viewModel.preparation {
        case .checking, .preparing:
            preparing
        case .failed:
            failure(String(localized: "심볼 인덱스를 읽지 못했어요")) {
                Button("다시 준비하기") { viewModel.retryPreparation() }
                    .buttonStyle(InvertedButtonStyle())
            }
        case .ready:
            readyContent
        }
    }

    @ViewBuilder
    private var readyContent: some View {
        switch viewModel.phase {
        case .tooSmall:
            message(String(localized: "조금 더 크게 그려 주세요"), detail: String(localized: "그림이 너무 작거나 획이 적어서 찾지 않았어요"))
        case .failed(let reason):
            message(String(localized: "찾지 못했어요"), detail: reason)
        case .searching(showsSkeleton: true) where viewModel.matches.isEmpty:
            SkeletonRows()
        default:
            #if DEBUG
            if let seconds = viewModel.preparationSeconds {
                // 개발용: 실기기 준비 시간 측정(출시 빌드에는 없음)
                Text(verbatim: "[DEBUG] 심볼 준비 시간 \(String(format: "%.1f", seconds))초")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(DSColor.danger)
                    .accessibilityIdentifier("debugPreparationSeconds")
            }
            #endif
            message(String(localized: "그림을 그리면 비슷한 심볼이\n여기에 나타나요"), detail: nil)
        }
    }

    private var preparing: some View {
        let progress: Double = if case .preparing(let value) = viewModel.preparation { value } else { 0 }
        return VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("심볼 준비 중").font(.subheadline)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.monospacedDigit())
            }
            .foregroundStyle(DSColor.textPrimary)
            ProgressView(value: progress)
                .tint(DSColor.accent)
            Text(viewModel.isRebuildingIndex ? "기기 안에서 심볼 인덱스를 다시 만들고 있어요" : "처음 한 번만 기기 안에서 심볼을 준비해요")
                .font(.footnote)
                .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.top, Spacing.s)
        .accessibilityElement(children: .combine)
    }

    private func message(_ title: String, detail: String?) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(.subheadline.weight(detail == nil ? .regular : .semibold))
                .foregroundStyle(detail == nil ? DSColor.textSecondary : DSColor.textPrimary)
            if let detail {
                Text(detail).font(.footnote).foregroundStyle(DSColor.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.l)
    }

    private func failure(_ title: String, @ViewBuilder action: () -> some View) -> some View {
        VStack(spacing: Spacing.m) {
            Text(title).font(.subheadline).foregroundStyle(DSColor.textPrimary)
            action()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.l)
    }
}

#if DEBUG
private func drawStatusPreview() -> some View {
    let viewModel = DrawPreviewFixture.viewModel(withSketch: false)
    return DrawStatusView(viewModel: viewModel)
        .padding(Spacing.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DSColor.bgSecondary)
        .task { await viewModel.start() }
}

#Preview("라이트") { drawStatusPreview().preferredColorScheme(.light) }
#Preview("다크") { drawStatusPreview().preferredColorScheme(.dark) }
#endif
