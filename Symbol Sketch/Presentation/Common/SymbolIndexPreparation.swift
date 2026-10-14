//
//  SymbolIndexPreparation.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/14/26.
//

import Foundation
import Domain

/// 심볼 인덱스 준비 상태. 그리기 화면과 온보딩이 같은 준비를 함께 지켜본다(앱에 하나).
/// 첫 실행에는 온보딩을 보는 동안 뒤에서 준비가 진행되고, 진행률이 그리기 화면으로 그대로 이어진다(기획서 9장, 12.3).
@MainActor @Observable
final class SymbolIndexPreparation {
    enum State: Equatable {
        case checking
        case preparing(progress: Double)
        case ready
        case failed(String)
    }

    private(set) var state: State = .checking
    /// 설정에서 "심볼 다시 준비하기"로 다시 만드는 중인지(준비 문구가 달라진다)
    private(set) var isRebuilding = false
    /// 준비된 심볼 수("심볼 8,092개 준비 완료")
    private(set) var symbolCount: Int?
    #if DEBUG
    /// 개발용: 이번 실행에서 준비에 걸린 시간(초). 인덱스를 새로 만들 때만 채워진다.
    private(set) var seconds: Double?
    #endif

    private let prepareIndex: any PrepareSymbolIndexUseCase
    private var task: Task<Void, Never>?
    private var readyHandlers: [() -> Void] = []

    init(prepareIndex: any PrepareSymbolIndexUseCase) {
        self.prepareIndex = prepareIndex
    }

    var isReady: Bool { state == .ready }
    var isPreparing: Bool { task != nil }

    /// 준비를 마칠 때마다 부른다(그리던 그림이 있으면 바로 찾기 위함).
    func onReady(_ handler: @escaping () -> Void) {
        readyHandlers.append(handler)
    }

    /// 앱이 처음 화면을 띄울 때. 인덱스가 없으면 바로 만들기 시작한다. 여러 번 불러도 한 번만 준비한다.
    func start() async {
        guard task == nil, state != .ready else { return }
        if case .ready(let count) = await prepareIndex.status() {
            symbolCount = count
            state = .ready
        } else {
            begin(force: false)
        }
    }

    /// 오류 상태의 "다시 준비하기"
    func retry() {
        begin(force: false)
    }

    /// 설정의 "심볼 다시 준비하기": 준비돼 있어도 처음부터 다시 만든다.
    func rebuild() {
        guard task == nil else { return }
        isRebuilding = true
        begin(force: true)
    }

    private func begin(force: Bool) {
        guard task == nil else { return }
        state = .preparing(progress: 0)
        let startedAt = Date.now
        task = Task {
            do {
                for try await progress in (force ? prepareIndex.rebuild() : prepareIndex.execute()) {
                    state = .preparing(progress: progress)
                }
                #if DEBUG
                seconds = Date.now.timeIntervalSince(startedAt)
                #endif
                if case .ready(let count) = await prepareIndex.status() { symbolCount = count }
                state = .ready
                readyHandlers.forEach { $0() }
            } catch {
                state = .failed(error.localizedDescription)
            }
            isRebuilding = false
            task = nil
        }
    }
}
