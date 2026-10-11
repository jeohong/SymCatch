//
//  DeviceClients.swift
//  Symbol Sketch
//
//  Created by Hongjeongmin on 10/11/26.
//

import UIKit

/// 클립보드 복사. ViewModel이 UIKit을 직접 부르지 않도록 감싼다(테스트에서 가짜로 바꿈).
@MainActor
protocol PasteboardClient {
    func copy(_ text: String)
}

/// 햅틱. 설정(S8)에서 끌 수 있게 되면 구현체가 설정을 읽는다.
@MainActor
protocol HapticsClient {
    /// 복사 같은 가벼운 동작
    func lightImpact()
    /// 뱃지 획득 같은 성공
    func success()
}

struct SystemPasteboard: PasteboardClient {
    func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}

struct SystemHaptics: HapticsClient {
    func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
