//
//  RootTabView.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 하단 탭: 그리기 · 최근 · 콜렉션(기획서 4장). 앱을 열면 그리기 탭에서 시작한다.
/// 표준 TabView·NavigationStack을 써서 iPhone Duo·iPad에서 바 배치를 시스템에 맡긴다(기획서 8.2-4).
struct RootTabView: View {
    let container: AppContainer
    @State private var router: AppRouter
    @State private var drawViewModel: DrawViewModel
    @State private var recentViewModel: RecentViewModel
    @State private var collectionViewModel: CollectionViewModel
    @State private var onboardingViewModel: OnboardingViewModel

    init(container: AppContainer) {
        self.container = container
        let router = container.router
        _router = State(initialValue: router)
        _drawViewModel = State(initialValue: container.makeDrawViewModel(navigator: router))
        _recentViewModel = State(initialValue: container.makeRecentViewModel(navigator: router))
        _collectionViewModel = State(initialValue: container.makeCollectionViewModel(navigator: router))
        _onboardingViewModel = State(initialValue: container.makeOnboardingViewModel(navigator: router))
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

            NavigationStack(path: $router.recentPath) {
                RecentScreen(viewModel: recentViewModel)
                    .navigationDestination(for: RecentRoute.self) { route in
                        switch route {
                        case .symbolDetail(let request):
                            SymbolDetailScreen(viewModel: container.makeSymbolDetailViewModel(request: request))
                        }
                    }
            }
            .tabItem { Label("최근", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.recent)

            NavigationStack(path: $router.collectionPath) {
                CollectionScreen(viewModel: collectionViewModel)
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
                    .navigationDestination(for: CollectionRoute.self) { route in
                        switch route {
                        case .badgeDetail(let name):
                            BadgeDetailScreen(viewModel: container.makeBadgeDetailViewModel(symbolName: name, navigator: router))
                        case .symbolDetail(let request):
                            SymbolDetailScreen(viewModel: container.makeSymbolDetailViewModel(request: request))
                        case .settings:
                            SettingsScreen(viewModel: container.makeSettingsViewModel(navigator: router))
                        }
                    }
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
            await container.reconcileBadgeTiers()
            await drawViewModel.refreshProgress()   // 맞춘 등급을 결과 행 표시에 바로 반영
        }
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
