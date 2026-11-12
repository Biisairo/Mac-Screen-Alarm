/// FR-14: 표시할 알람을 하나씩 내보내는 큐.
public struct AlarmQueue: Sendable {
    private var items: [Alarm] = []

    public init() {}

    public var current: Alarm? { items.first }

    public mutating func enqueue(_ alarms: [Alarm]) {
        items.append(contentsOf: alarms)
    }

    public mutating func dismiss() {
        if !items.isEmpty {
            items.removeFirst()
        }
    }
}
