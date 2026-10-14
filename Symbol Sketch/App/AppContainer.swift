//
//  AppContainer.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import SwiftData
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
    // 기록·뱃지·업적·통계(SwiftData)
    let records: any FoundRecordRepository
    let badges: any BadgeRepository
    let achievements: any AchievementRepository
    let stats: any UserStatsRepository

    init(symbolCatalog: any SymbolCatalogRepository, evaluationSamples: any EvaluationSampleRepository, indexDirectory: URL,
         progressContainer: ModelContainer) {
        self.symbolCatalog = symbolCatalog
        self.evaluationSamples = evaluationSamples
        self.indexDirectory = indexDirectory
        records = SwiftDataFoundRecordRepository(modelContainer: progressContainer)
        badges = SwiftDataBadgeRepository(modelContainer: progressContainer)
        achievements = SwiftDataAchievementRepository(modelContainer: progressContainer)
        stats = SwiftDataUserStatsRepository(modelContainer: progressContainer)
    }

    /// 앱이 쓰는 인식 방식(계획서 7장 결정 7: B 윤곽선)
    static let recognitionMethod: RecognitionMethod = .visionOutline

    /// 탭·내비게이션 상태. 앱 전체에서 하나. UI 테스트는 실행 인자로 온보딩을 끄거나 켠다.
    let router = AppRouter(showsOnboarding: AppContainer.onboardingOverride)

    /// 인식 엔진은 한 번만 만들어 앱이 살아 있는 동안 유지한다(준비한 인덱스·윤곽선을 다시 만들지 않기 위함).
    /// 그리기 화면과 인식 실험이 같은 엔진을 공유한다.
    private lazy var recognitionEngines: [RecognitionEngineOption] = RecognitionMethod.allCases.map { makeEngineOption($0) }

    private var appEngine: RecognitionEngineOption {
        recognitionEngines.first { $0.id == Self.recognitionMethod.rawValue }!
    }

    static func live() -> AppContainer {
        guard let catalogURL = Bundle.main.url(forResource: "symbols", withExtension: "json") else {
            fatalError("symbols.json이 앱 번들에 없습니다. Tools/extract_symbols.swift를 실행하세요.")
        }
        let support = URL.applicationSupportDirectory
        return AppContainer(
            // 번들 목록은 최신 SF Symbols 기준이라, 이 기기 OS에 없는 심볼은 걸러서 쓴다.
            symbolCatalog: AvailableSymbolCatalog(base: BundledSymbolCatalogRepository(fileURL: catalogURL), os: currentOS),
            evaluationSamples: FileEvaluationSampleRepository(directory: support.appending(path: "EvaluationSamples")),
            indexDirectory: support.appending(path: "SymbolIndex"),
            progressContainer: makeProgressContainer(url: support.appending(path: "Progress.store"))
        )
    }

    /// 기록 저장소. UI 테스트는 매번 빈 상태에서 시작하도록 메모리에만 둔다.
    /// 파일을 열지 못하면(저장 형식 손상 등) 앱은 계속 쓸 수 있게 메모리 저장소로 연다.
    private static func makeProgressContainer(url: URL) -> ModelContainer {
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(uiTestingInMemoryArgument) {
                return try ProgressModelContainerFactory.inMemory()
            }
            #endif
            return try ProgressModelContainerFactory.live(url: url)
        } catch {
            do {
                return try ProgressModelContainerFactory.inMemory()
            } catch {
                fatalError("기록 저장소를 만들지 못했습니다: \(error)")
            }
        }
    }

    private static var currentOS: OSVersion {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return OSVersion(major: version.majorVersion, minor: version.minorVersion)
    }

    /// UI 테스트 실행 인자: 기록을 메모리에만 저장
    static let uiTestingInMemoryArgument = "-UITestingInMemoryProgress"
    /// UI 테스트 실행 인자: 온보딩 건너뛰기 / 항상 보이기
    static let uiTestingSkipOnboardingArgument = "-UITestingSkipOnboarding"
    static let uiTestingShowOnboardingArgument = "-UITestingShowOnboarding"

    /// UI 테스트에서만 온보딩 표시 여부를 정한다. 그 밖에는 nil(첫 실행 여부를 따름).
    private static var onboardingOverride: Bool? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(uiTestingShowOnboardingArgument) { return true }
        if arguments.contains(uiTestingSkipOnboardingArgument) { return false }
        #endif
        return nil
    }

    /// Preview용: 앱 데이터와 섞이지 않도록 임시 폴더를 쓴다.
    static func preview() -> AppContainer {
        let temporary = URL.temporaryDirectory.appending(path: "Preview-\(UUID().uuidString)")
        return AppContainer(
            symbolCatalog: BundledSymbolCatalogRepository(fileURL: temporary.appending(path: "symbols.json")),
            evaluationSamples: FileEvaluationSampleRepository(directory: temporary.appending(path: "EvaluationSamples")),
            indexDirectory: temporary.appending(path: "SymbolIndex"),
            progressContainer: try! ProgressModelContainerFactory.inMemory()
        )
    }

    /// 앱을 켤 때 한 번: 등급 기준이 바뀌기 전에 받은 뱃지의 등급을 최고 유사도에 맞춘다(올리기만 한다).
    func reconcileBadgeTiers() async {
        _ = try? await DefaultReconcileBadgeTiersUseCase(badges: badges).execute(now: .now)
    }

    /// 심볼 인덱스 준비. 그리기 화면과 온보딩이 같은 준비를 함께 쓴다(앱에 하나).
    private(set) lazy var indexPreparation = SymbolIndexPreparation(prepareIndex: drawPrepare)

    /// 그리기·온보딩이 쓰는 준비와 검색. UI 테스트는 실행 인자로 오류·느린 준비·느린 검색을 만든다.
    private var drawPrepare: any PrepareSymbolIndexUseCase {
        #if DEBUG
        UITestingStates.prepare(appEngine.prepare)
        #else
        appEngine.prepare
        #endif
    }

    private var drawSearch: any SearchSymbolsUseCase {
        #if DEBUG
        UITestingStates.search(appEngine.search)
        #else
        appEngine.search
        #endif
    }

    // MARK: - ViewModel 팩토리

    func makeDrawViewModel(navigator: any DrawNavigating) -> DrawViewModel {
        DrawViewModel(
            indexPreparation: indexPreparation,
            searchSymbols: drawSearch,
            selectSymbol: DefaultSelectSymbolUseCase(records: records, badges: badges, achievements: achievements, stats: stats),
            fetchRecent: DefaultFetchRecentRecordsUseCase(records: records),
            fetchBadges: DefaultFetchBadgesUseCase(badges: badges),
            navigator: navigator
        )
    }

    func makeRecentViewModel(navigator: any RecentNavigating) -> RecentViewModel {
        RecentViewModel(
            fetchRecent: DefaultFetchRecentRecordsUseCase(records: records),
            deleteRecords: DefaultDeleteRecordsUseCase(records: records),
            clearHistory: DefaultClearHistoryUseCase(records: records),
            fetchBadges: DefaultFetchBadgesUseCase(badges: badges),
            navigator: navigator
        )
    }

    func makeCollectionViewModel(navigator: any CollectionNavigating) -> CollectionViewModel {
        CollectionViewModel(
            fetchCollection: DefaultFetchCollectionUseCase(badges: badges, achievements: achievements, catalog: symbolCatalog),
            navigator: navigator
        )
    }

    func makeBadgeDetailViewModel(symbolName: String, navigator: any CollectionNavigating) -> BadgeDetailViewModel {
        BadgeDetailViewModel(symbolName: symbolName, fetchBadges: DefaultFetchBadgesUseCase(badges: badges), navigator: navigator)
    }

    func makeOnboardingViewModel(navigator: any OnboardingNavigating) -> OnboardingViewModel {
        OnboardingViewModel(
            indexPreparation: indexPreparation,
            searchSymbols: drawSearch,
            selectSymbol: DefaultSelectSymbolUseCase(records: records, badges: badges, achievements: achievements, stats: stats),
            navigator: navigator
        )
    }

    func makeSettingsViewModel(navigator: any SettingsNavigating) -> SettingsViewModel {
        SettingsViewModel(
            prepareIndex: appEngine.prepare,
            resetProgress: DefaultResetProgressUseCase(records: records, badges: badges, achievements: achievements, stats: stats),
            navigator: navigator,
            appVersion: Self.appVersion
        )
    }

    /// "1.0 (1)" = 버전 (빌드)
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    func makeCelebrationViewModel(celebration: Celebration, onFinish: @escaping () -> Void) -> CelebrationViewModel {
        CelebrationViewModel(celebration: celebration, haptics: SystemHaptics(), onFinish: onFinish)
    }

    func makeSymbolDetailViewModel(request: SymbolDetailRequest) -> SymbolDetailViewModel {
        SymbolDetailViewModel(
            request: request,
            getDetail: DefaultGetSymbolDetailUseCase(catalog: symbolCatalog),
            fetchBadges: DefaultFetchBadgesUseCase(badges: badges),
            pasteboard: SystemPasteboard(),
            haptics: SystemHaptics()
        )
    }

    func makeEvaluationCollectionViewModel() -> EvaluationCollectionViewModel {
        EvaluationCollectionViewModel(
            loadProgress: DefaultLoadEvaluationProgressUseCase(repository: evaluationSamples),
            saveSample: DefaultSaveEvaluationSampleUseCase(repository: evaluationSamples),
            exportSamples: DefaultExportEvaluationSamplesUseCase(repository: evaluationSamples),
            importSamples: DefaultImportEvaluationSamplesUseCase(repository: evaluationSamples)
        )
    }

    #if DEBUG
    /// 앱이 쓰는 방식(B 윤곽선)으로 평가한다. 화면을 나갔다 와도 결과가 남도록 하나만 만든다.
    func makeEvaluationRunViewModel() -> EvaluationRunViewModel {
        evaluationRun
    }

    private lazy var evaluationRun = EvaluationRunViewModel(
        prepareIndex: appEngine.prepare,
        runCalibration: DefaultRunCalibrationUseCase(samples: evaluationSamples, scorer: appEngine.scorer),
        currentCalibrator: appEngine.calibrator
    )
    #endif

    /// 화면을 나갔다 들어와도 준비 진행 상황이 이어지도록 하나만 만들어 재사용한다.
    func makeRecognitionLabViewModel() -> RecognitionLabViewModel {
        recognitionLab
    }

    private lazy var recognitionLab = RecognitionLabViewModel(options: recognitionEngines)

    // MARK: - 인식 엔진 조립

    private func makeEngineOption(_ method: RecognitionMethod) -> RecognitionEngineOption {
        let builder: any SymbolIndexBuilding
        let searcher: any SymbolSearching & SymbolScoring
        if let pipeline = method.embeddingPipeline {
            let store = SymbolIndexStore(fileURL: indexDirectory.appending(path: "\(method.rawValue).index"))
            builder = SymbolIndexBuilder(catalog: symbolCatalog, pipeline: pipeline, store: store)
            searcher = EmbeddingSymbolSearch(pipeline: pipeline, store: store, calibrator: method.calibrator, weights: method.scoreWeights)
        } else {
            let chamfer = ChamferSymbolSearch(catalog: symbolCatalog, calibrator: method.calibrator)
            builder = ChamferIndexPreparer(search: chamfer)
            searcher = chamfer
        }
        return RecognitionEngineOption(
            id: method.rawValue,
            title: method.title,
            detail: method.detail,
            prepare: DefaultPrepareSymbolIndexUseCase(builder: builder),
            search: DefaultSearchSymbolsUseCase(searcher: searcher),
            scorer: searcher,
            calibrator: method.calibrator
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
