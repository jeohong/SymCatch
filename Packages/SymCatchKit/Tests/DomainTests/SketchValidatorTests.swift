//
//  SketchValidatorTests.swift
//  DomainTests
//
//  Created by Hongjeongmin on 10/11/26.
//

import Testing
@testable import Domain

struct SketchValidatorTests {
    let validator = SketchValidator(minimumExtent: 0.15, minimumTotalLength: 0.3)

    private func line(from start: (Double, Double), to end: (Double, Double)) -> [SketchPoint] {
        [SketchPoint(x: start.0, y: start.1), SketchPoint(x: end.0, y: end.1)]
    }

    @Test func 빈_그림은_empty() {
        #expect(validator.validate(.empty) == .empty)
        #expect(validator.validate(Sketch(strokes: [[]])) == .empty)
    }

    @Test func 크기가_작으면_tooSmall() {
        let tiny = Sketch(strokes: [line(from: (0.5, 0.5), to: (0.6, 0.5))])
        #expect(validator.validate(tiny) == .tooSmall)
    }

    @Test func 크기는_충분해도_획이_짧으면_tooSmall() {
        // 점 두 개만 찍은 그림: 범위는 넓지만 획 길이는 0
        let dots = Sketch(strokes: [[SketchPoint(x: 0.1, y: 0.1)], [SketchPoint(x: 0.9, y: 0.9)]])
        #expect(validator.validate(dots) == .tooSmall)
    }

    @Test func 충분히_크게_그리면_valid() {
        let cross = Sketch(strokes: [
            line(from: (0.2, 0.5), to: (0.8, 0.5)),
            line(from: (0.5, 0.2), to: (0.5, 0.8)),
        ])
        #expect(validator.validate(cross) == .valid)
    }

    @Test func 획_수와_길이를_계산한다() {
        let sketch = Sketch(strokes: [line(from: (0, 0), to: (0.3, 0.4)), []])
        #expect(sketch.strokeCount == 1)
        #expect(abs(sketch.totalLength - 0.5) < 1e-9)
    }
}
