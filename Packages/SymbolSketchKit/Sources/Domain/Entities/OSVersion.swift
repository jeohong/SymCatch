//
//  OSVersion.swift
//  Domain
//
//  Created by Hongjeongmin on 10/11/26.
//

import Foundation

/// iOS·iPadOS 버전(주.부). 심볼마다 처음 나온 버전과 기기 버전을 비교할 때 쓴다.
public struct OSVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int

    public init(major: Int, minor: Int = 0) {
        self.major = major
        self.minor = minor
    }

    /// "17.0", "26", "18.4" 같은 문자열. 읽을 수 없으면 nil.
    public init?(_ string: String) {
        let parts = string.split(separator: ".").map { Int($0) }
        guard let first = parts.first, let major = first else { return nil }
        let minor = parts.count > 1 ? parts[1] : 0
        guard let minor else { return nil }
        self.init(major: major, minor: minor)
    }

    public static func < (lhs: OSVersion, rhs: OSVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }

    public var description: String { "\(major).\(minor)" }
}

extension SymbolMeta {
    /// 이 OS에서 쓸 수 있는 심볼인지. 버전을 읽을 수 없으면 있다고 본다(그림이 없으면 인덱스에서 어차피 빠진다).
    public func isAvailable(on os: OSVersion) -> Bool {
        OSVersion(minOS).map { $0 <= os } ?? true
    }
}
