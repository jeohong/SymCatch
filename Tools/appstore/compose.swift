//
//  compose.swift
//  Tools
//
//  Created by Hongjeongmin on 10/16/26.
//
//  App Store 스크린샷 합성: 시뮬레이터 원본(capture.sh)에 배경·기기 테두리·마케팅 문구를 입혀
//  App Store Connect 규격 크기 PNG로 저장한다.
//
//  사용법: swift Tools/appstore/compose.swift <slides.json> <원본 폴더> <저장 폴더> [ko|en]
//

import AppKit
import CoreImage

// MARK: - 설정 파일

struct SlideFile: Decodable {
    let slides: [Slide]
}

struct Slide: Decodable {
    let output: String
    let width: Int
    let height: Int
    /// 언어별 문구. [대괄호] 안은 강조색.
    let title: [String: String]
    let subtitle: [String: String]?
    let devices: [Device]
    /// 문구 위치를 직접 정할 때(헤더·검색 결과 같은 가로 배너). 없으면 위 가운데.
    let text: TextLayout?
}

struct TextLayout: Decodable {
    /// 문구 상자 왼쪽 x, 위쪽 y, 폭(모두 캔버스 비율)
    let x: Double
    let y: Double
    let width: Double
    /// left | center(기본)
    let align: String?
    /// 제목 글자 크기(캔버스 높이 비율)
    let size: Double
}

struct Device: Decodable {
    /// phone | ipad | duoOpen | duoFold | duoClosed
    let kind: String
    /// 원본 파일 이름(언어 폴더 기준, 예: "iphone/draw.png")
    let image: String
    /// 캔버스 폭 대비 기기 중심 x(0...1)
    let x: Double
    /// 캔버스 높이 대비 기기 위쪽 y(0...1)
    let y: Double
    /// 캔버스 폭 대비 기기 폭
    let width: Double
    /// 기기를 돌려 그릴 각도(도, 시계 방향)
    let rotation: Double?
    /// kind가 mockupFold일 때 쓸 목업 이미지(저장소 루트 기준, 흰 배경 PNG)
    let mockup: String?
}

// MARK: - 색

let accentTop = NSColor(srgbRed: 0x5E / 255, green: 0x55 / 255, blue: 0xF2 / 255, alpha: 1)
let accentBottom = NSColor(srgbRed: 0x3B / 255, green: 0x32 / 255, blue: 0xC8 / 255, alpha: 1)
let highlight = NSColor(srgbRed: 0xFF / 255, green: 0xD9 / 255, blue: 0x5A / 255, alpha: 1)
let bodyColor = NSColor(srgbRed: 0x16 / 255, green: 0x16 / 255, blue: 0x1A / 255, alpha: 1)
let frameEdge = NSColor(srgbRed: 0x3A / 255, green: 0x3A / 255, blue: 0x40 / 255, alpha: 1)

// MARK: - 그리기 도우미

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("이미지를 읽지 못했습니다: \(url.path)")
    }
    return image
}

func makeContext(width: Int, height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

/// 위가 0인 좌표로 그리기 위해 뒤집는다(CoreGraphics는 아래가 0).
func flipped(_ context: CGContext, height: Int) {
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
}

func drawBackground(_ context: CGContext, size: CGSize) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [accentTop.cgColor, accentBottom.cgColor] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width * 0.35, y: size.height), options: [])
    // 캔버스의 점 격자 무늬
    let spacing = size.width / 22
    let radius = size.width * 0.0032
    context.setFillColor(NSColor.white.withAlphaComponent(0.1).cgColor)
    var y = spacing / 2
    while y < size.height {
        var x = spacing / 2
        while x < size.width {
            context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            x += spacing
        }
        y += spacing
    }
}

/// "[강조]" 표기를 강조색으로 바꾼 문자열
func styled(_ text: String, font: NSFont, color: NSColor, lineHeight: CGFloat, alignment: NSTextAlignment = .center) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.minimumLineHeight = font.pointSize * lineHeight
    paragraph.maximumLineHeight = font.pointSize * lineHeight
    paragraph.lineBreakStrategy = .hangulWordPriority
    let result = NSMutableAttributedString()
    var isHighlighted = false
    var buffer = ""
    func flush() {
        guard !buffer.isEmpty else { return }
        result.append(NSAttributedString(string: buffer, attributes: [
            .font: font, .foregroundColor: isHighlighted ? highlight : color, .paragraphStyle: paragraph, .kern: -font.pointSize * 0.02,
        ]))
        buffer = ""
    }
    for character in text {
        if character == "[" { flush(); isHighlighted = true } else if character == "]" { flush(); isHighlighted = false } else { buffer.append(character) }
    }
    flush()
    return result
}

/// 문구를 위가 0인 좌표의 `top`부터 그리고, 그린 높이를 돌려준다.
func drawText(_ text: NSAttributedString, in context: CGContext, canvas: CGSize, top: CGFloat, width: CGFloat, left: CGFloat? = nil) -> CGFloat {
    let bounds = text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                   options: [.usesLineFragmentOrigin, .usesFontLeading])
    let rect = CGRect(x: left ?? (canvas.width - width) / 2, y: top, width: width, height: ceil(bounds.height))
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(cgContext: context, flipped: true)
    NSGraphicsContext.current = graphics
    text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    NSGraphicsContext.restoreGraphicsState()
    return rect.height
}

// MARK: - 기기 테두리

struct FrameStyle {
    /// 기기 폭 대비 테두리 두께
    let bezel: CGFloat
    /// 기기 폭 대비 바깥 모서리 반지름
    let radius: CGFloat
    let island: Bool
    let punchHole: Bool
    let hinge: Bool
    /// 접히는 화면의 주름(Duo 펼침)
    var crease = false
    /// 접힌 폰의 등(Duo 닫힘): 왼쪽에 경첩 쪽 모서리를 그린다
    var spine = false
}

func style(for kind: String) -> FrameStyle {
    switch kind {
    case "ipad": FrameStyle(bezel: 0.028, radius: 0.055, island: false, punchHole: false, hinge: false)
    case "duoOpen", "duoFold": FrameStyle(bezel: 0.022, radius: 0.06, island: false, punchHole: false, hinge: true, crease: true)
    case "duoClosed": FrameStyle(bezel: 0.034, radius: 0.12, island: false, punchHole: false, hinge: false, spine: true)
    default: FrameStyle(bezel: 0.034, radius: 0.15, island: true, punchHole: false, hinge: false)
    }
}

/// 화면 이미지를 감싼 기기 이미지를 만든다(투명 배경, 화면 원본 비율 유지).
func renderDevice(screen: CGImage, style: FrameStyle, width deviceWidth: CGFloat) -> CGImage {
    let screenAspect = CGFloat(screen.height) / CGFloat(screen.width)
    let bezel = deviceWidth * style.bezel
    let screenWidth = deviceWidth - bezel * 2
    let deviceHeight = screenWidth * screenAspect + bezel * 2
    let width = Int(deviceWidth.rounded(.up)), height = Int(deviceHeight.rounded(.up))
    let context = makeContext(width: width, height: height)
    flipped(context, height: height)

    let body = CGRect(x: 0, y: 0, width: deviceWidth, height: deviceHeight)
    let outerRadius = deviceWidth * style.radius
    // 몸체와 테두리 금속 느낌의 얇은 선
    context.addPath(CGPath(roundedRect: body, cornerWidth: outerRadius, cornerHeight: outerRadius, transform: nil))
    context.setFillColor(bodyColor.cgColor)
    context.fillPath()
    let edgeWidth = deviceWidth * 0.004
    context.addPath(CGPath(roundedRect: body.insetBy(dx: edgeWidth / 2, dy: edgeWidth / 2),
                           cornerWidth: outerRadius, cornerHeight: outerRadius, transform: nil))
    context.setStrokeColor(frameEdge.cgColor)
    context.setLineWidth(edgeWidth)
    context.strokePath()

    // 화면
    let screenRect = body.insetBy(dx: bezel, dy: bezel)
    let innerRadius = max(outerRadius - bezel, deviceWidth * 0.01)
    context.saveGState()
    context.addPath(CGPath(roundedRect: screenRect, cornerWidth: innerRadius, cornerHeight: innerRadius, transform: nil))
    context.clip()
    context.saveGState()
    // 이미지는 뒤집힌 좌표에서 위아래가 바뀌므로 다시 뒤집어 그린다.
    context.translateBy(x: screenRect.minX, y: screenRect.maxY)
    context.scaleBy(x: 1, y: -1)
    context.interpolationQuality = .high
    context.draw(screen, in: CGRect(origin: .zero, size: screenRect.size))
    context.restoreGState()
    if style.crease {
        // 접히는 자리의 주름: 가로로 긴 화면은 세로 선, 세로로 긴 화면은 가로 선
        let vertical = screenRect.width > screenRect.height
        let band = min(screenRect.width, screenRect.height) * 0.018
        let mid = vertical ? screenRect.midX : screenRect.midY
        let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                               colors: [NSColor.black.withAlphaComponent(0).cgColor, NSColor.black.withAlphaComponent(0.13).cgColor,
                                        NSColor.white.withAlphaComponent(0.18).cgColor, NSColor.black.withAlphaComponent(0.13).cgColor,
                                        NSColor.black.withAlphaComponent(0).cgColor] as CFArray,
                               locations: [0, 0.38, 0.5, 0.62, 1])!
        let from = vertical ? CGPoint(x: mid - band, y: 0) : CGPoint(x: 0, y: mid - band)
        let to = vertical ? CGPoint(x: mid + band, y: 0) : CGPoint(x: 0, y: mid + band)
        context.drawLinearGradient(shade, start: from, end: to, options: [])
    }
    context.restoreGState()

    if style.island {
        let islandWidth = deviceWidth * 0.27, islandHeight = deviceWidth * 0.078
        let rect = CGRect(x: (deviceWidth - islandWidth) / 2, y: bezel + deviceWidth * 0.028, width: islandWidth, height: islandHeight)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: islandHeight / 2, cornerHeight: islandHeight / 2, transform: nil))
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath()
    }
    let isLandscape = deviceWidth > deviceHeight
    if style.punchHole && !isLandscape {
        let diameter = deviceWidth * 0.032
        context.setFillColor(NSColor.black.cgColor)
        context.fillEllipse(in: CGRect(x: (deviceWidth - diameter) / 2, y: bezel + deviceWidth * 0.022, width: diameter, height: diameter))
    }
    if style.hinge {
        // 접히는 자리의 경첩 표시: 세로 기기는 양옆 가운데, 가로 기기는 위아래 가운데
        let notchLength = min(deviceWidth, deviceHeight) * 0.06, notchThickness = edgeWidth * 2.2
        context.setFillColor(frameEdge.cgColor)
        if isLandscape {
            for y in [0, deviceHeight - notchThickness] {
                context.fill(CGRect(x: deviceWidth / 2 - notchLength / 2, y: y, width: notchLength, height: notchThickness))
            }
        } else {
            for x in [0, deviceWidth - notchThickness] {
                context.fill(CGRect(x: x, y: deviceHeight / 2 - notchLength / 2, width: notchThickness, height: notchLength))
            }
        }
    }
    let device = context.makeImage()!
    guard style.spine else { return device }

    // 접힌 폰: 왼쪽에 두 판이 맞물린 등(경첩)을 덧붙인다.
    let spineWidth = deviceWidth * 0.045
    let wrapped = makeContext(width: width + Int(spineWidth), height: height)
    flipped(wrapped, height: height)
    let inset = outerRadius * 0.32
    let spineRect = CGRect(x: 0, y: inset, width: spineWidth * 2, height: deviceHeight - inset * 2)
    wrapped.saveGState()
    wrapped.addPath(CGPath(roundedRect: spineRect, cornerWidth: spineWidth * 0.95, cornerHeight: spineWidth * 1.6, transform: nil))
    wrapped.clip()
    let metal = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [NSColor(white: 0.16, alpha: 1).cgColor, NSColor(white: 0.42, alpha: 1).cgColor,
                                    NSColor(white: 0.22, alpha: 1).cgColor, NSColor(white: 0.1, alpha: 1).cgColor] as CFArray,
                           locations: [0, 0.35, 0.7, 1])!
    wrapped.drawLinearGradient(metal, start: CGPoint(x: 0, y: 0), end: CGPoint(x: spineWidth, y: 0), options: [])
    wrapped.restoreGState()
    wrapped.saveGState()
    wrapped.translateBy(x: spineWidth, y: CGFloat(height))
    wrapped.scaleBy(x: 1, y: -1)
    wrapped.draw(device, in: CGRect(x: 0, y: 0, width: width, height: height))
    wrapped.restoreGState()
    return wrapped.makeImage()!
}

/// 반쯤 접힌 모습(노트북 자세): 세로로 든 펼친 기기를 가운데 가로 선에서 접는다.
/// 위 판은 정면 그대로 세우고, 아래 판은 책상에 눕혀 높이를 줄이고 앞쪽을 넓힌다(위 판의 약 60%, 앞쪽 양옆 6%).
/// 화면과 베젤은 접히는 자리에서 끊기지 않고 이어지며(경첩 막대 없음), 아래 판 앞쪽에만 은색 두께가 보인다.
func foldDevice(_ device: CGImage) -> CGImage {
    let width = CGFloat(device.width), height = CGFloat(device.height)
    let half = height / 2
    let ciImage = CIImage(cgImage: device)
    let bottomHalf = ciImage.cropped(to: CGRect(x: 0, y: 0, width: width, height: half))
    guard let topHalf = device.cropping(to: CGRect(x: 0, y: 0, width: width, height: half)) else { return device }  // CGImage는 위가 0

    let spread = width * 0.06
    let bottomHeight = half * 0.61
    let thickness = width * 0.03
    let room = width * 0.06                      // 그림자 여백
    let outWidth = width + spread * 2 + room * 2
    let outHeight = half + bottomHeight + thickness + room
    let left = room + spread                     // 위 판 왼쪽
    let base = room + thickness                  // 아래 판 화면 앞쪽 가장자리(CoreGraphics, 아래가 0)
    let fold = base + bottomHeight               // 접히는 자리

    let filter = CIFilter(name: "CIPerspectiveTransform")!
    filter.setValue(bottomHalf, forKey: kCIInputImageKey)
    filter.setValue(CIVector(x: left, y: fold), forKey: "inputTopLeft")
    filter.setValue(CIVector(x: left + width, y: fold), forKey: "inputTopRight")
    filter.setValue(CIVector(x: room, y: base), forKey: "inputBottomLeft")
    filter.setValue(CIVector(x: room + width + spread * 2, y: base), forKey: "inputBottomRight")
    let full = CGRect(x: 0, y: 0, width: outWidth, height: outHeight)
    let bottomImage = CIContext().createCGImage(filter.outputImage!, from: full)!
    let space = CGColorSpace(name: CGColorSpace.sRGB)
    let context = makeContext(width: Int(outWidth), height: Int(outHeight))

    // 책상 그림자
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -width * 0.02), blur: width * 0.05, color: CGColor(gray: 0, alpha: 0.4))
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fill(CGRect(x: room + width * 0.03, y: base - thickness * 0.8, width: width + spread * 2 - width * 0.06, height: thickness))
    context.restoreGState()

    // 아래 판 앞쪽 두께: 둥근 끝의 은색 띠
    let front = CGRect(x: room, y: base - thickness, width: width + spread * 2, height: thickness * 1.6)
    context.saveGState()
    context.addPath(CGPath(roundedRect: front, cornerWidth: thickness * 1.2, cornerHeight: thickness * 0.8, transform: nil))
    context.clip()
    let edge = CGGradient(colorsSpace: space, colors: [CGColor(srgbRed: 0.98, green: 0.98, blue: 0.97, alpha: 1),
                                                       CGColor(srgbRed: 0.78, green: 0.79, blue: 0.78, alpha: 1),
                                                       CGColor(srgbRed: 0.6, green: 0.61, blue: 0.62, alpha: 1)] as CFArray,
                          locations: [0, 0.5, 1])!
    context.drawLinearGradient(edge, start: CGPoint(x: 0, y: front.maxY), end: CGPoint(x: 0, y: front.minY), options: [])
    // 옆 버튼·안테나 선처럼 보이는 가는 이음 자국
    context.setFillColor(CGColor(gray: 0.55, alpha: 0.7))
    for x in [front.minX + front.width * 0.1, front.maxX - front.width * 0.1] {
        context.fill(CGRect(x: x, y: front.minY, width: width * 0.003, height: thickness))
    }
    context.restoreGState()

    // 아래 판(눕힌 화면) + 은은한 빛 반사
    context.draw(bottomImage, in: full)
    let plate = CGMutablePath()
    plate.addLines(between: [CGPoint(x: room, y: base), CGPoint(x: room + width + spread * 2, y: base),
                             CGPoint(x: left + width, y: fold), CGPoint(x: left, y: fold)])
    plate.closeSubpath()
    context.saveGState()
    context.addPath(plate)
    context.clip()
    let glare = CGGradient(colorsSpace: space, colors: [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 0.12), CGColor(gray: 1, alpha: 0)] as CFArray,
                           locations: [0, 0.5, 1])!
    context.drawLinearGradient(glare, start: CGPoint(x: room, y: base), end: CGPoint(x: left + width * 0.7, y: fold), options: [])
    context.restoreGState()

    // 위 판(정면 그대로)
    context.draw(topHalf, in: CGRect(x: left, y: fold, width: width, height: half))
    // 접히는 자리: 아주 옅은 굽은 면 그늘(선이 아니라 면이 꺾이는 느낌)
    context.saveGState()
    context.clip(to: CGRect(x: left, y: fold - width * 0.012, width: width, height: width * 0.024))
    let bend = CGGradient(colorsSpace: space, colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.08), CGColor(gray: 0, alpha: 0)] as CFArray,
                          locations: [0, 0.5, 1])!
    context.drawLinearGradient(bend, start: CGPoint(x: 0, y: fold - width * 0.012), end: CGPoint(x: 0, y: fold + width * 0.012), options: [])
    context.restoreGState()
    return context.makeImage()!
}

// MARK: - iPhone Duo 테두리(시뮬레이터 화면 마스크 기준)

/// 시뮬레이터의 Duo 화면 모양 PDF(CoreSimulator 기기 정의에 들어 있음)
let duoProfile = "/Library/Developer/CoreSimulator/Profiles/DeviceTypes/iPhone Duo.simdevicetype/Contents/Resources/"
let duoOuterMask = duoProfile + "1C896A2B-F0D7-405C-8D0F-66E4B80AD044.pdf"   // 바깥 화면: 왼쪽(접히는 쪽) 각지고 오른쪽 둥근 모양
let duoInnerMask = duoProfile + "BF0DC480-5EE2-4EC1-B02B-C75E94759832.pdf"   // 안쪽 화면: 고르게 둥근 모양(세로 기준)

/// PDF 모양을 주어진 크기의 알파 이미지로 그린다.
/// 가로로 긴 크기면 세로 모양을 시계 방향으로 90도 돌린다(기기를 오른쪽으로 돌린 것과 같다: 왼쪽 → 위).
func shapeImage(_ path: String, size: CGSize) -> CGImage {
    let page = CGPDFDocument(URL(fileURLWithPath: path) as CFURL)!.page(at: 1)!
    let box = page.getBoxRect(.mediaBox)
    let rotate = (size.width > size.height) != (box.width > box.height)
    let native = rotate ? CGSize(width: size.height, height: size.width) : size
    let context = makeContext(width: Int(native.width.rounded()), height: Int(native.height.rounded()))
    context.scaleBy(x: native.width / box.width, y: native.height / box.height)
    // PDF 가장자리의 얇은 외곽선(작업 영역 테두리)이 같이 그려지지 않도록 안쪽만 그린다.
    context.clip(to: box.insetBy(dx: box.width * 0.004, dy: box.height * 0.004))
    context.drawPDFPage(page)
    let image = context.makeImage()!
    return rotate ? rotatedClockwise(image) : image
}

/// 이미지를 시계 방향으로 90도 돌린다.
func rotatedClockwise(_ image: CGImage) -> CGImage {
    let context = makeContext(width: image.height, height: image.width)
    context.translateBy(x: 0, y: CGFloat(image.width))
    context.rotate(by: -.pi / 2)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return context.makeImage()!
}

/// 모양(알파) 안에만 색을 채운다.
func fillShape(_ context: CGContext, _ shape: CGImage, in rect: CGRect, color: CGColor) {
    context.saveGState()
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.draw(shape, in: rect)
    context.setBlendMode(.sourceIn)
    context.setFillColor(color)
    context.fill(rect)
    context.endTransparencyLayer()
    context.restoreGState()
}

// Apple 소개 이미지의 밝은 은색 테두리와 경첩
let duoSilver = CGColor(srgbRed: 0xCF / 255, green: 0xD2 / 255, blue: 0xD7 / 255, alpha: 1)
let duoSilverEdge = CGColor(srgbRed: 0xA4 / 255, green: 0xA8 / 255, blue: 0xB0 / 255, alpha: 1)
let duoHinge = CGColor(srgbRed: 0xB4 / 255, green: 0xB8 / 255, blue: 0xBF / 255, alpha: 1)
let duoBlack = CGColor(srgbRed: 0x07 / 255, green: 0x07 / 255, blue: 0x09 / 255, alpha: 1)

/// Duo 기기 이미지(Apple HIG 그림 기준).
/// 은색 금속 테두리 → 얇은 검정 베젤 → 화면(시뮬레이터 화면 마스크 모양).
/// 닫힘: 접히는 쪽(세로면 왼쪽, 가로면 위)에 경첩 띠, 바깥 카메라는 세로면 오른쪽 위, 가로면 오른쪽 아래.
func renderDuo(screen: CGImage, closed: Bool, width deviceWidth: CGFloat) -> CGImage {
    let landscape = screen.width > screen.height
    let aspect = CGFloat(screen.height) / CGFloat(screen.width)
    // 두께는 기기의 짧은 변 기준
    let unit = landscape ? deviceWidth * aspect : deviceWidth
    let metal = unit * 0.009, bezel = unit * 0.012
    let hinge: CGFloat = closed ? unit * 0.026 : 0
    let side = metal + bezel
    // 폭 방향: 화면 + 양쪽 테두리 (+ 세로 닫힘이면 왼쪽 경첩)
    let screenWidth = deviceWidth - side * 2 - (closed && !landscape ? hinge : 0)
    let screenHeight = screenWidth * aspect
    let deviceHeight = screenHeight + side * 2 + (closed && landscape ? hinge : 0)
    let width = Int(deviceWidth.rounded(.up)), height = Int(deviceHeight.rounded(.up))
    let context = makeContext(width: width, height: height)
    let mask = closed ? duoOuterMask : duoInnerMask

    // CoreGraphics 좌표는 아래가 0: 가로 닫힘의 경첩(위쪽)은 maxY 쪽
    let hingeLeft = closed && !landscape ? hinge : 0
    let screenRect = CGRect(x: hingeLeft + side, y: side, width: screenWidth, height: screenHeight)
    let bezelRect = screenRect.insetBy(dx: -bezel, dy: -bezel)
    let bodyRect = bezelRect.insetBy(dx: -metal, dy: -metal)

    if closed {
        // 경첩 띠: 몸체 바깥으로 이어진 둥근 막대
        let band = landscape
            ? CGRect(x: bodyRect.minX + unit * 0.01, y: bodyRect.maxY - metal * 2, width: bodyRect.width - unit * 0.02, height: hinge + metal * 2)
            : CGRect(x: 0, y: bodyRect.minY + unit * 0.01, width: hinge + metal * 2, height: bodyRect.height - unit * 0.02)
        context.addPath(CGPath(roundedRect: band, cornerWidth: hinge * 0.45, cornerHeight: hinge * 0.45, transform: nil))
        context.setFillColor(duoHinge)
        context.fillPath()
        // 경첩 이음선
        context.setFillColor(duoSilverEdge)
        if landscape {
            context.fill(CGRect(x: band.minX + hinge, y: band.minY + band.height * 0.55, width: band.width - hinge * 2, height: unit * 0.0025))
        } else {
            context.fill(CGRect(x: band.minX + band.width * 0.42, y: band.minY + hinge, width: unit * 0.0025, height: band.height - hinge * 2))
        }
    }
    fillShape(context, shapeImage(mask, size: bodyRect.insetBy(dx: -unit * 0.002, dy: -unit * 0.002).size),
              in: bodyRect.insetBy(dx: -unit * 0.002, dy: -unit * 0.002), color: duoSilverEdge)
    fillShape(context, shapeImage(mask, size: bodyRect.size), in: bodyRect, color: duoSilver)
    fillShape(context, shapeImage(mask, size: bezelRect.size), in: bezelRect, color: duoBlack)

    // 같은 픽셀 격자에서 잘라야 가장자리에 반쯤 남는 픽셀(가는 선)이 생기지 않는다.
    let screenMask = shapeImage(mask, size: screenRect.size)
    let cut = makeContext(width: screenMask.width, height: screenMask.height)
    let cutRect = CGRect(x: 0, y: 0, width: screenMask.width, height: screenMask.height)
    cut.interpolationQuality = .high
    cut.draw(screen, in: cutRect)
    cut.setBlendMode(.destinationIn)
    cut.draw(screenMask, in: cutRect)
    context.interpolationQuality = .high
    context.draw(cut.makeImage()!, in: screenRect)

    if closed {
        // 바깥 카메라: 세로 기준 (왼쪽에서 0.905, 위에서 0.068) → 시계 방향으로 돌리면 (0.932, 0.905)
        let u: CGFloat = landscape ? 0.932 : 0.905, v: CGFloat = landscape ? 0.905 : 0.068
        let diameter = min(screenWidth, screenHeight) * 0.07
        let center = CGPoint(x: screenRect.minX + screenWidth * u, y: screenRect.maxY - screenHeight * v)
        context.setFillColor(duoBlack)
        context.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))
    }
    return context.makeImage()!
}

// MARK: - 사진 목업(반쯤 접힌 Duo)

/// 흰 배경의 기기 사진 목업에 스크린샷을 끼운다.
/// 바깥 흰 배경과 화면 자리(베젤 안쪽 흰 영역)를 찾아 투명하게 만들고, 스크린샷 위 절반은 위 판에,
/// 아래 절반은 아래 판(앞이 넓은 사다리꼴)에 맞춰 붙인 뒤 목업 테두리를 덮는다. 결과는 기기 부분만 잘라 돌려준다.
func mockupFold(screen: CGImage, mockupPath: String) -> CGImage {
    let mockup = loadImage(URL(fileURLWithPath: mockupPath))
    let w = mockup.width, h = mockup.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(mockup, in: CGRect(x: 0, y: 0, width: w, height: h))
    // pixels는 위가 0인 행 순서

    func isWhite(_ i: Int) -> Bool { pixels[i * 4] > 246 && pixels[i * 4 + 1] > 246 && pixels[i * 4 + 2] > 246 }
    /// 시작점들에서 이어진 흰 영역을 찾는다.
    func flood(_ seeds: [Int]) -> [Bool] {
        var mark = [Bool](repeating: false, count: w * h)
        var stack = seeds.filter { isWhite($0) }
        for seed in stack { mark[seed] = true }
        while let i = stack.popLast() {
            let x = i % w, y = i / w
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] where nx >= 0 && ny >= 0 && nx < w && ny < h {
                let n = ny * w + nx
                if !mark[n] && isWhite(n) { mark[n] = true; stack.append(n) }
            }
        }
        return mark
    }
    var border: [Int] = []
    for x in 0..<w { border.append(x); border.append((h - 1) * w + x) }
    for y in 0..<h { border.append(y * w); border.append(y * w + w - 1) }
    let outside = flood(border)
    let inside = flood([(h * 45 / 100) * w + w / 2])

    // 화면 자리의 행별 좌우 끝
    var rows: [(y: Int, minX: Int, maxX: Int)] = []
    for y in 0..<h {
        var minX = -1, maxX = -1
        for x in 0..<w where inside[y * w + x] { if minX < 0 { minX = x }; maxX = x }
        if minX >= 0 { rows.append((y, minX, maxX)) }
    }
    let top = rows.first!.y, bottom = rows.last!.y
    let span = bottom - top
    let ref = rows.first { $0.y >= top + span / 4 }!
    // 접히는 자리: 왼쪽 끝이 바깥으로 벌어지기 시작하는 행
    let foldRow = rows.first { $0.y > top + span / 3 && $0.minX < ref.minX - 2 }!
    func row(at fraction: Double) -> (y: Int, minX: Int, maxX: Int) {
        let target = foldRow.y + Int(Double(bottom - foldRow.y) * fraction)
        return rows.first { $0.y >= target }!
    }
    let a = row(at: 0.3), b = row(at: 0.6)
    func extrapolate(_ v1: Int, _ v2: Int, _ y1: Int, _ y2: Int, to y: Int) -> CGFloat {
        CGFloat(v1) + CGFloat(v2 - v1) * CGFloat(y - y1) / CGFloat(y2 - y1)
    }
    let bottomLeft = extrapolate(a.minX, b.minX, a.y, b.y, to: bottom)
    let bottomRight = extrapolate(a.maxX, b.maxX, a.y, b.y, to: bottom)
    let foldLeft = extrapolate(a.minX, b.minX, a.y, b.y, to: foldRow.y)
    let foldRight = extrapolate(a.maxX, b.maxX, a.y, b.y, to: foldRow.y)

    // 바깥 배경과 화면 자리(가장자리 2픽셀 넓혀서)를 투명하게
    var frame = pixels
    for i in 0..<(w * h) where outside[i] { frame[i * 4] = 0; frame[i * 4 + 1] = 0; frame[i * 4 + 2] = 0; frame[i * 4 + 3] = 0 }
    // 바깥 배경에 닿은 밝은 가장자리 픽셀(흰 배경 흔적)을 한 겹 지운다
    for y in 1..<(h - 1) {
        for x in 1..<(w - 1) where !outside[y * w + x] {
            let i = y * w + x
            guard outside[i - 1] || outside[i + 1] || outside[i - w] || outside[i + w] else { continue }
            let light = min(pixels[i * 4], pixels[i * 4 + 1], pixels[i * 4 + 2])
            if light > 215 { frame[i * 4] = 0; frame[i * 4 + 1] = 0; frame[i * 4 + 2] = 0; frame[i * 4 + 3] = 0 }
        }
    }
    for y in 0..<h {
        for x in 0..<w where inside[y * w + x] {
            for dy in -2...2 { for dx in -2...2 {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
                let n = (ny * w + nx) * 4
                // 흰색에 가까운 가장자리만 지운다(검은 베젤은 남긴다)
                if frame[n] > 120 { frame[n] = 0; frame[n + 1] = 0; frame[n + 2] = 0; frame[n + 3] = 0 }
            } }
        }
    }
    let frameImage = frame.withUnsafeMutableBytes { buffer in
        CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }

    // 스크린샷을 화면 자리에 붙인다(CoreImage 좌표는 아래가 0)
    let H = CGFloat(h)
    let shot = CIImage(cgImage: screen)
    let sw = CGFloat(screen.width), sh = CGFloat(screen.height)
    let topScreen = shot.cropped(to: CGRect(x: 0, y: sh / 2, width: sw, height: sh / 2))
    let bottomScreen = shot.cropped(to: CGRect(x: 0, y: 0, width: sw, height: sh / 2))
    func warp(_ image: CIImage, tl: CGPoint, tr: CGPoint, bl: CGPoint, br: CGPoint) -> CIImage {
        let filter = CIFilter(name: "CIPerspectiveTransform")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: tl), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: tr), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bl), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: br), forKey: "inputBottomRight")
        return filter.outputImage!
    }
    let foldY = H - CGFloat(foldRow.y)
    let upper = warp(topScreen, tl: CGPoint(x: CGFloat(ref.minX), y: H - CGFloat(top)), tr: CGPoint(x: CGFloat(ref.maxX), y: H - CGFloat(top)),
                     bl: CGPoint(x: foldLeft, y: foldY - 4), br: CGPoint(x: foldRight, y: foldY - 4))  // 아래 판과 4픽셀 겹쳐 틈을 없앤다
    let lower = warp(bottomScreen, tl: CGPoint(x: foldLeft, y: foldY), tr: CGPoint(x: foldRight, y: foldY),
                     bl: CGPoint(x: bottomLeft, y: H - CGFloat(bottom)), br: CGPoint(x: bottomRight, y: H - CGFloat(bottom)))
    let screens = CIContext().createCGImage(upper.composited(over: lower), from: CGRect(x: 0, y: 0, width: w, height: h))!

    // 화면 자리 모양으로 자르고(둥근 모서리), 목업 테두리를 덮는다
    var insideAlpha = [UInt8](repeating: 0, count: w * h)
    for y in 0..<h { for x in 0..<w where inside[y * w + x] {
        for dy in -3...3 { for dx in -3...3 {
            let nx = x + dx, ny = y + dy
            if nx >= 0, ny >= 0, nx < w, ny < h { insideAlpha[ny * w + nx] = 255 }
        } }
    } }
    let maskImage = insideAlpha.withUnsafeMutableBytes { buffer in
        CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!.makeImage()!
    }
    let out = makeContext(width: w, height: h)
    out.saveGState()
    out.clip(to: CGRect(x: 0, y: 0, width: w, height: h), mask: maskImage)
    out.interpolationQuality = .high
    out.draw(screens, in: CGRect(x: 0, y: 0, width: w, height: h))
    out.restoreGState()
    out.draw(frameImage, in: CGRect(x: 0, y: 0, width: w, height: h))
    let composed = out.makeImage()!

    // 기기 부분만 잘라 낸다
    var minX = w, maxX = 0, minY = h, maxY = 0
    for y in 0..<h { for x in 0..<w where !outside[y * w + x] {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    } }
    return composed.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))!
}

// MARK: - 합성

func compose(slide: Slide, rawFolder: URL, language: String) -> CGImage {
    let canvas = CGSize(width: slide.width, height: slide.height)
    let context = makeContext(width: slide.width, height: slide.height)
    flipped(context, height: slide.height)
    drawBackground(context, size: canvas)

    let isLandscape = canvas.width > canvas.height
    let layout = slide.text
    let titleSize: CGFloat = layout.map { canvas.height * CGFloat($0.size) }
        ?? (isLandscape ? canvas.height : canvas.width) * (isLandscape ? 0.07 : 0.078)
    let titleFont = NSFont.systemFont(ofSize: titleSize, weight: .heavy)
    let subtitleFont = NSFont.systemFont(ofSize: titleSize * 0.46, weight: .medium)
    let textWidth: CGFloat = layout.map { canvas.width * CGFloat($0.width) } ?? canvas.width * (isLandscape ? 0.7 : 0.86)
    let textLeft: CGFloat? = layout.map { canvas.width * CGFloat($0.x) }
    let alignment: NSTextAlignment = layout?.align == "left" ? .left : .center
    var top: CGFloat = layout.map { canvas.height * CGFloat($0.y) } ?? canvas.height * (isLandscape ? 0.06 : 0.055)
    let title = slide.title[language] ?? slide.title["ko"]!
    top += drawText(styled(title, font: titleFont, color: .white, lineHeight: 1.15, alignment: alignment),
                    in: context, canvas: canvas, top: top, width: textWidth, left: textLeft)
    if let subtitle = slide.subtitle?[language] ?? slide.subtitle?["ko"] {
        top += titleSize * 0.35
        _ = drawText(styled(subtitle, font: subtitleFont, color: NSColor.white.withAlphaComponent(0.86), lineHeight: 1.3, alignment: alignment),
                     in: context, canvas: canvas, top: top, width: textWidth, left: textLeft)
    }

    for device in slide.devices {
        let screen = loadImage(rawFolder.appending(path: device.image))
        let deviceWidth = canvas.width * device.width
        var image: CGImage
        switch device.kind {
        case "duoOpen": image = renderDuo(screen: screen, closed: false, width: deviceWidth)
        case "duoFold": image = foldDevice(renderDuo(screen: screen, closed: false, width: deviceWidth))
        case "duoClosed": image = renderDuo(screen: screen, closed: true, width: deviceWidth)
        case "mockupFold":
            let photo = mockupFold(screen: screen, mockupPath: device.mockup!)
            // 목업 사진을 원하는 폭으로 줄인다
            let scale = deviceWidth / CGFloat(photo.width)
            let resized = makeContext(width: Int(deviceWidth), height: Int(CGFloat(photo.height) * scale))
            resized.interpolationQuality = .high
            resized.draw(photo, in: CGRect(x: 0, y: 0, width: resized.width, height: resized.height))
            image = resized.makeImage()!
        default: image = renderDevice(screen: screen, style: style(for: device.kind), width: deviceWidth)
        }
        let size = CGSize(width: image.width, height: image.height)
        let center = CGPoint(x: canvas.width * device.x, y: canvas.height * device.y + size.height / 2)

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(device.rotation ?? 0) * .pi / 180)
        context.setShadow(offset: CGSize(width: 0, height: deviceWidth * 0.02), blur: deviceWidth * 0.08,
                          color: NSColor.black.withAlphaComponent(0.35).cgColor)
        // 뒤집힌 좌표에서 이미지를 바로 세워 그린다.
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        context.restoreGState()
    }
    return context.makeImage()!
}

func savePNG(_ image: CGImage, to url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    // App Store Connect는 알파 채널이 있는 스크린샷을 받지 않으므로 불투명으로 저장한다.
    let opaque = makeContext(width: image.width, height: image.height)
    opaque.setFillColor(accentBottom.cgColor)
    opaque.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    opaque.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let rgb = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    rgb.draw(opaque.makeImage()!, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    CGImageDestinationAddImage(destination, rgb.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

// MARK: - 실행

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    print("사용법: swift Tools/appstore/compose.swift <slides.json> <원본 폴더> <저장 폴더> [ko|en]")
    exit(1)
}
let specURL = URL(fileURLWithPath: arguments[1])
let rawFolder = URL(fileURLWithPath: arguments[2])
let outFolder = URL(fileURLWithPath: arguments[3])
let language = arguments.count > 4 ? arguments[4] : "ko"
let file = try JSONDecoder().decode(SlideFile.self, from: Data(contentsOf: specURL))
for slide in file.slides {
    let image = compose(slide: slide, rawFolder: rawFolder, language: language)
    let url = outFolder.appending(path: slide.output)
    savePNG(image, to: url)
    print("만듦: \(slide.output) (\(image.width)×\(image.height))")
}
