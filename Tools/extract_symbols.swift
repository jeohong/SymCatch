#!/usr/bin/env swift
//
//  extract_symbols.swift
//  Tools
//
//  Created by Hongjeongmin on 10/11/26.
//
//  Mac에 설치된 SF Symbols 앱의 메타데이터에서 심볼 목록을 뽑아 symbols.json을 만든다.
//
//  사용법:
//    swift Tools/extract_symbols.swift [출력 경로] [SF Symbols.app 경로]
//  기본 출력: "SymCatch/Resources/symbols.json"
//
//  규칙:
//  - 로케일 변형(.ar, .hi, .ja, .ko, .rtl …)은 제외한다. 모양이 원본과 거의 같아 Top 10을 채우기 때문이다.
//  - family = 이름에서 `fill` 구성요소를 뺀 것 (Domain의 VariantGrouper.family(of:)와 같은 규칙).
//  - 카테고리에서 모양과 무관한 메타 카테고리(all, whatsnew, draw, variable, multicolor)는 뺀다.
//  - minOS는 출시 연도 키(예: "2023.2")를 iOS 버전으로 바꾼 값이다.
//

import Foundation

let arguments = CommandLine.arguments
let outputPath = arguments.count > 1 ? arguments[1] : "SymCatch/Resources/symbols.json"
let appPath = arguments.count > 2 ? arguments[2] : "/Applications/SF Symbols.app"
let metadata = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/Metadata")

let localeSuffixes: Set<String> = [
    "ar", "hi", "rtl", "he", "th", "ja", "zh", "ko", "el", "ru", "km", "my",
    "mni", "pa", "sat", "or", "kn", "bn", "te", "gu", "ml", "ta", "si", "mr",
]
let metaCategories: Set<String> = ["all", "whatsnew", "draw", "variable", "multicolor"]

func plist(_ name: String) throws -> Any {
    let data = try Data(contentsOf: metadata.appendingPathComponent(name))
    return try PropertyListSerialization.propertyList(from: data, format: nil)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func family(of name: String) -> String {
    let parts = name.split(separator: ".").filter { $0 != "fill" }
    return parts.isEmpty ? name : parts.joined(separator: ".")
}

func isLocaleVariant(_ name: String) -> Bool {
    guard let last = name.split(separator: ".").last else { return false }
    return localeSuffixes.contains(String(last))
}

struct Category: Encodable { let key: String; let label: String; let icon: String }
struct Symbol: Encodable { let name: String; let family: String; let categories: [String]; let keywords: [String]; let minOS: String }
struct CatalogFile: Encodable { let source: String; let categories: [Category]; let symbols: [Symbol] }

guard FileManager.default.fileExists(atPath: metadata.path) else {
    fail("SF Symbols 메타데이터를 찾을 수 없습니다: \(metadata.path)")
}

do {
    guard let availability = try plist("name_availability.plist") as? [String: Any],
          let releaseByName = availability["symbols"] as? [String: String],
          let yearToRelease = availability["year_to_release"] as? [String: [String: String]] else {
        fail("name_availability.plist 형식이 예상과 다릅니다")
    }
    let categoriesByName = try plist("symbol_categories.plist") as? [String: [String]] ?? [:]
    let keywordsByName = try plist("symbol_search.plist") as? [String: [String]] ?? [:]
    let categoryList = try plist("categories.plist") as? [[String: String]] ?? []

    let categories = categoryList.compactMap { item -> Category? in
        guard let key = item["key"], !metaCategories.contains(key) else { return nil }
        return Category(key: key, label: item["label"] ?? key, icon: item["icon"] ?? "questionmark")
    }

    let symbols = releaseByName.keys
        .filter { !isLocaleVariant($0) }
        .sorted()
        .map { name in
            Symbol(
                name: name,
                family: family(of: name),
                categories: (categoriesByName[name] ?? []).filter { !metaCategories.contains($0) },
                keywords: keywordsByName[name] ?? [],
                minOS: yearToRelease[releaseByName[name] ?? ""]?["iOS"] ?? "13.0"
            )
        }

    let latestRelease = yearToRelease.keys.max { $0.compare($1, options: .numeric) == .orderedAscending } ?? "unknown"
    let file = CatalogFile(source: latestRelease, categories: categories, symbols: symbols)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let outputURL = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try encoder.encode(file).write(to: outputURL)

    let familyCount = Set(symbols.map(\.family)).count
    print("심볼 \(symbols.count)개 (family \(familyCount)개, 로케일 변형 \(releaseByName.count - symbols.count)개 제외)")
    print("카테고리 \(categories.count)개, 메타데이터 \(latestRelease)")
    print("저장: \(outputURL.path)")
} catch {
    fail("\(error)")
}
