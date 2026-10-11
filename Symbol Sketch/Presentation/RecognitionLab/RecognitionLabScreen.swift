//
//  RecognitionLabScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

#if DEBUG
import SwiftUI
import Domain

/// 개발용 인식 실험 화면. DEBUG 빌드에서만 존재한다.
struct RecognitionLabScreen: View {
    @State private var viewModel: RecognitionLabViewModel
    @State private var canvas = SketchCanvasController()

    init(viewModel: RecognitionLabViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 12) {
            methodPicker
            preparationRow
            canvasArea
            toolBar
            results
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .navigationTitle("인식 실험")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var methodPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("인식 방식", selection: Binding(get: { viewModel.selectedID }, set: { viewModel.select($0) })) {
                ForEach(viewModel.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
            Text(viewModel.selected.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var preparationRow: some View {
        HStack(spacing: 12) {
            switch viewModel.selectedPreparation {
            case .unknown:
                ProgressView()
                Text("상태 확인 중")
            case .notReady:
                Text("심볼을 먼저 준비해야 해요")
                Spacer(minLength: 0)
                Button("준비하기") { viewModel.prepareSelected() }
                    .buttonStyle(.borderedProminent)
            case .preparing(let progress):
                ProgressView(value: progress)
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            case .ready(let seconds):
                Label("준비됨", systemImage: "checkmark.circle")
                if let seconds {
                    Text("준비에 \(seconds, format: .number.precision(.fractionLength(1)))초")
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            case .failed(let message):
                Label(message, systemImage: "xmark.octagon")
                    .foregroundStyle(.red)
                Spacer(minLength: 0)
                Button("다시 준비하기") { viewModel.prepareSelected() }
            }
        }
        .font(.subheadline)
        .frame(minHeight: 36)
    }

    private var canvasArea: some View {
        SketchCanvas(controller: canvas) { viewModel.sketchDidChange($0) }
            .aspectRatio(1, contentMode: .fit)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.separator))
            .frame(maxWidth: 480, maxHeight: 360)
    }

    private var toolBar: some View {
        HStack(spacing: 8) {
            Button { canvas.undo() } label: { Label("되돌리기", systemImage: "arrow.uturn.backward") }
                .disabled(!canvas.canUndo)
            Button { canvas.redo() } label: { Label("다시 하기", systemImage: "arrow.uturn.forward") }
                .disabled(!canvas.canRedo)
            Button(role: .destructive) { canvas.clear() } label: { Label("전체 지우기", systemImage: "trash") }
                .disabled(canvas.isEmpty)
            Spacer(minLength: 0)
            Button { viewModel.searchNow() } label: { Label("찾기", systemImage: "magnifyingglass") }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.borderedProminent)
                .disabled(canvas.isEmpty)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var results: some View {
        switch viewModel.searchState {
        case .idle:
            placeholder("그리면 0.6초 뒤에 자동으로 찾아요")
        case .notPrepared:
            placeholder("위에서 준비하기를 먼저 눌러 주세요")
        case .tooSmall:
            placeholder("조금 더 크게 그려 주세요")
        case .searching:
            placeholder("찾는 중…")
        case .failed(let message):
            placeholder(message)
        case .results(let matches, let milliseconds):
            List {
                Section {
                    ForEach(Array(matches.enumerated()), id: \.element.id) { rank, match in
                        ResultRow(rank: rank + 1, match: match)
                    }
                } footer: {
                    Text("검색 \(milliseconds)ms · 원점수는 보정 전 엔진 점수")
                }
            }
            .listStyle(.plain)
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ResultRow: View {
    let rank: Int
    let match: SymbolMatch

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 20)
            Image(systemName: match.name)
                .font(.title2)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.name)
                    .font(.body.monospaced())
                if !match.variants.isEmpty {
                    Text("변형 \(match.variants.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(match.similarity)%")
                    .font(.headline.monospacedDigit())
                Text(match.score, format: .number.precision(.fractionLength(3)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

private struct PreviewPrepare: PrepareSymbolIndexUseCase {
    func status() async -> SymbolIndexStatus { .ready(symbolCount: 3) }
    func execute() -> AsyncThrowingStream<Double, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct PreviewSearch: SearchSymbolsUseCase {
    func execute(sketch: Sketch, limit: Int) async throws -> SearchOutcome {
        .results([
            SymbolMatch(name: "heart", variants: ["heart.fill"], similarity: 92, score: 0.91),
            SymbolMatch(name: "star", variants: [], similarity: 71, score: 0.82),
        ])
    }
}

private func previewScreen() -> some View {
    NavigationStack {
        RecognitionLabScreen(viewModel: RecognitionLabViewModel(options: [
            RecognitionEngineOption(id: "a", title: "A 윤곽", detail: "미리보기", prepare: PreviewPrepare(), search: PreviewSearch()),
            RecognitionEngineOption(id: "b", title: "B 채움", detail: "미리보기", prepare: PreviewPrepare(), search: PreviewSearch()),
        ]))
    }
}

#Preview("라이트") { previewScreen().preferredColorScheme(.light) }
#Preview("다크") { previewScreen().preferredColorScheme(.dark) }
#endif
