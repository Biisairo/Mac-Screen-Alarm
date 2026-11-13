import AlarmCore
import AppKit
import SwiftUI

/// FR-39: 화면 기록 권한 없이 바탕화면 파일을 읽어 미리보기·타일의 배경으로 쓴다.
@MainActor
enum Wallpaper {
    private static let maxPixelWidth: CGFloat = 960
    private static let fallbackAspectRatio: CGFloat = 16 / 10
    private static var cachedURL: URL?
    private static var cachedImage: NSImage?

    static func current() -> NSImage? {
        guard let screen = NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        if url != cachedURL {
            cachedURL = url
            cachedImage = downscaled(NSImage(contentsOf: url))
        }
        return cachedImage
    }

    static var aspectRatio: CGFloat {
        guard let frame = NSScreen.main?.frame, frame.height > 0 else { return fallbackAspectRatio }
        return frame.width / frame.height
    }

    /// 그리기 비용을 줄이려고 작은 비트맵으로 한 번만 그린다.
    private static func downscaled(_ source: NSImage?) -> NSImage? {
        guard let source, source.size.width > 0 else { return nil }
        let scale = min(1, maxPixelWidth / source.size.width)
        let width = Int(source.size.width * scale)
        let height = Int(source.size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        source.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return image
    }
}

/// FR-21: 색 덮개 위 글자색. 밝은 색에는 어두운 글자를 쓰고, 아래 화면 위에서 읽히도록 반대색 그림자를 둔다.
struct GlassInk {
    let primary: Color
    let secondary: Color
    let fill: Color
    let hoverFill: Color
    let border: Color
    let shadow: Color

    static let shadowRadius: CGFloat = 8

    init(_ color: RGBA) {
        let base: Color = color.isLight ? .black : .white
        shadow = (color.isLight ? Color.white : Color.black).opacity(0.5)
        primary = base.opacity(color.isLight ? 0.85 : 0.95)
        secondary = base.opacity(0.6)
        fill = base.opacity(0.14)
        hoverFill = base.opacity(0.24)
        border = base.opacity(0.2)
    }
}

/// 바탕화면 + 유리 농도로 자른 알람 색. 오버레이(FR-21)의 모습을 앱 안에서 재현한다.
struct GlassSurface: View {
    let color: RGBA
    let wallpaper: NSImage?

    var body: some View {
        ZStack {
            if let wallpaper {
                Image(nsImage: wallpaper)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.5)
            }
            Color(color.glassTint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

/// FR-38 시그니처: 알람마다 붙는 유리 조각.
struct GlassTile: View {
    let color: RGBA
    var size: CGFloat = 40

    var body: some View {
        GlassSurface(color: color, wallpaper: Wallpaper.current())
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size / 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size / 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1))
            )
    }
}

/// FR-39: 오버레이(FR-22)와 같은 배치를 축소해 보여 준다.
struct OverlayPreview: View {
    let alarm: Alarm
    let date: Date?

    var body: some View {
        let ink = GlassInk(alarm.color)
        GlassSurface(color: alarm.color, wallpaper: Wallpaper.current())
            .overlay {
                VStack(spacing: 4) {
                    if let date {
                        Text(OverlayText.date(date))
                            .font(.system(size: 11))
                            .foregroundStyle(ink.secondary)
                    }
                    Text(OverlayText.time(alarm))
                        .font(.system(size: 44, weight: .regular).monospacedDigit())
                        .foregroundStyle(ink.primary)
                    Text(alarm.label.isEmpty ? Alarm.defaultLabel : alarm.label)
                        .font(.system(size: 14))
                        .foregroundStyle(ink.primary)
                        .lineLimit(1)
                    Text("알람 끄기")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ink.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(ink.fill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .shadow(color: ink.shadow, radius: 2)
            }
            .aspectRatio(Wallpaper.aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1))
            )
    }
}

/// 오버레이·미리보기·목록이 같은 표기를 쓰도록 모은다.
enum OverlayText {
    private static let locale = Locale(identifier: "ko_KR")

    static func time(_ alarm: Alarm) -> String {
        String(format: "%02d:%02d", alarm.hour, alarm.minute)
    }

    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day().weekday(.wide).locale(locale))
    }

    static func weekdayName(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).locale(locale))
    }
}

extension Color {
    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }
}
