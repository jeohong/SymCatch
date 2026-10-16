//
//  make_icon.swift
//  Tools
//
//  Created by Hongjeongmin on 10/16/26.
//
//  SymCatch 앱 아이콘(1024×1024, 알파 없음)을 그린다. 라이트·다크·틴트 세 가지.
//  모티프: 캔버스 점 격자 위, 반듯한 하트(심볼) 위에 손으로 그린 하트 선이 살짝 어긋나게 겹친 모습.
//  SF Symbol은 앱 아이콘에 쓸 수 없으므로 하트는 직접 그린 곡선이다.
//
//  사용법: swift Tools/appicon/make_icon.swift <저장 폴더> [A|B]
//    A: 인디고 바탕 + 흰 캔버스 카드  B: 인디고 바탕 전체가 캔버스  C: 금색 별에 펜으로 친 동그라미
//    D: C + 선 끝의 스타일러스  E: C + 선 끝의 손끝 물결  F: D에 빛·그림자·광택과 코랄 펜
//

import AppKit

let size: CGFloat = 1024

struct Palette {
    let background: CGColor
    let dots: CGColor
    let card: CGColor?
    let cardDots: CGColor
    let symbol: CGColor
    let ink: CGColor
    var stylus: CGColor = CGColor(gray: 1, alpha: 1)
    var stylusCone: CGColor = CGColor(srgbRed: 0xE4 / 255, green: 0xE2 / 255, blue: 0xFA / 255, alpha: 1)
    var nib: CGColor = CGColor(srgbRed: 0x1E / 255, green: 0x1B / 255, blue: 0x4B / 255, alpha: 1)
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// 반듯한 하트(심볼): 두 원호와 아래 꼭짓점으로 이루어진 대칭 곡선. 중심 (cx, cy), 폭 w.
func symbolHeart(cx: CGFloat, cy: CGFloat, w: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let h = w * 0.9
    let top = cy - h * 0.5, bottom = cy + h * 0.5
    let dip = top + h * 0.22
    path.move(to: CGPoint(x: cx, y: bottom))
    path.addCurve(to: CGPoint(x: cx - w * 0.5, y: top + h * 0.3),
                  control1: CGPoint(x: cx - w * 0.16, y: bottom - h * 0.2),
                  control2: CGPoint(x: cx - w * 0.5, y: top + h * 0.58))
    path.addCurve(to: CGPoint(x: cx, y: dip),
                  control1: CGPoint(x: cx - w * 0.5, y: top - h * 0.02),
                  control2: CGPoint(x: cx - w * 0.08, y: top - h * 0.06))
    path.addCurve(to: CGPoint(x: cx + w * 0.5, y: top + h * 0.3),
                  control1: CGPoint(x: cx + w * 0.08, y: top - h * 0.06),
                  control2: CGPoint(x: cx + w * 0.5, y: top - h * 0.02))
    path.addCurve(to: CGPoint(x: cx, y: bottom),
                  control1: CGPoint(x: cx + w * 0.5, y: top + h * 0.58),
                  control2: CGPoint(x: cx + w * 0.16, y: bottom - h * 0.2))
    path.closeSubpath()
    return path
}

/// 손으로 그린 하트 한 획: 가운데 오목한 곳에서 시작해 한 바퀴 돌고, 시작점을 조금 지나쳐 끝난다.
/// 반듯한 하트보다 조금 크고 기울었으며, 느리게 흔들린다.
func sketchHeart(cx: CGFloat, cy: CGFloat, w: CGFloat) -> CGPath {
    var points: [CGPoint] = []
    let steps = 220
    let turn = 2 * Double.pi * 1.07   // 한 바퀴 + 조금 더(지나쳐 끝남)
    let tilt = -0.07                  // 살짝 왼쪽으로 기울임(라디안)
    for step in 0...steps {
        let t = Double(step) / Double(steps) * turn
        let x = 16 * pow(sin(t), 3)
        let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
        // 손떨림: 느린 흔들림 두 겹, 끝으로 갈수록 바깥으로 조금 벌어진다(빨리 그리는 손)
        let drift = 1 + 0.035 * Double(step) / Double(steps)
        let wobbleX = 0.35 * sin(t * 3 + 0.8) + 0.18 * sin(t * 7 + 2.1)
        let wobbleY = 0.3 * cos(t * 2 + 0.3) + 0.15 * cos(t * 6 + 1.4)
        let px = (x * drift + wobbleX) / 34 * Double(w) * 1.04
        let py = -(y * drift + wobbleY) / 34 * Double(w) * 1.04
        let rx = px * cos(tilt) - py * sin(tilt)
        let ry = px * sin(tilt) + py * cos(tilt)
        points.append(CGPoint(x: cx + rx, y: cy + ry - w * 0.03))
    }
    let path = CGMutablePath()
    path.addLines(between: points)
    return path
}

/// 반듯한 별(심볼): 꼭짓점 5개, 모서리는 둥근 이음으로 다듬는다.
func symbolStar(cx: CGFloat, cy: CGFloat, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    for index in 0..<10 {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 5
        let r = index.isMultiple(of: 2) ? radius : radius * 0.48
        let point = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
        index == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

/// 정답에 펜으로 치는 동그라미: 오른쪽 위에서 시작해 한 바퀴 조금 넘게 돌고, 시작점을 지나쳐 끝난다.
/// 반지름이 조금씩 달라져 두 끝이 맞물리지 않고 엇갈린다.
func lassoPoints(cx: CGFloat, cy: CGFloat, radius: CGFloat, start: Double = -0.95 * Double.pi / 2) -> [CGPoint] {
    var points: [CGPoint] = []
    let steps = 240
    let sweep = -2 * Double.pi * 1.16     // 시계 반대 방향, 한 바퀴 + 조금
    for step in 0...steps {
        let f = Double(step) / Double(steps)
        let t = start + sweep * f
        // 가로로 조금 넓은 타원, 끝으로 갈수록 바깥으로 벌어진다
        let r = Double(radius) * (0.9 + 0.16 * f + 0.02 * sin(t * 3 + 0.6))
        let x = cos(t) * r * 1.08
        let y = sin(t) * r * 0.97
        let tilt = -0.18
        points.append(CGPoint(x: cx + x * cos(tilt) - y * sin(tilt), y: cy + x * sin(tilt) + y * cos(tilt)))
    }
    return points
}

func lasso(cx: CGFloat, cy: CGFloat, radius: CGFloat, start: Double = -0.95 * Double.pi / 2) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: lassoPoints(cx: cx, cy: cy, radius: radius, start: start))
    return path
}

/// 군더더기 없는 스타일러스. 펜 끝(tip)이 선 끝에 닿고, 몸통은 `angle` 방향(라디안, 화면 좌표)으로 뻗는다.
func drawStylus(_ context: CGContext, tip: CGPoint, angle: CGFloat, body: CGColor, cone: CGColor, nib: CGColor) {
    let length: CGFloat = 310, width: CGFloat = 92, coneLength: CGFloat = 104
    context.saveGState()
    context.translateBy(x: tip.x, y: tip.y)
    context.rotate(by: angle)
    // x축 방향이 몸통. 0 = 펜 끝
    context.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: CGColor(gray: 0, alpha: 0.28))
    let barrel = CGMutablePath()
    barrel.move(to: CGPoint(x: coneLength, y: -width / 2))
    barrel.addLine(to: CGPoint(x: length - width / 2, y: -width / 2))
    barrel.addArc(center: CGPoint(x: length - width / 2, y: 0), radius: width / 2, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
    barrel.addLine(to: CGPoint(x: coneLength, y: width / 2))
    barrel.closeSubpath()
    let conePath = CGMutablePath()
    conePath.move(to: CGPoint(x: coneLength + 1, y: -width / 2))
    conePath.addQuadCurve(to: CGPoint(x: 12, y: -11), control: CGPoint(x: coneLength * 0.5, y: -width * 0.36))
    conePath.addArc(center: CGPoint(x: 12, y: 0), radius: 11, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
    conePath.addQuadCurve(to: CGPoint(x: coneLength + 1, y: width / 2), control: CGPoint(x: coneLength * 0.5, y: width * 0.36))
    conePath.closeSubpath()
    context.addPath(barrel); context.addPath(conePath)
    context.setFillColor(body); context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.addPath(conePath); context.setFillColor(cone); context.fillPath()
    // 펜촉: 원뿔 앞쪽 1/3을 진한 색으로
    context.saveGState()
    context.addPath(conePath)
    context.clip()
    context.setFillColor(nib)
    context.fill(CGRect(x: -20, y: -width, width: coneLength * 0.36 + 20, height: width * 2))
    context.restoreGState()
    context.restoreGState()
}

/// 손끝이 닿은 자리: 점과 퍼지는 물결 고리
func drawTouch(_ context: CGContext, at point: CGPoint, color: CGColor) {
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(x: point.x - 36, y: point.y - 36, width: 72, height: 72))
    for (radius, alpha, width) in [(CGFloat(78), CGFloat(0.45), CGFloat(12)), (118, 0.2, 10)] {
        context.setStrokeColor(color.copy(alpha: alpha)!)
        context.setLineWidth(width)
        context.strokeEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }
}

// MARK: - F: 입체감(빛·그림자·광택)을 더한 펜 안

struct GlassPalette {
    let backgroundTop: CGColor, backgroundBottom: CGColor, glow: CGColor, dots: CGColor
    let starTop: CGColor, starBottom: CGColor
    let ink: CGColor, inkShadow: CGColor
    let penLight: CGColor, penDark: CGColor, penBand: CGColor, cone: CGColor, nib: CGColor
}

func linear(_ context: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func drawGlassPen(_ context: CGContext, tip: CGPoint, angle: CGFloat, palette: GlassPalette) {
    let length: CGFloat = 318, width: CGFloat = 96, coneLength: CGFloat = 108
    context.saveGState()
    context.translateBy(x: tip.x, y: tip.y)
    context.rotate(by: angle)
    let barrel = CGMutablePath()
    barrel.move(to: CGPoint(x: coneLength, y: -width / 2))
    barrel.addLine(to: CGPoint(x: length - width / 2, y: -width / 2))
    barrel.addArc(center: CGPoint(x: length - width / 2, y: 0), radius: width / 2, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
    barrel.addLine(to: CGPoint(x: coneLength, y: width / 2))
    barrel.closeSubpath()
    let cone = CGMutablePath()
    cone.move(to: CGPoint(x: coneLength + 1, y: -width / 2))
    cone.addQuadCurve(to: CGPoint(x: 12, y: -11), control: CGPoint(x: coneLength * 0.5, y: -width * 0.36))
    cone.addArc(center: CGPoint(x: 12, y: 0), radius: 11, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
    cone.addQuadCurve(to: CGPoint(x: coneLength + 1, y: width / 2), control: CGPoint(x: coneLength * 0.5, y: width * 0.36))
    cone.closeSubpath()

    // 그림자
    context.saveGState()
    context.setShadow(offset: CGSize(width: -10, height: 22), blur: 36, color: CGColor(gray: 0, alpha: 0.32))
    context.addPath(barrel); context.addPath(cone)
    context.setFillColor(palette.penDark); context.fillPath()
    context.restoreGState()

    // 몸통: 폭 방향 그라데이션(위가 밝게) + 광택 줄 + 끝 띠
    context.saveGState()
    context.addPath(barrel); context.clip()
    linear(context, [palette.penLight, palette.penDark], from: CGPoint(x: 0, y: -width / 2), to: CGPoint(x: 0, y: width / 2))
    context.setFillColor(palette.penBand)
    context.fill(CGRect(x: length - width * 0.95, y: -width, width: width * 0.22, height: width * 2))
    context.setFillColor(CGColor(gray: 1, alpha: 0.42))
    let shine = CGPath(roundedRect: CGRect(x: coneLength + 22, y: -width * 0.34, width: length - coneLength - width * 1.15, height: width * 0.13),
                       cornerWidth: width * 0.065, cornerHeight: width * 0.065, transform: nil)
    context.addPath(shine); context.fillPath()
    context.restoreGState()

    // 원뿔과 펜촉
    context.saveGState()
    context.addPath(cone); context.clip()
    linear(context, [palette.cone, palette.cone.copy(alpha: 0.82)!], from: CGPoint(x: 0, y: -width / 2), to: CGPoint(x: 0, y: width / 2))
    context.setFillColor(palette.nib)
    context.fill(CGRect(x: -20, y: -width, width: coneLength * 0.36 + 20, height: width * 2))
    context.restoreGState()
    context.restoreGState()
}

func renderGlass(_ palette: GlassPalette) -> CGImage {
    let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)

    // 배경: 왼쪽 위에서 빛이 드는 깊이감
    linear(context, [palette.backgroundTop, palette.backgroundBottom], from: CGPoint(x: 120, y: 0), to: CGPoint(x: 900, y: size))
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [palette.glow, palette.glow.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(glow, startCenter: CGPoint(x: 260, y: 200), startRadius: 0,
                               endCenter: CGPoint(x: 260, y: 200), endRadius: 620, options: [])
    drawDots(context, in: CGRect(x: 0, y: 0, width: size, height: size), spacing: 78, radius: 6, color: palette.dots)

    let center = CGPoint(x: size / 2 - 40, y: size / 2 - 30)

    // 별: 금색 그라데이션 + 위쪽 하이라이트 + 떠 있는 그림자
    // 둥근 모서리 별(채움 + 같은 색 둥근 이음 선)을 한 겹으로 그린 뒤, 그 모양 안에만 그라데이션을 입힌다.
    let star = symbolStar(cx: center.x, cy: center.y + 12, radius: 182)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 20), blur: 34, color: CGColor(gray: 0, alpha: 0.28))
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.addPath(star); context.setFillColor(palette.starBottom); context.fillPath()
    context.addPath(star); context.setStrokeColor(palette.starBottom); context.setLineWidth(44)
    context.setLineJoin(.round); context.strokePath()
    context.setBlendMode(.sourceIn)
    linear(context, [palette.starTop, palette.starBottom], from: CGPoint(x: 0, y: center.y - 200), to: CGPoint(x: 0, y: center.y + 200))
    context.setBlendMode(.sourceAtop)
    context.setFillColor(CGColor(gray: 1, alpha: 0.22))
    context.fillEllipse(in: CGRect(x: center.x - 260, y: center.y - 330, width: 520, height: 330))
    context.endTransparencyLayer()
    context.restoreGState()

    // 펜으로 친 동그라미
    let points = lassoPoints(cx: center.x, cy: center.y + 8, radius: 272, start: 0.25 * .pi + 2 * .pi * 1.16)
    let loop = CGMutablePath(); loop.addLines(between: points)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 10), blur: 18, color: palette.inkShadow)
    context.addPath(loop)
    context.setStrokeColor(palette.ink); context.setLineWidth(40)
    context.setLineCap(.round); context.setLineJoin(.round)
    context.strokePath()
    context.restoreGState()

    drawGlassPen(context, tip: points.last!, angle: 1.0, palette: palette)
    return context.makeImage()!
}

func drawDots(_ context: CGContext, in rect: CGRect, spacing: CGFloat, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    var y = rect.minY + spacing / 2
    while y < rect.maxY {
        var x = rect.minX + spacing / 2
        while x < rect.maxX {
            context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            x += spacing
        }
        y += spacing
    }
}

func render(_ palette: Palette, concept: String) -> CGImage {
    let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // 위가 0인 좌표
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)
    context.setFillColor(palette.background)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    let center = CGPoint(x: size / 2, y: size / 2)
    var heartWidth: CGFloat = 520
    var inkWidth: CGFloat = 40

    if concept == "A", let card = palette.card {
        // 캔버스 카드(살짝 기울임)
        let cardSide: CGFloat = 690
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: -0.06)
        let cardRect = CGRect(x: -cardSide / 2, y: -cardSide / 2, width: cardSide, height: cardSide)
        let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 120, cornerHeight: 120, transform: nil)
        context.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: rgb(0x000000, 0.22))
        context.addPath(cardPath)
        context.setFillColor(card)
        context.fillPath()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.addPath(cardPath)
        context.clip()
        drawDots(context, in: cardRect, spacing: 54, radius: 5, color: palette.cardDots)
        context.restoreGState()
        heartWidth = 430
        inkWidth = 34
    } else {
        drawDots(context, in: CGRect(x: 0, y: 0, width: size, height: size), spacing: 78, radius: 6.5, color: palette.dots)
    }

    if concept == "D" || concept == "E" {
        // 그리는 중: 별을 감싼 동그라미가 오른쪽 아래에서 끝나고, 그 자리에 펜 끝(D) 또는 손끝(E)
        let starCenter = CGPoint(x: center.x - 40, y: center.y - 30)
        let star = symbolStar(cx: starCenter.x, cy: starCenter.y + 12, radius: 178)
        context.addPath(star)
        context.setFillColor(palette.symbol)
        context.fillPath()
        context.addPath(star)
        context.setStrokeColor(palette.symbol)
        context.setLineWidth(40)
        context.setLineJoin(.round)
        context.strokePath()
        let points = lassoPoints(cx: starCenter.x, cy: starCenter.y + 8, radius: 270, start: 0.25 * .pi + 2 * .pi * 1.16)
        let path = CGMutablePath()
        path.addLines(between: points)
        context.addPath(path)
        context.setStrokeColor(palette.ink)
        context.setLineWidth(38)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
        let end = points.last!
        if concept == "D" {
            drawStylus(context, tip: end, angle: 1.0, body: palette.stylus, cone: palette.stylusCone, nib: palette.nib)
        } else {
            drawTouch(context, at: end, color: palette.ink)
        }
        return context.makeImage()!
    }

    if concept == "C" {
        // 금색 별(찾은 심볼) + 펜으로 친 동그라미
        let star = symbolStar(cx: center.x, cy: center.y + 16, radius: 212)
        context.addPath(star)
        context.setFillColor(palette.symbol)
        context.fillPath()
        context.addPath(star)
        context.setStrokeColor(palette.symbol)
        context.setLineWidth(46)
        context.setLineJoin(.round)
        context.strokePath()
        context.addPath(lasso(cx: center.x, cy: center.y + 10, radius: 318))
        context.setStrokeColor(palette.ink)
        context.setLineWidth(42)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
        return context.makeImage()!
    }

    // 반듯한 하트(심볼)
    context.addPath(symbolHeart(cx: center.x + 34, cy: center.y + 44, w: heartWidth))
    context.setFillColor(palette.symbol)
    context.fillPath()

    // 손으로 그린 하트 선
    context.addPath(sketchHeart(cx: center.x - 30, cy: center.y - 16, w: heartWidth * 0.97))
    context.setStrokeColor(palette.ink)
    context.setLineWidth(inkWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
    return context.makeImage()!
}

func save(_ image: CGImage, _ url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

let glassPalettes: [(String, GlassPalette)] = [
    ("light", GlassPalette(backgroundTop: rgb(0x6C63FF), backgroundBottom: rgb(0x3A31C9), glow: rgb(0xFFFFFF, 0.16), dots: rgb(0xFFFFFF, 0.12),
                           starTop: rgb(0xFFE88F), starBottom: rgb(0xF9B532), ink: rgb(0xFFFFFF), inkShadow: rgb(0x1E1A6B, 0.35),
                           penLight: rgb(0xFF9A7A), penDark: rgb(0xF0555E), penBand: rgb(0xC93B4E), cone: rgb(0xFFE3D3), nib: rgb(0x231F4F))),
    ("dark", GlassPalette(backgroundTop: rgb(0x221E4A), backgroundBottom: rgb(0x0B0A18), glow: rgb(0x7C75F0, 0.18), dots: rgb(0xFFFFFF, 0.08),
                          starTop: rgb(0xFFE07A), starBottom: rgb(0xEFA92A), ink: rgb(0xA9A4FF), inkShadow: rgb(0x000000, 0.5),
                          penLight: rgb(0xFF9A7A), penDark: rgb(0xE8505B), penBand: rgb(0xB8384A), cone: rgb(0xFFE3D3), nib: rgb(0x0E0D1A))),
    ("tinted", GlassPalette(backgroundTop: rgb(0x1A1A1A), backgroundBottom: rgb(0x000000), glow: rgb(0xFFFFFF, 0.06), dots: rgb(0xFFFFFF, 0.08),
                            starTop: rgb(0xFFFFFF), starBottom: rgb(0xD6D6D6), ink: rgb(0x9A9A9A), inkShadow: rgb(0x000000, 0.5),
                            penLight: rgb(0xBDBDBD), penDark: rgb(0x8C8C8C), penBand: rgb(0x6A6A6A), cone: rgb(0xE6E6E6), nib: rgb(0x2E2E2E))),
]

let arguments = CommandLine.arguments
let folder = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : ".")
let concept = arguments.count > 2 ? arguments[2] : "A"
try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

let starPalettes: [(String, Palette)] = [
    ("light", Palette(background: rgb(0x4F46E5), dots: rgb(0xFFFFFF, 0.16), card: nil,
                      cardDots: rgb(0, 0), symbol: rgb(0xFFD95A), ink: rgb(0xFFFFFF))),
    ("dark", Palette(background: rgb(0x0E0D1A), dots: rgb(0xFFFFFF, 0.1), card: nil,
                     cardDots: rgb(0, 0), symbol: rgb(0xF5C542), ink: rgb(0x8F89FF))),
    ("tinted", Palette(background: rgb(0x000000), dots: rgb(0xFFFFFF, 0.1), card: nil,
                       cardDots: rgb(0, 0), symbol: rgb(0xFFFFFF), ink: rgb(0x8A8A8A))),
]
var darkStylus = starPalettes[1].1
darkStylus.stylus = rgb(0xE9E7FF); darkStylus.stylusCone = rgb(0xB9B5F5); darkStylus.nib = rgb(0x0E0D1A)
var tintedStylus = starPalettes[2].1
tintedStylus.stylus = rgb(0xD0D0D0); tintedStylus.stylusCone = rgb(0x9A9A9A); tintedStylus.nib = rgb(0x3A3A3A)
let drawingPalettes: [(String, Palette)] = [starPalettes[0], ("dark", darkStylus), ("tinted", tintedStylus)]
let palettes: [(String, Palette)] = concept == "D" || concept == "E" ? drawingPalettes : concept == "C" ? starPalettes : concept == "A" ? [
    ("light", Palette(background: rgb(0x4F46E5), dots: rgb(0xFFFFFF, 0.12), card: rgb(0xFBFBFD),
                      cardDots: rgb(0x4F46E5, 0.16), symbol: rgb(0xC9C5FB), ink: rgb(0x16161A))),
    ("dark", Palette(background: rgb(0x0E0D1A), dots: rgb(0xFFFFFF, 0.08), card: rgb(0x1E1D2B),
                     cardDots: rgb(0xFFFFFF, 0.12), symbol: rgb(0x4F46E5), ink: rgb(0xF4F4F8))),
    ("tinted", Palette(background: rgb(0x000000), dots: rgb(0xFFFFFF, 0.08), card: rgb(0x2A2A2A),
                       cardDots: rgb(0xFFFFFF, 0.14), symbol: rgb(0x6E6E6E), ink: rgb(0xFFFFFF))),
] : [
    ("light", Palette(background: rgb(0x4F46E5), dots: rgb(0xFFFFFF, 0.16), card: nil,
                      cardDots: rgb(0, 0), symbol: rgb(0x7C75F0), ink: rgb(0xFFFFFF))),
    ("dark", Palette(background: rgb(0x0E0D1A), dots: rgb(0xFFFFFF, 0.1), card: nil,
                     cardDots: rgb(0, 0), symbol: rgb(0x3B34B8), ink: rgb(0xF4F4F8))),
    ("tinted", Palette(background: rgb(0x000000), dots: rgb(0xFFFFFF, 0.1), card: nil,
                       cardDots: rgb(0, 0), symbol: rgb(0x5A5A5A), ink: rgb(0xFFFFFF))),
]
if concept == "F" {
    for (name, palette) in glassPalettes {
        let url = folder.appending(path: "icon-F-\(name).png")
        save(renderGlass(palette), url)
        print("만듦: \(url.lastPathComponent)")
    }
    exit(0)
}
for (name, palette) in palettes {
    let url = folder.appending(path: "icon-\(concept)-\(name).png")
    save(render(palette, concept: concept), url)
    print("만듦: \(url.lastPathComponent)")
}
