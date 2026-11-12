// 1024×1024 앱 아이콘 PNG 를 그린다. 사용: swift scripts/make-icon.swift <출력.png>
import AppKit

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

guard let context = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("context") }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// macOS 아이콘 그리드: 824pt 본체, 위아래 여백 100pt.
let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let body = CGPath(roundedRect: bodyRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

// 그림자
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
context.addPath(body)
context.setFillColor(color(0x1B1F3B))
context.fillPath()
context.restoreGState()

// 본체: 번진 색 덩어리로 '블러된 화면'을 표현
context.saveGState()
context.addPath(body)
context.clip()
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let base = CGGradient(colorsSpace: space, colors: [color(0x2A2F6B), color(0x14173A)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(base, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])

func blob(_ center: CGPoint, _ radius: CGFloat, _ hex: UInt32, _ alpha: CGFloat) {
    let gradient = CGGradient(colorsSpace: space, colors: [color(hex, alpha), color(hex, 0)] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}
blob(CGPoint(x: 260, y: 780), 520, 0xFF6B8B, 0.85)
blob(CGPoint(x: 820, y: 700), 460, 0xFFB35C, 0.75)
blob(CGPoint(x: 700, y: 220), 520, 0x5B8CFF, 0.8)
blob(CGPoint(x: 220, y: 240), 380, 0x9B6BFF, 0.6)

// 위쪽 하이라이트
let sheen = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.18), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(sheen, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 560), options: [])
context.restoreGState()

// 알람 시계
let center = CGPoint(x: 512, y: 488)
let faceRadius: CGFloat = 230
let white = color(0xFFFFFF)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: color(0x0B0D24, 0.45))

// 벨 두 개
for side in [-1.0, 1.0] {
    let bellCenter = CGPoint(x: center.x + side * 170, y: center.y + 215)
    context.saveGState()
    context.translateBy(x: bellCenter.x, y: bellCenter.y)
    context.rotate(by: side * -.pi / 5)
    context.addArc(center: .zero, radius: 92, startAngle: 0, endAngle: .pi, clockwise: false)
    context.closePath()
    context.setFillColor(white)
    context.fillPath()
    context.restoreGState()
}

// 다리 두 개
context.setStrokeColor(white)
context.setLineCap(.round)
context.setLineWidth(40)
for side in [-1.0, 1.0] {
    context.move(to: CGPoint(x: center.x + side * 140, y: center.y - 170))
    context.addLine(to: CGPoint(x: center.x + side * 200, y: center.y - 265))
}
context.strokePath()

// 시계판 (반투명 유리 + 흰 테두리)
context.addEllipse(in: CGRect(x: center.x - faceRadius, y: center.y - faceRadius, width: faceRadius * 2, height: faceRadius * 2))
context.setFillColor(white)
context.fillPath()
context.restoreGState()

let innerRadius = faceRadius - 38
context.addEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2))
context.setFillColor(color(0x2A2F6B))
context.fillPath()

// 눈금 4개
context.setStrokeColor(color(0xFFFFFF, 0.55))
context.setLineWidth(18)
for index in 0..<4 {
    let angle = CGFloat(index) * .pi / 2
    let outer = innerRadius - 24
    let inner = innerRadius - 54
    context.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
    context.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
}
context.strokePath()

// 바늘 (10:10)
context.setStrokeColor(white)
context.setLineWidth(30)
context.move(to: center)
context.addLine(to: CGPoint(x: center.x - 88, y: center.y + 62))
context.strokePath()
context.setStrokeColor(color(0xFFB35C))
context.setLineWidth(22)
context.move(to: center)
context.addLine(to: CGPoint(x: center.x + 105, y: center.y + 105))
context.strokePath()
context.addEllipse(in: CGRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48))
context.setFillColor(white)
context.fillPath()

guard let image = context.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
else { fatalError("encode") }
FileManager.default.createFile(atPath: outputPath, contents: png)
print("icon: \(outputPath)")
