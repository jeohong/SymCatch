//
//  RootView.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import SwiftUI

/// 앱의 첫 화면. M0(인식 프로토타입) 동안은 개발용 메뉴만 있고, M1에서 탭 구성(그리기·최근·콜렉션)으로 바뀐다.
struct RootView: View {
    let container: AppContainer

    var body: some View {
        NavigationStack {
            #if DEBUG
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
            .navigationTitle("Symbol Sketch")
            #else
            Text("준비 중이에요")
            #endif
        }
    }
}

#Preview("라이트") { RootView(container: .preview()).preferredColorScheme(.light) }
#Preview("다크") { RootView(container: .preview()).preferredColorScheme(.dark) }
