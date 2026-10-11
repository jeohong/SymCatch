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

    init(container: AppContainer) {
        self.container = container
        let router = container.router
        _router = State(initialValue: router)
        _drawViewModel = State(initialValue: container.makeDrawViewModel(navigator: router))
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

            NavigationStack {
                EmptyStateView(systemImage: "clock.arrow.circlepath", message: String(localized: "최근 찾은 심볼은 다음 단계(M2)에서 만들어요"))
                    .navigationTitle("최근")
            }
            .tabItem { Label("최근", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.recent)

            NavigationStack {
                CollectionPlaceholder(container: container)
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
    }
}

/// M2에서 콜렉션 화면으로 바뀐다. 지금은 개발 도구로 가는 입구만 둔다(DEBUG).
private struct CollectionPlaceholder: View {
    let container: AppContainer

    var body: some View {
        EmptyStateView(systemImage: "rosette", message: String(localized: "콜렉션은 다음 단계(M2)에서 만들어요"))
            .navigationTitle("콜렉션")
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
            }
        }
        .navigationTitle("개발 도구")
    }
}
#endif
