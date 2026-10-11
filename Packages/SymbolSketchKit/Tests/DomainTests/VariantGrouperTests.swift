//
//  VariantGrouperTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Testing
@testable import Domain

struct VariantGrouperTests {
    private func scored(_ name: String, _ score: Double) -> ScoredSymbol {
        ScoredSymbol(name: name, family: VariantGrouper.family(of: name), score: score)
    }

    @Test(arguments: [
        ("heart", "heart"),
        ("heart.fill", "heart"),
        ("heart.circle.fill", "heart.circle"),
        ("square.fill.on.square.fill", "square.on.square"),
        ("fill", "fill"),
    ])
    func family는_fill_구성요소를_뺀_이름이다(name: String, expected: String) {
        #expect(VariantGrouper.family(of: name) == expected)
    }

    @Test func 같은_family는_하나로_묶고_최고점_변형이_대표가_된다() {
        let groups = VariantGrouper.group([
            scored("heart", 0.80),
            scored("heart.fill", 0.90),
            scored("star", 0.70),
        ], limit: 10)

        #expect(groups.map(\.representative.name) == ["heart.fill", "star"])
        #expect(groups[0].variants == ["heart"])
        #expect(groups[1].variants.isEmpty)
    }

    @Test func 묶은_뒤에_상위_limit개를_자른다() {
        let groups = VariantGrouper.group([
            scored("a", 0.9), scored("a.fill", 0.95),
            scored("b", 0.8),
            scored("c", 0.7),
        ], limit: 2)

        #expect(groups.map(\.representative.name) == ["a.fill", "b"])
    }

    @Test func 점수가_같으면_이름순으로_순서를_고정한다() {
        let groups = VariantGrouper.group([scored("b", 0.5), scored("a", 0.5)], limit: 10)
        #expect(groups.map(\.representative.name) == ["a", "b"])
    }

    @Test func limit이_0이하면_빈_결과() {
        #expect(VariantGrouper.group([scored("a", 1)], limit: 0).isEmpty)
    }
}
