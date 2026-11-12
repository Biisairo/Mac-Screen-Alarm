import Foundation

public struct RGBA: Codable, Equatable, Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public static let defaultBlur = RGBA(r: 0, g: 0, b: 0, a: 0.4)
}

public struct Alarm: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var hour: Int
    public var minute: Int
    public var label: String
    /// Calendar weekday 값(1=일 … 7=토). 비어 있으면 1회성 알람.
    public var weekdays: Set<Int>
    public var isEnabled: Bool
    public var color: RGBA

    public init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        label: String,
        weekdays: Set<Int>,
        isEnabled: Bool,
        color: RGBA
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.color = color
    }

    public static let defaultLabel = "알람"

    public var isOneShot: Bool { weekdays.isEmpty }

    /// FR-1: 현재 시각 다음 분, 기본 내용·색상, 반복 없음, 활성.
    public static func makeDefault(now: Date, calendar: Calendar) -> Alarm {
        let minuteStart = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        let next = minuteStart.addingTimeInterval(60)
        return Alarm(
            hour: calendar.component(.hour, from: next),
            minute: calendar.component(.minute, from: next),
            label: defaultLabel,
            weekdays: [],
            isEnabled: true,
            color: .defaultBlur
        )
    }
}
