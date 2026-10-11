// swift-tools-version: 6.0
//
//  Package.swift
//  SymbolSketchKit
//
//  Created by Hongjeongmin on 10/11/26.
//
//  레이어 경계를 컴파일러로 강제하기 위한 로컬 패키지.
//  Domain   : 순수 Swift (Foundation만)
//  Storage  : Data 레이어 — SwiftData·파일 저장소 구현 (Domain 의존)
//  Recognition : 인식 엔진 — Vision·Core ML·Accelerate (Domain 의존)
//

import PackageDescription

let package = Package(
    name: "SymbolSketchKit",
    defaultLocalization: "ko",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "Recognition", targets: ["Recognition"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Storage", dependencies: ["Domain"]),
        .target(
            name: "Recognition",
            dependencies: ["Domain"],
            // 픽셀 단위 반복 계산이 많아 최적화 없이(-Onone) 돌리면 10배 이상 느리다.
            // Xcode에서 디버그로 실행해도 심볼 준비를 기다릴 만하도록 이 모듈만 항상 최적화한다.
            swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .debug))]
        ),

        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "StorageTests", dependencies: ["Storage", "Domain"]),
        .testTarget(name: "RecognitionTests", dependencies: ["Recognition", "Domain"]),
    ]
)
