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

    @Test func 같은_family는_하나로_묶고_기본_모양이_대표가_된다() {
        let groups = VariantGrouper.group([
            scored("heart", 0.80),
            scored("heart.fill", 0.90),
            scored("star", 0.70),
        ], limit: 10)

        #expect(groups.map(\.representative.name) == ["heart", "star"])
        #expect(groups[0].variants == ["heart.fill"])
        // 묶음 점수는 변형 중 최고점(대표를 기본 모양으로 바꿔도 점수가 깎이지 않는다)
        #expect(groups[0].score == 0.90)
        #expect(groups[1].variants.isEmpty)
    }

    @Test func 기본_모양이_없으면_fill이_적은_변형이_대표() {
        let groups = VariantGrouper.group([
            scored("square.fill.on.square.fill", 0.9),
            scored("square.on.square.fill", 0.5),
        ], limit: 10)
        #expect(groups.first?.representative.name == "square.on.square.fill")
    }

    @Test func 묶은_뒤에_상위_limit개를_자른다() {
        let groups = VariantGrouper.group([
            scored("a", 0.9), scored("a.fill", 0.95),
            scored("b", 0.8),
            scored("c", 0.7),
        ], limit: 2)

        #expect(groups.map(\.representative.name) == ["a", "b"])
        #expect(groups.map(\.score) == [0.95, 0.8])
    }

    @Test func 점수가_같으면_이름순으로_순서를_고정한다() {
        let groups = VariantGrouper.group([scored("b", 0.5), scored("a", 0.5)], limit: 10)
        #expect(groups.map(\.representative.name) == ["a", "b"])
    }

    @Test func limit이_0이하면_빈_결과() {
        #expect(VariantGrouper.group([scored("a", 1)], limit: 0).isEmpty)
    }
}
