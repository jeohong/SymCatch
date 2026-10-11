//
//  SymbolIndexStore.swift
//  Recognition
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

public enum SymbolIndexStoreError: Error, Sendable, Equatable {
    case notFound
    case corrupted
    case unsupportedFormat(UInt32)
}

/// 심볼 인덱스를 바이너리 파일로 저장하고 읽는다. 벡터는 float16으로 저장해 크기를 절반으로 줄인다.
///
/// 파일 형식(리틀 엔디언):
/// ```
/// "SSIX" | formatVersion u32 | engineID str | osVersion str | count u32 | dimension u32
/// names: str × count | complexity: f32 × count | vectors: f16 × count × dimension
/// str = 바이트 길이 u32 + UTF-8
/// ```
public struct SymbolIndexStore: Sendable {
    public static let formatVersion: UInt32 = 1
    private static let magic = Data("SSIX".utf8)

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func save(_ index: SymbolIndex) throws {
        var data = Self.magic
        data.append(le: Self.formatVersion)
        data.append(string: index.engineID)
        data.append(string: index.osVersion)
        data.append(le: UInt32(index.count))
        data.append(le: UInt32(index.dimension))
        for name in index.names { data.append(string: name) }
        for value in index.complexity { data.append(le: value.bitPattern) }
        data.reserveCapacity(data.count + index.vectors.count * 2)
        for value in index.vectors { data.append(le: Float16(value).bitPattern) }

        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    public func load() throws -> SymbolIndex {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw SymbolIndexStoreError.notFound }
        var reader = BinaryReader(data: try Data(contentsOf: fileURL, options: .mappedIfSafe))

        guard try reader.read(count: 4) == Self.magic else { throw SymbolIndexStoreError.corrupted }
        let version: UInt32 = try reader.read()
        guard version == Self.formatVersion else { throw SymbolIndexStoreError.unsupportedFormat(version) }
        let engineID = try reader.readString()
        let osVersion = try reader.readString()
        let count = Int(try reader.read() as UInt32)
        let dimension = Int(try reader.read() as UInt32)

        let names = try (0..<count).map { _ in try reader.readString() }
        let complexity = try (0..<count).map { _ in Float(bitPattern: try reader.read()) }
        var vectors = [Float](repeating: 0, count: count * dimension)
        for index in vectors.indices {
            vectors[index] = Float(Float16(bitPattern: try reader.read()))
        }
        guard reader.isAtEnd else { throw SymbolIndexStoreError.corrupted }

        return SymbolIndex(engineID: engineID, osVersion: osVersion, names: names, complexity: complexity, dimension: dimension, vectors: vectors)
    }

    public func delete() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - 바이너리 읽기·쓰기

private extension Data {
    mutating func append<T: FixedWidthInteger>(le value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(string: String) {
        let bytes = Data(string.utf8)
        append(le: UInt32(bytes.count))
        append(bytes)
    }
}

private struct BinaryReader {
    let data: Data
    private var offset: Int

    init(data: Data) {
        self.data = data
        self.offset = data.startIndex
    }

    var isAtEnd: Bool { offset == data.endIndex }

    mutating func read(count: Int) throws -> Data {
        guard count >= 0, data.endIndex - offset >= count else { throw SymbolIndexStoreError.corrupted }
        defer { offset += count }
        return data[offset..<offset + count]
    }

    mutating func read<T: FixedWidthInteger>() throws -> T {
        let bytes = try read(count: MemoryLayout<T>.size)
        var value: T = 0
        withUnsafeMutableBytes(of: &value) { $0.copyBytes(from: bytes) }
        return T(littleEndian: value)
    }

    mutating func readString() throws -> String {
        let length = Int(try read() as UInt32)
        guard let string = String(data: try read(count: length), encoding: .utf8) else {
            throw SymbolIndexStoreError.corrupted
        }
        return string
    }
}
