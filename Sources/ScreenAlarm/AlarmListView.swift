import AlarmCore
import SwiftUI

/// FR-1~FR-5, FR-32, FR-37, FR-38
struct AlarmListView: View {
    static let windowID = "manage"

    private static let width: CGFloat = 460
    private static let minHeight: CGFloat = 440

    @ObservedObject var controller: AlarmController
    @StateObject private var session = EditSession()

    var body: some View {
        VStack(spacing: 0) {
            if controller.alarms.isEmpty {
                EmptyAlarms { addAlarm() }
            } else {
                NextAlarmHeader(controller: controller)
                Divider()
                alarmList
            }
        }
        .frame(width: Self.width)
        .frame(minHeight: Self.minHeight, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addAlarm) {
                    Label("알람 추가", systemImage: "plus")
                }
                .keyboardShortcut("n")
                .help("알람 추가 (⌘N)")
            }
        }
        .sheet(item: $session.editing) { alarm in
            AlarmEditor(
                session: session,
                isNew: !controller.alarms.contains { $0.id == alarm.id },
                onSave: { controller.upsert($0) },
                onDelete: { controller.delete($0) }
            )
        }
    }

    private var alarmList: some View {
        List(selection: $session.selection) {
            ForEach(controller.alarms) { alarm in
                AlarmRow(
                    alarm: alarm,
                    isEnabled: Binding(
                        get: { alarm.isEnabled },
                        set: { controller.setEnabled(alarm, $0) }
                    ),
                    onEdit: { session.open(alarm) },
                    onDelete: { controller.delete(alarm) }
                )
                .tag(alarm.id)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let alarm = alarm(in: ids) {
                Button("편집") { session.open(alarm) }
                Button("삭제", role: .destructive) { controller.delete(alarm) }
            }
        } primaryAction: { ids in
            if let alarm = alarm(in: ids) {
                session.open(alarm)
            }
        }
        .onDeleteCommand {
            if let id = session.selection, let alarm = alarm(in: [id]) {
                controller.delete(alarm)
            }
        }
    }

    private func addAlarm() {
        session.open(Alarm.makeDefault(now: Date(), calendar: .current))
    }

    private func alarm(in ids: Set<UUID>) -> Alarm? {
        controller.alarms.first { ids.contains($0.id) }
    }
}

/// FR-37
private struct NextAlarmHeader: View {
    @ObservedObject var controller: AlarmController

    var body: some View {
        HStack(spacing: 16) {
            if let alarm = controller.nextAlarm, let date = controller.nextFireDate {
                GlassTile(color: alarm.color, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("다음 알람")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(OverlayText.time(alarm))
                            .font(.system(size: 28, weight: .medium).monospacedDigit())
                        Text(controller.remainingText)
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text("\(dayText(date)) · \(alarm.label)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("예정된 알람 없음")
                        .font(.system(size: 15, weight: .medium))
                    Text("켜진 알람이 없습니다")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func dayText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "오늘" }
        if calendar.isDateInTomorrow(date) { return "내일" }
        return OverlayText.weekdayName(date)
    }
}

private struct EmptyAlarms: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            GlassTile(color: RGBA(r: 0.16, g: 0.44, b: 0.45, a: 0.45), size: 72)
            VStack(spacing: 4) {
                Text("알람이 없습니다")
                    .font(.system(size: 15, weight: .medium))
                Text("알람이 울리면 소리 대신 화면 전체가\n고른 색의 유리로 덮입니다")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("첫 알람 만들기", action: onAdd)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

/// FR-38
private struct AlarmRow: View {
    let alarm: Alarm
    @Binding var isEnabled: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    /// SwiftUI `@State` 매크로 플러그인이 CLT 에 없어 `State` 를 직접 보관한다.
    private let isHovered = State(initialValue: false)

    var body: some View {
        HStack(spacing: 12) {
            GlassTile(color: alarm.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(OverlayText.time(alarm))
                    .font(.system(size: 22, weight: .medium).monospacedDigit())
                Text(alarm.label)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if isHovered.wrappedValue {
                HStack(spacing: 4) {
                    RowIconButton(systemImage: "pencil", help: "편집", action: onEdit)
                    RowIconButton(systemImage: "trash", help: "삭제", action: onDelete)
                }
            }
            WeekdayStrip(weekdays: alarm.weekdays)
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .opacity(alarm.isEnabled ? 1 : 0.5)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { isHovered.wrappedValue = $0 }
    }
}

private struct RowIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(help)
    }
}

/// 반복 요일을 일~토 7칸으로 보여 준다. 1회성이면 "한 번".
private struct WeekdayStrip: View {
    let weekdays: Set<Int>

    var body: some View {
        if weekdays.isEmpty {
            Text("한 번")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: Weekday.stripWidth, alignment: .trailing)
        } else {
            HStack(spacing: 1) {
                ForEach(Weekday.all, id: \.value) { day in
                    Text(day.symbol)
                        .font(.system(size: 11, weight: weekdays.contains(day.value) ? .medium : .regular))
                        .foregroundStyle(weekdays.contains(day.value) ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                        .frame(width: 14)
                }
            }
            .frame(width: Weekday.stripWidth, alignment: .trailing)
        }
    }
}

/// SwiftUI `@State` 매크로 플러그인이 CLT 에 없어 편집 상태를 ObservableObject 로 둔다.
@MainActor
final class EditSession: ObservableObject {
    @Published var editing: Alarm?
    @Published var selection: UUID?
    @Published var draft = Alarm.makeDefault(now: Date(), calendar: .current)

    func open(_ alarm: Alarm) {
        draft = alarm
        editing = alarm
    }
}

enum Weekday {
    struct Day {
        let value: Int
        let symbol: String
    }

    static let all: [Day] = ["일", "월", "화", "수", "목", "금", "토"].enumerated().map { Day(value: $0.offset + 1, symbol: $0.element) }
    static let weekdays: Set<Int> = [2, 3, 4, 5, 6]
    static let weekend: Set<Int> = [1, 7]
    static let everyday: Set<Int> = Set(1...7)
    static let stripWidth: CGFloat = 104
}
