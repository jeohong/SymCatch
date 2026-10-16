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
func styled(_ text: String, font: NSFont, color: NSColor, lineHeight: CGFloat) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
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
func drawText(_ text: NSAttributedString, in context: CGContext, canvas: CGSize, top: CGFloat, width: CGFloat) -> CGFloat {
    let bounds = text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                   options: [.usesLineFragmentOrigin, .usesFontLeading])
    let rect = CGRect(x: (canvas.width - width) / 2, y: top, width: width, height: ceil(bounds.height))
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
}

func style(for kind: String) -> FrameStyle {
    switch kind {
    case "ipad": FrameStyle(bezel: 0.028, radius: 0.055, island: false, punchHole: false, hinge: false)
    case "duoOpen", "duoFold": FrameStyle(bezel: 0.024, radius: 0.07, island: false, punchHole: true, hinge: true)
    case "duoClosed": FrameStyle(bezel: 0.032, radius: 0.13, island: false, punchHole: true, hinge: false)
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
    return context.makeImage()!
}

/// 반쯤 접힌 모습: 위 절반을 뒤로 젖힌 원근으로 바꾸고 아래 절반은 그대로 둔다.
func foldDevice(_ device: CGImage) -> CGImage {
    let width = CGFloat(device.width), height = CGFloat(device.height)
    let half = height / 2
    let ciImage = CIImage(cgImage: device)
    // CIImage는 아래가 0: 위 절반은 y ∈ [half, height]
    let top = ciImage.cropped(to: CGRect(x: 0, y: half, width: width, height: half))
    let bottom = ciImage.cropped(to: CGRect(x: 0, y: 0, width: width, height: half))
    let squeeze = width * 0.09       // 먼 쪽(위 끝)이 좁아지는 양
    let foreshorten = half * 0.22    // 기울어 짧아지는 양
    let perspective = CIFilter(name: "CIPerspectiveTransform")!
    perspective.setValue(top, forKey: kCIInputImageKey)
    perspective.setValue(CIVector(x: squeeze, y: height - foreshorten), forKey: "inputTopLeft")
    perspective.setValue(CIVector(x: width - squeeze, y: height - foreshorten), forKey: "inputTopRight")
    perspective.setValue(CIVector(x: 0, y: half), forKey: "inputBottomLeft")
    perspective.setValue(CIVector(x: width, y: half), forKey: "inputBottomRight")
    var tilted = perspective.outputImage!
    // 젖힌 면은 조금 어둡게(빛을 덜 받는 쪽)
    tilted = tilted.applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.06])
    let composed = tilted.composited(over: bottom)
    let output = CIContext().createCGImage(composed, from: CGRect(x: 0, y: 0, width: width, height: height))!
    // 접힌 선 그림자
    let context = makeContext(width: Int(width), height: Int(height))
    context.draw(output, in: CGRect(x: 0, y: 0, width: width, height: height))
    let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [NSColor.black.withAlphaComponent(0.35).cgColor, NSColor.black.withAlphaComponent(0).cgColor] as CFArray,
                           locations: [0, 1])!
    context.saveGState()
    context.clip(to: CGRect(x: 0, y: half, width: width, height: half * 0.12))
    context.drawLinearGradient(shade, start: CGPoint(x: 0, y: half), end: CGPoint(x: 0, y: half + half * 0.12), options: [])
    context.restoreGState()
    return context.makeImage()!
}

// MARK: - 합성

func compose(slide: Slide, rawFolder: URL, language: String) -> CGImage {
    let canvas = CGSize(width: slide.width, height: slide.height)
    let context = makeContext(width: slide.width, height: slide.height)
    flipped(context, height: slide.height)
    drawBackground(context, size: canvas)

    let isLandscape = canvas.width > canvas.height
    let titleSize = (isLandscape ? canvas.height : canvas.width) * (isLandscape ? 0.07 : 0.078)
    let titleFont = NSFont.systemFont(ofSize: titleSize, weight: .heavy)
    let subtitleFont = NSFont.systemFont(ofSize: titleSize * 0.46, weight: .medium)
    let textWidth = canvas.width * (isLandscape ? 0.7 : 0.86)
    var top = canvas.height * (isLandscape ? 0.06 : 0.055)
    let title = slide.title[language] ?? slide.title["ko"]!
    top += drawText(styled(title, font: titleFont, color: .white, lineHeight: 1.15), in: context, canvas: canvas, top: top, width: textWidth)
    if let subtitle = slide.subtitle?[language] ?? slide.subtitle?["ko"] {
        top += titleSize * 0.35
        _ = drawText(styled(subtitle, font: subtitleFont, color: NSColor.white.withAlphaComponent(0.86), lineHeight: 1.3),
                     in: context, canvas: canvas, top: top, width: textWidth)
    }

    for device in slide.devices {
        let screen = loadImage(rawFolder.appending(path: device.image))
        let deviceWidth = canvas.width * device.width
        var image = renderDevice(screen: screen, style: style(for: device.kind), width: deviceWidth)
        if device.kind == "duoFold" { image = foldDevice(image) }
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
