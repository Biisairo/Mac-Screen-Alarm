import Foundation

public enum AlarmSchedule {
    /// FR-12: 이보다 긴 검사 구간은 잠자기 복귀·시계 변경으로 보고 건너뛴다.
    public static let maxWindow: TimeInterval = 10

    /// FR-11, FR-12, FR-14: 검사 구간 (from, to] 에 발화하는 알람을 발화 시각 순으로 반환한다.
    public static func dueAlarms(_ alarms: [Alarm], from: Date, to: Date, calendar: Calendar) -> [Alarm] {
        let window = to.timeIntervalSince(from)
        guard window > 0, window <= maxWindow else { return [] }

        let days = Set([calendar.startOfDay(for: from), calendar.startOfDay(for: to)])
        var hits: [(index: Int, fire: Date, alarm: Alarm)] = []
        for (index, alarm) in alarms.enumerated() where alarm.isEnabled {
            for day in days {
                guard let fire = fireDate(of: alarm, on: day, calendar: calendar) else { continue }
                if fire > from, fire <= to {
                    hits.append((index, fire, alarm))
                }
            }
        }
        return hits
            .sorted { ($0.fire, $0.index) < ($1.fire, $1.index) }
            .map(\.alarm)
    }

    /// FR-13: 발화한 1회성 알람을 비활성으로 바꾼다.
    public static func afterFiring(_ alarms: [Alarm], fired: [Alarm]) -> [Alarm] {
        let firedIDs = Set(fired.map(\.id))
        return alarms.map { alarm in
            guard alarm.isOneShot, firedIDs.contains(alarm.id) else { return alarm }
            var updated = alarm
            updated.isEnabled = false
            return updated
        }
    }

    /// `after` 보다 엄격히 뒤인 다음 발화 시각. 비활성이면 nil.
    public static func nextFireDate(for alarm: Alarm, after: Date, calendar: Calendar) -> Date? {
        guard alarm.isEnabled else { return nil }
        let start = calendar.startOfDay(for: after)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let fire = fireDate(of: alarm, on: day, calendar: calendar),
                  fire > after
            else { continue }
            return fire
        }
        return nil
    }

    public static func nextFire(in alarms: [Alarm], after: Date, calendar: Calendar) -> (alarm: Alarm, date: Date)? {
        alarms
            .compactMap { alarm in nextFireDate(for: alarm, after: after, calendar: calendar).map { (alarm, $0) } }
            .min { $0.1 < $1.1 }
    }

    /// FR-5: 시:분 오름차순.
    public static func sorted(_ alarms: [Alarm]) -> [Alarm] {
        alarms.enumerated()
            .sorted { ($0.element.hour, $0.element.minute, $0.offset) < ($1.element.hour, $1.element.minute, $1.offset) }
            .map(\.element)
    }

    /// 해당 날짜의 시:분:00. 반복 요일이 그 날짜를 포함하지 않으면 nil.
    private static func fireDate(of alarm: Alarm, on day: Date, calendar: Calendar) -> Date? {
        guard let fire = calendar.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: day) else {
            return nil
        }
        if alarm.isOneShot || alarm.weekdays.contains(calendar.component(.weekday, from: fire)) {
            return fire
        }
        return nil
    }
}
