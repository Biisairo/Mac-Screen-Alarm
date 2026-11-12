import AlarmCore
import SwiftUI

/// FR-1~FR-5, FR-32
struct AlarmListView: View {
    static let windowID = "manage"

    @ObservedObject var controller: AlarmController
    @StateObject private var session = EditSession()

    var body: some View {
        VStack(spacing: 0) {
            if controller.alarms.isEmpty {
                ContentUnavailableView("알람 없음", systemImage: "alarm", description: Text("+ 버튼으로 알람을 추가하세요."))
            } else {
                List(controller.alarms) { alarm in
                    AlarmRow(alarm: alarm, isEnabled: Binding(
                        get: { alarm.isEnabled },
                        set: { controller.setEnabled(alarm, $0) }
                    ))
                    .contentShape(Rectangle())
                    .onTapGesture { session.open(alarm) }
                    .contextMenu {
                        Button("편집") { session.open(alarm) }
                        Button("삭제", role: .destructive) { controller.delete(alarm) }
                    }
                }
            }
        }
        .frame(width: 380, height: 420)
        .toolbar {
            Button {
                session.open(Alarm.makeDefault(now: Date(), calendar: .current))
            } label: {
                Label("알람 추가", systemImage: "plus")
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
}

private struct AlarmRow: View {
    let alarm: Alarm
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(alarm.color))
                .overlay(Circle().stroke(.secondary.opacity(0.4)))
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%02d:%02d", alarm.hour, alarm.minute))
                    .font(.system(size: 24, weight: .medium).monospacedDigit())
                Text("\(alarm.label) · \(Weekday.summary(alarm.weekdays))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .opacity(alarm.isEnabled ? 1 : 0.5)
        .padding(.vertical, 4)
    }
}

/// SwiftUI `@State` 매크로 플러그인이 CLT 에 없어 편집 상태를 ObservableObject 로 둔다.
@MainActor
private final class EditSession: ObservableObject {
    @Published var editing: Alarm?
    @Published var draft = Alarm.makeDefault(now: Date(), calendar: .current)

    func open(_ alarm: Alarm) {
        draft = alarm
        editing = alarm
    }
}

private struct AlarmEditor: View {
    @ObservedObject var session: EditSession
    let isNew: Bool
    let onSave: (Alarm) -> Void
    let onDelete: (Alarm) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            DatePicker("시각", selection: timeBinding, displayedComponents: .hourAndMinute)
            TextField("내용", text: $session.draft.label)
            LabeledContent("반복") {
                HStack(spacing: 4) {
                    ForEach(Weekday.all, id: \.value) { day in
                        Toggle(day.symbol, isOn: weekdayBinding(day.value))
                            .toggleStyle(.button)
                    }
                }
            }
            ColorPicker("블러 색상", selection: colorBinding, supportsOpacity: true)
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    session.draft.isEnabled = isNew || session.draft.isEnabled
                    onSave(session.draft)
                    dismiss()
                }
            }
            if !isNew {
                ToolbarItem(placement: .destructiveAction) {
                    Button("삭제", role: .destructive) {
                        onDelete(session.draft)
                        dismiss()
                    }
                }
            }
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: session.draft.hour, minute: session.draft.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                session.draft.hour = Calendar.current.component(.hour, from: date)
                session.draft.minute = Calendar.current.component(.minute, from: date)
            }
        )
    }

    private func weekdayBinding(_ value: Int) -> Binding<Bool> {
        Binding(
            get: { session.draft.weekdays.contains(value) },
            set: { isOn in
                if isOn {
                    session.draft.weekdays.insert(value)
                } else {
                    session.draft.weekdays.remove(value)
                }
            }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(session.draft.color) },
            set: { color in
                if let rgb = NSColor(color).usingColorSpace(.sRGB) {
                    session.draft.color = RGBA(r: rgb.redComponent, g: rgb.greenComponent, b: rgb.blueComponent, a: rgb.alphaComponent)
                }
            }
        )
    }
}

private enum Weekday {
    struct Day {
        let value: Int
        let symbol: String
    }

    static let all: [Day] = ["일", "월", "화", "수", "목", "금", "토"].enumerated().map { Day(value: $0.offset + 1, symbol: $0.element) }

    static func summary(_ weekdays: Set<Int>) -> String {
        if weekdays.isEmpty { return "한 번" }
        if weekdays.count == all.count { return "매일" }
        return all.filter { weekdays.contains($0.value) }.map(\.symbol).joined(separator: " ")
    }
}

extension Color {
    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }
}
