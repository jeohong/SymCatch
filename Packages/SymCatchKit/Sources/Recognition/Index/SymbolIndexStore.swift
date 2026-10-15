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
/// names: str × count | complexity: f32 × count | hubness: f32 × count
/// layoutDimension u32 | layouts: f16 × count × layoutDimension | vectors: f16 × count × dimension
/// (2판: hubness 추가, 3판: 잉크 배치 추가. 이전 판 파일은 `unsupportedFormat` → 인덱스를 다시 만든다)
/// str = 바이트 길이 u32 + UTF-8
/// ```
public struct SymbolIndexStore: Sendable {
    public static let formatVersion: UInt32 = 3
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
        for value in index.hubness { data.append(le: value.bitPattern) }
        data.append(le: UInt32(index.layoutDimension))
        for value in index.layouts { data.append(le: Float16(value).bitPattern) }
        data.reserveCapacity(data.count + index.vectors.count * 2)
        for value in index.vectors { data.append(le: Float16(value).bitPattern) }

        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    /// 인덱스를 다시 만들어야 하는지 판단할 때 쓰는 머리 정보.
    public struct Header: Sendable, Hashable {
        public let engineID: String
        public let osVersion: String
        public let count: Int
        public let dimension: Int
    }

    /// 벡터는 읽지 않고 머리 정보만 읽는다.
    public func loadHeader() throws -> Header {
        var reader = try openReader()
        return try Self.readHeader(&reader)
    }

    public func load() throws -> SymbolIndex {
        var reader = try openReader()
        let header = try Self.readHeader(&reader)
        let (engineID, osVersion, count, dimension) = (header.engineID, header.osVersion, header.count, header.dimension)

        let names = try (0..<count).map { _ in try reader.readString() }
        let complexity = try (0..<count).map { _ in Float(bitPattern: try reader.read()) }
        let hubness = try (0..<count).map { _ in Float(bitPattern: try reader.read()) }
        let layoutDimension = Int(try reader.read() as UInt32)
        let layouts = try (0..<count * layoutDimension).map { _ in Float(Float16(bitPattern: try reader.read())) }
        var vectors = [Float](repeating: 0, count: count * dimension)
        for index in vectors.indices {
            vectors[index] = Float(Float16(bitPattern: try reader.read()))
        }
        guard reader.isAtEnd else { throw SymbolIndexStoreError.corrupted }

        return SymbolIndex(engineID: engineID, osVersion: osVersion, names: names, complexity: complexity, hubness: hubness,
                           layoutDimension: layoutDimension, layouts: layouts, dimension: dimension, vectors: vectors)
    }

    /// 파일 수정 시각. 파일이 없으면 nil.
    public func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
    }

    public func delete() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func openReader() throws -> BinaryReader {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw SymbolIndexStoreError.notFound }
        return BinaryReader(data: try Data(contentsOf: fileURL, options: .mappedIfSafe))
    }

    private static func readHeader(_ reader: inout BinaryReader) throws -> Header {
        guard try reader.read(count: 4) == magic else { throw SymbolIndexStoreError.corrupted }
        let version: UInt32 = try reader.read()
        guard version == formatVersion else { throw SymbolIndexStoreError.unsupportedFormat(version) }
        return Header(
            engineID: try reader.readString(),
            osVersion: try reader.readString(),
            count: Int(try reader.read() as UInt32),
            dimension: Int(try reader.read() as UInt32)
        )
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
