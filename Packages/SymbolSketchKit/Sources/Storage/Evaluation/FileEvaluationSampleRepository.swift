//
//  FileEvaluationSampleRepository.swift
//  Storage
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation
import Domain

/// 평가용 손그림을 그림 한 장당 JSON 파일 하나로 저장한다.
/// 이미지가 아닌 획 좌표를 저장하므로, 나중에 전처리를 바꿔도 같은 그림으로 다시 평가할 수 있다.
public actor FileEvaluationSampleRepository: EvaluationSampleRepository {
    private let directory: URL
    private let exportDirectory: URL
    private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - directory: 그림을 보관할 폴더(앱에서는 Application Support/EvaluationSamples)
    ///   - exportDirectory: 내보낼 파일을 만들 임시 폴더
    public init(directory: URL, exportDirectory: URL = FileManager.default.temporaryDirectory, now: @escaping @Sendable () -> Date = Date.init) {
        self.directory = directory
        self.exportDirectory = exportDirectory
        self.now = now
    }

    public func save(_ sample: EvaluationSample) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(sample).write(to: fileURL(for: sample.id), options: .atomic)
    }

    public func all() async throws -> [EvaluationSample] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try files
            .map { try Self.decoder.decode(EvaluationSample.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func delete(id: UUID) async throws {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// 모든 그림을 배열 하나로 묶은 JSON 파일을 만든다. 파일 이름: `symbol-sketch-eval-yyyyMMdd-HHmmss.json`
    public func exportArchive() async throws -> URL {
        let samples = try await all()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = exportDirectory.appendingPathComponent("symbol-sketch-eval-\(formatter.string(from: now())).json")
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try Self.encoder.encode(samples).write(to: url, options: .atomic)
        return url
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
