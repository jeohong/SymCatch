//
//  ProgressModelContainerFactory.swift
//  Storage
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import SwiftData

/// 기록·뱃지·업적·통계를 담는 SwiftData 컨테이너를 만든다.
public enum ProgressModelContainerFactory {
    /// 앱용: 기기에 저장한다. iCloud 동기화는 쓰지 않는다(네트워크 금지).
    /// - Parameter url: 저장 파일 위치(앱에서는 Application Support/Progress.store)
    public static func live(url: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: ProgressMigrationPlan.self, configurations: configuration)
    }

    /// 테스트·Preview용: 메모리에만 둔다.
    public static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: ProgressMigrationPlan.self, configurations: configuration)
    }

    private static var schema: Schema { Schema(versionedSchema: ProgressSchemaV1.self) }
}
