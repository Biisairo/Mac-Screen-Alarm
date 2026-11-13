import Foundation

extension RGBA {
    /// FR-8: 오버레이·미리보기가 유리처럼 보이는 농도 범위.
    public static let glassAlphaRange: ClosedRange<Double> = 0.10...0.75

    /// FR-21: 이보다 휘도가 높은 색은 밝은 블러와 어두운 글자를 쓴다.
    public static let lightLuminanceThreshold = 0.55

    /// FR-8: 농도를 유리 농도 범위로 자른 색.
    public var glassTint: RGBA {
        RGBA(r: r, g: g, b: b, a: min(max(a, Self.glassAlphaRange.lowerBound), Self.glassAlphaRange.upperBound))
    }

    /// WCAG 상대 휘도 (sRGB 감마 해제).
    public var relativeLuminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    public var isLight: Bool { relativeLuminance > Self.lightLuminanceThreshold }
}

/// FR-2d: 시·분 입력의 순환 증감.
public enum TimeStep {
    public static func cycle(_ value: Int, by delta: Int, modulo: Int) -> Int {
        ((value + delta) % modulo + modulo) % modulo
    }
}

/// FR-37a, FR-37b: 다음 알람까지 남은 시간 표기.
public enum RemainingTime {
    private static let minutesPerHour = 60
    private static let minutesPerDay = 1440

    public static func text(seconds: TimeInterval) -> String {
        let total = max(1, Int((seconds / 60).rounded(.up)))
        let days = total / minutesPerDay
        let hours = (total % minutesPerDay) / minutesPerHour
        let minutes = total % minutesPerHour
        if days > 0 {
            return hours > 0 ? "\(days)일 \(hours)시간 뒤" : "\(days)일 뒤"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)시간 \(minutes)분 뒤" : "\(hours)시간 뒤"
        }
        return "\(minutes)분 뒤"
    }
}
