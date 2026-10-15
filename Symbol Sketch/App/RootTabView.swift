//
//  RootTabView.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI
import Domain

/// 하단 탭: 그리기 · 최근 · 콜렉션(기획서 4장). 앱을 열면 그리기 탭에서 시작한다.
/// 표준 TabView·NavigationStack을 써서 iPhone Duo·iPad에서 바 배치를 시스템에 맡긴다(기획서 8.2-4).
struct RootTabView: View {
    let container: AppContainer
    @State private var router: AppRouter
    @State private var drawViewModel: DrawViewModel
    @State private var recentViewModel: RecentViewModel
    @State private var collectionViewModel: CollectionViewModel
    @State private var onboardingViewModel: OnboardingViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 넓은 창: 최근·콜렉션을 목록 + 상세 분할 화면으로(기획서 8A.1). 좁은 창은 iPhone과 같은 스택.
    private var isSplit: Bool { horizontalSizeClass == .regular }

    /// 상위 화면(테마 전환 등)이 다시 그려질 때마다 init이 다시 불린다. 그래서 탭 ViewModel은 여기서 만들지 않고
    /// 컨테이너가 앱에 하나씩만 만들어 둔 것을 쓴다.
    init(container: AppContainer) {
        self.container = container
        _router = State(initialValue: container.router)
        _drawViewModel = State(initialValue: container.drawViewModel)
        _recentViewModel = State(initialValue: container.recentViewModel)
        _collectionViewModel = State(initialValue: container.collectionViewModel)
        _onboardingViewModel = State(initialValue: container.onboardingViewModel)
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.drawPath) {
                DrawScreen(viewModel: drawViewModel)
                    .navigationDestination(for: DrawRoute.self) { route in
                        switch route {
                        case .symbolDetail(let request):
                            SymbolDetailScreen(viewModel: container.makeSymbolDetailViewModel(request: request))
                        }
                    }
            }
            .onChange(of: router.drawPath) { oldPath, newPath in
                // 상세에서 뒤로 돌아오면 캔버스를 비운다(기획서 5.1-4).
                if newPath.isEmpty, !oldPath.isEmpty { drawViewModel.returnedFromDetail() }
            }
            .tabItem { Label("그리기", systemImage: "scribble") }
            .tag(AppTab.draw)

            Group {
                if isSplit { recentSplit } else { recentStack }
            }
            .tabItem { Label("최근", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.recent)

            Group {
                if isSplit { collectionSplit } else { collectionStack }
            }
            .tabItem { Label("콜렉션", systemImage: "rosette") }
            .tag(AppTab.collection)
        }
        .overlay {
            // 축하 모달(S4)은 탭 바까지 덮는다.
            if let celebration = router.celebration {
                CelebrationOverlay(viewModel: container.makeCelebrationViewModel(celebration: celebration) {
                    router.dismissCelebration()
                })
                .id(celebration.id)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: router.celebration)
        .fullScreenCover(isPresented: Binding(get: { router.isOnboardingPresented }, set: { router.isOnboardingPresented = $0 })) {
            OnboardingScreen(viewModel: onboardingViewModel)
        }
        .onChange(of: router.isOnboardingPresented) { _, presented in
            // 온보딩을 마치면 연습에서 고른 심볼이 최근·뱃지 표시에 바로 보이게 다시 읽는다.
            guard !presented else { return }
            Task { await drawViewModel.refreshProgress() }
        }
        .task {
            await container.reconcileProgress()
            await drawViewModel.refreshProgress()   // 맞춘 등급을 결과 행 표시에 바로 반영
            await collectionViewModel.load()        // 맞춘 업적을 콜렉션에 바로 반영
        }
        .onChange(of: isSplit, initial: true) { _, split in
            router.isSplitLayout = split
            selectDefaultRecent()
            selectDefaultBadge()
        }
        .onChange(of: recentViewModel.records) { selectDefaultRecent() }
        .onChange(of: collectionViewModel.summary?.badges) { selectDefaultBadge() }
        .onChange(of: router.pendingIndexRebuild) { _, requested in
            // 설정의 "심볼 다시 준비하기" → 그리기 화면에서 준비 진행을 보여 준다.
            guard requested else { return }
            drawViewModel.rebuildIndex()
            router.pendingIndexRebuild = false
        }
        .onChange(of: router.pendingChallenge) { _, name in
            // 콜렉션의 "도전하기" → 그리기 화면에 목표를 넘긴다.
            guard let name else { return }
            drawViewModel.startChallenge(symbolName: name)
            router.pendingChallenge = nil
        }
    }

    // MARK: - 최근(S5)

    private var recentStack: some View {
        NavigationStack(path: $router.recentPath) {
            RecentScreen(viewModel: recentViewModel)
                .navigationDestination(for: RecentRoute.self) { route in
                    switch route {
                    case .symbolDetail(let request): symbolDetail(request)
                    }
                }
        }
    }

    private var recentSplit: some View {
        NavigationSplitView {
            RecentScreen(viewModel: recentViewModel, selectedSymbolName: router.recentSelection?.name)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
        } detail: {
            NavigationStack {
                if let request = router.recentSelection {
                    symbolDetail(request).id(request)
                } else {
                    splitPlaceholder
                }
            }
        }
    }

    // MARK: - 콜렉션(S6)

    private var collectionStack: some View {
        NavigationStack(path: $router.collectionPath) {
            collectionScreen(selectedBadgeName: nil)
                .navigationDestination(for: CollectionRoute.self) { collectionDetail($0) }
        }
    }

    private var collectionSplit: some View {
        NavigationSplitView {
            collectionScreen(selectedBadgeName: router.collectionSelection.flatMap {
                if case .badgeDetail(let name) = $0 { name } else { nil }
            })
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
        } detail: {
            NavigationStack(path: $router.collectionDetailPath) {
                Group {
                    if let selection = router.collectionSelection {
                        collectionDetail(selection).id(selection)
                    } else {
                        splitPlaceholder
                    }
                }
                .navigationDestination(for: CollectionRoute.self) { collectionDetail($0) }
            }
        }
    }

    private func collectionScreen(selectedBadgeName: String?) -> some View {
        CollectionScreen(viewModel: collectionViewModel, selectedBadgeName: selectedBadgeName)
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DeveloperMenu(container: container)
                    } label: {
                        Label("개발 도구", systemImage: "hammer")
                    }
                }
            }
            #endif
    }

    @ViewBuilder
    private func collectionDetail(_ route: CollectionRoute) -> some View {
        switch route {
        case .badgeDetail(let name):
            BadgeDetailScreen(viewModel: container.makeBadgeDetailViewModel(symbolName: name, navigator: router))
        case .symbolDetail(let request):
            symbolDetail(request)
        case .settings:
            SettingsScreen(viewModel: container.makeSettingsViewModel(navigator: router))
        case .achievements:
            AchievementsScreen(viewModel: collectionViewModel)
        }
    }

    // MARK: - 공용

    private func symbolDetail(_ request: SymbolDetailRequest) -> some View {
        SymbolDetailScreen(viewModel: container.makeSymbolDetailViewModel(request: request))
    }

    /// 분할 화면 오른쪽에 보여 줄 것이 없을 때(DESIGN_NOTES S5)
    private var splitPlaceholder: some View {
        Text("왼쪽에서 항목을 고르세요")
            .font(.body)
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.bgGrouped)
    }

    /// 분할 화면의 기본 선택은 첫 기록. 고른 기록이 지워지면 다음 첫 기록으로(없으면 비움).
    private func selectDefaultRecent() {
        guard isSplit else { return }
        let records = recentViewModel.records
        if let selected = router.recentSelection, records.contains(where: { $0.symbolName == selected.name }) { return }
        if let first = records.first {
            recentViewModel.select(first)
        } else {
            router.recentSelection = nil
        }
    }

    /// 분할 화면의 기본 선택은 첫 뱃지(최근 획득순). 설정을 보고 있으면 그대로 둔다.
    private func selectDefaultBadge() {
        guard isSplit, router.collectionSelection == nil,
              let first = collectionViewModel.summary?.badges.first else { return }
        collectionViewModel.select(symbolName: first.symbolName)
    }
}

#if DEBUG
/// 개발용 화면 모음(인식 실험·평가셋 수집). 출시 빌드에는 없다.
private struct DeveloperMenu: View {
    let container: AppContainer

    var body: some View {
        List {
            Section("M0 인식 프로토타입") {
                NavigationLink {
                    RecognitionLabScreen(viewModel: container.makeRecognitionLabViewModel())
                } label: {
                    Label("인식 실험", systemImage: "scribble.variable")
                }
                NavigationLink {
                    EvaluationCollectionScreen(viewModel: container.makeEvaluationCollectionViewModel())
                } label: {
                    Label("평가셋 수집", systemImage: "pencil.and.list.clipboard")
                }
                NavigationLink {
                    EvaluationRunScreen(viewModel: container.makeEvaluationRunViewModel())
                } label: {
                    Label("평가 실행", systemImage: "chart.bar.doc.horizontal")
                }
            }
        }
        .navigationTitle("개발 도구")
    }
}
#endif
