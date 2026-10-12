//
//  EvaluationCollectionScreen.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

#if DEBUG
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Domain

/// 개발용 수집 모드 화면. DEBUG 빌드에서만 존재한다.
struct EvaluationCollectionScreen: View {
    @State private var viewModel: EvaluationCollectionViewModel
    @State private var canvas = SketchCanvasController()
    @State private var isSharing = false
    @State private var isImporting = false
    @AppStorage("evaluation.author") private var author = ""

    init(viewModel: EvaluationCollectionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // ScrollView로 감싸면 캔버스에서 끄는 동작이 스크롤로 처리돼 그림이 그려지지 않는다.
        // 캔버스가 남는 공간을 차지하도록 고정 배치한다.
        VStack(spacing: 12) {
            authorField
            targetCard
            canvasArea
            toolBar
            actionButtons
            feedbackText
        }
        .padding(16)
        .navigationTitle("평가셋 수집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.export()
                        isSharing = viewModel.exportedFile != nil
                    }
                } label: {
                    Label("내보내기", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.progress.overallTotal == 0 || viewModel.isBusy)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isImporting = true
                } label: {
                    Label("가져오기", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.isBusy)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            Task { await viewModel.importArchive(from: url, author: author) }
        }
        .sheet(isPresented: $isSharing) {
            if let file = viewModel.exportedFile {
                ActivityView(items: [file])
            }
        }
        .task { await viewModel.load(author: author) }
        .onChange(of: author) { _, newValue in
            Task { await viewModel.authorDidChange(newValue) }
        }
        .onChange(of: viewModel.canvasResetCount) {
            canvas.clear()
        }
    }

    private var authorField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("그린 사람 이름", text: $author)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("authorField")
            Text("내 그림 \(viewModel.progress.authorTotal) / \(viewModel.progress.authorGoal) · 전체 \(viewModel.progress.overallTotal)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var targetCard: some View {
        if let target = viewModel.target {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("이 심볼을 기억으로 그려 주세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(target)
                        .font(.title3.monospaced().bold())
                        .accessibilityIdentifier("targetName")
                }
                Spacer(minLength: 0)
                if viewModel.isHintVisible {
                    Image(systemName: target)
                        .font(.title)
                        .accessibilityLabel(target)
                }
                Toggle("모양 보기", isOn: $viewModel.isHintVisible)
                    .toggleStyle(.button)
                    .font(.subheadline)
            }
            .padding(12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        } else {
            Text("모든 심볼을 다 그렸어요. 내보내기로 평가셋을 옮겨 주세요.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(16)
        }
    }

    private var canvasArea: some View {
        SketchCanvas(controller: canvas) { viewModel.sketchDidChange($0) }
            .aspectRatio(1, contentMode: .fit)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.separator))
            .frame(maxWidth: 560, maxHeight: .infinity)
            .layoutPriority(1)
    }

    private var toolBar: some View {
        HStack(spacing: 8) {
            Button { canvas.undo() } label: { Label("되돌리기", systemImage: "arrow.uturn.backward") }
                .disabled(!canvas.canUndo)
            Button { canvas.redo() } label: { Label("다시 하기", systemImage: "arrow.uturn.forward") }
                .disabled(!canvas.canRedo)
            Button { canvas.toggleTool() } label: {
                Label(canvas.tool == .eraser ? "펜" : "지우개", systemImage: canvas.tool == .eraser ? "pencil.tip" : "eraser")
            }
            Button(role: .destructive) { canvas.clear() } label: { Label("전체 지우기", systemImage: "trash") }
                .disabled(canvas.isEmpty)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("건너뛰기") { viewModel.skip() }
                .buttonStyle(.bordered)
                .disabled(viewModel.target == nil)
            Button("저장하고 다음") {
                Task { await viewModel.save(author: author) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSave || author.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("saveButton")
        }
        .controlSize(.large)
    }

    @ViewBuilder
    private var feedbackText: some View {
        switch viewModel.feedback {
        case .saved:
            Label("저장했어요", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .tooSmall:
            Label("조금 더 크게 그려 주세요", systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
        case .imported(let count):
            Label("그림 \(count)장을 가져왔어요", systemImage: "square.and.arrow.down")
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon")
                .foregroundStyle(.red)
        case nil:
            if author.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("저장하려면 그린 사람 이름을 입력하세요")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 공유 시트(AirDrop으로 Mac에 옮기기 위함)
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

private struct PreviewProgressUseCase: LoadEvaluationProgressUseCase {
    func execute(author: String) async throws -> EvaluationProgress {
        EvaluationProgress(countsByTarget: ["circle": 3, "square": 1], authorTotal: 4, overallTotal: 10, authorGoal: 300)
    }
}

private struct PreviewSaveUseCase: SaveEvaluationSampleUseCase {
    func execute(symbolName: String, sketch: Sketch, author: String, now: Date) async throws {}
}

private struct PreviewExportUseCase: ExportEvaluationSamplesUseCase {
    func execute() async throws -> URL { URL(fileURLWithPath: "/tmp/preview.json") }
}

private struct PreviewImportUseCase: ImportEvaluationSamplesUseCase {
    func execute(from url: URL) async throws -> Int { 0 }
}

private func previewScreen() -> some View {
    NavigationStack {
        EvaluationCollectionScreen(viewModel: EvaluationCollectionViewModel(
            loadProgress: PreviewProgressUseCase(),
            saveSample: PreviewSaveUseCase(),
            exportSamples: PreviewExportUseCase(),
            importSamples: PreviewImportUseCase()
        ))
    }
}

#Preview("라이트") { previewScreen().preferredColorScheme(.light) }
#Preview("다크") { previewScreen().preferredColorScheme(.dark) }
#endif
