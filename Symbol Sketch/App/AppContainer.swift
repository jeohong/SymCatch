//
//  AppContainer.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain
import Storage
import Recognition

/// 객체 조립(DI)을 하는 유일한 곳. 저장소·인식 엔진·UseCase를 만들고 ViewModel에 넘긴다.
/// Presentation 코드는 이 타입을 직접 참조하지 않고, 생성자로 UseCase만 받는다.
final class AppContainer {
    let symbolCatalog: any SymbolCatalogRepository
    let evaluationSamples: any EvaluationSampleRepository
    /// 심볼 인덱스 파일을 두는 폴더(방식마다 파일 하나)
    let indexDirectory: URL

    init(symbolCatalog: any SymbolCatalogRepository, evaluationSamples: any EvaluationSampleRepository, indexDirectory: URL) {
        self.symbolCatalog = symbolCatalog
        self.evaluationSamples = evaluationSamples
        self.indexDirectory = indexDirectory
    }

    /// 인식 엔진은 한 번만 만들어 앱이 살아 있는 동안 유지한다(준비한 인덱스·윤곽선을 다시 만들지 않기 위함).
    private lazy var recognitionEngines: [RecognitionEngineOption] = RecognitionMethod.allCases.map { makeEngineOption($0) }

    static func live() -> AppContainer {
        guard let catalogURL = Bundle.main.url(forResource: "symbols", withExtension: "json") else {
            fatalError("symbols.json이 앱 번들에 없습니다. Tools/extract_symbols.swift를 실행하세요.")
        }
        let support = URL.applicationSupportDirectory
        return AppContainer(
            symbolCatalog: BundledSymbolCatalogRepository(fileURL: catalogURL),
            evaluationSamples: FileEvaluationSampleRepository(directory: support.appending(path: "EvaluationSamples")),
            indexDirectory: support.appending(path: "SymbolIndex")
        )
    }

    /// Preview용: 앱 데이터와 섞이지 않도록 임시 폴더를 쓴다.
    static func preview() -> AppContainer {
        let temporary = URL.temporaryDirectory.appending(path: "Preview-\(UUID().uuidString)")
        return AppContainer(
            symbolCatalog: BundledSymbolCatalogRepository(fileURL: temporary.appending(path: "symbols.json")),
            evaluationSamples: FileEvaluationSampleRepository(directory: temporary.appending(path: "EvaluationSamples")),
            indexDirectory: temporary.appending(path: "SymbolIndex")
        )
    }

    // MARK: - ViewModel 팩토리

    func makeEvaluationCollectionViewModel() -> EvaluationCollectionViewModel {
        EvaluationCollectionViewModel(
            loadProgress: DefaultLoadEvaluationProgressUseCase(repository: evaluationSamples),
            saveSample: DefaultSaveEvaluationSampleUseCase(repository: evaluationSamples),
            exportSamples: DefaultExportEvaluationSamplesUseCase(repository: evaluationSamples)
        )
    }

    /// 화면을 나갔다 들어와도 준비 진행 상황이 이어지도록 하나만 만들어 재사용한다.
    func makeRecognitionLabViewModel() -> RecognitionLabViewModel {
        recognitionLab
    }

    private lazy var recognitionLab = RecognitionLabViewModel(options: recognitionEngines)

    // MARK: - 인식 엔진 조립

    private func makeEngineOption(_ method: RecognitionMethod) -> RecognitionEngineOption {
        let builder: any SymbolIndexBuilding
        let searcher: any SymbolSearching
        if let pipeline = method.embeddingPipeline {
            let store = SymbolIndexStore(fileURL: indexDirectory.appending(path: "\(method.rawValue).index"))
            builder = SymbolIndexBuilder(catalog: symbolCatalog, pipeline: pipeline, store: store)
            searcher = EmbeddingSymbolSearch(pipeline: pipeline, store: store, calibrator: method.provisionalCalibrator)
        } else {
            let chamfer = ChamferSymbolSearch(catalog: symbolCatalog, calibrator: method.provisionalCalibrator)
            builder = ChamferIndexPreparer(search: chamfer)
            searcher = chamfer
        }
        return RecognitionEngineOption(
            id: method.rawValue,
            title: method.title,
            detail: method.detail,
            prepare: DefaultPrepareSymbolIndexUseCase(builder: builder),
            search: DefaultSearchSymbolsUseCase(searcher: searcher)
        )
    }
}

private extension RecognitionMethod {
    var title: String {
        switch self {
        case .chamfer: String(localized: "A 윤곽 비교")
        case .visionFilled: String(localized: "B 채움")
        case .visionOutline: String(localized: "B 윤곽선")
        }
    }

    var detail: String {
        switch self {
        case .chamfer: String(localized: "모델 없이 선 사이 거리로 비교. 준비는 메모리에만(앱을 끄면 다시)")
        case .visionFilled: String(localized: "Vision 특징 벡터, 심볼을 채운 모양 그대로 비교")
        case .visionOutline: String(localized: "Vision 특징 벡터, 심볼을 윤곽선으로 바꿔 비교")
        }
    }
}
