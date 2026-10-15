#!/usr/bin/env swift
//
//  check_korean_keywords.swift
//  Tools
//
//  Created by Hongjeongmin on 10/15/26.
//
//  한국어 검색 사전(symbol_keywords_ko.json)에 없는 단어를 찾는다(계획서 7장 결정 22).
//  SF Symbols를 업데이트해 symbols.json을 다시 만든 뒤 실행하고, 나온 단어의 한국어 뜻을 사전에 채운다.
//
//  사용법:
//    swift Tools/check_korean_keywords.swift
//
//  규칙(사전을 만들 때와 같음):
//  - 대상 = 심볼 이름을 점으로 나눈 단어 + 키워드를 영문·숫자가 아닌 글자로 나눈 단어(소문자)
//  - 숫자만 있는 단어와 연결어(fill, and, on, to …)는 뺀다.
//  - 한국어로 찾을 말이 없는 조각(한 글자, 1x2 같은 코드)은 사전에 넣지 않아도 된다. 목록에 계속 나오는 것은 정상.
//

import Foundation

let resources = URL(fileURLWithPath: "Symbol Sketch/Resources")
struct Catalog: Decodable {
    struct Symbol: Decodable { let name: String; let keywords: [String] }
    let symbols: [Symbol]
}
struct Dictionary_: Decodable { let words: [String: [String]] }

let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: resources.appendingPathComponent("symbols.json")))
let dictionary = try JSONDecoder().decode(Dictionary_.self, from: Data(contentsOf: resources.appendingPathComponent("symbol_keywords_ko.json")))

let skip: Set<String> = ["fill", "and", "on", "to", "of", "the", "a", "in", "with", "for", "by", "at", "or"]
func isNumber(_ word: String) -> Bool { word.allSatisfy(\.isNumber) }

var needed: [String: Int] = [:]
for symbol in catalog.symbols {
    var words = symbol.name.split(separator: ".").map(String.init)
    for keyword in symbol.keywords {
        words += keyword.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
    for word in Set(words.map { $0.lowercased() }) where !skip.contains(word) && !isNumber(word) {
        needed[word, default: 0] += 1
    }
}

let missing = needed.filter { dictionary.words[$0.key] == nil }.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
print("사전 \(dictionary.words.count)단어, 대상 \(needed.count)단어, 없는 단어 \(missing.count)개(많이 쓰이는 순)")
for (word, count) in missing {
    print("\(word)\t\(count)")
}
