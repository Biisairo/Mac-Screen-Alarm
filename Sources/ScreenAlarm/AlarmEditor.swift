import AlarmCore
import AppKit
import SwiftUI

/// FR-2, FR-39
struct AlarmEditor: View {
    @ObservedObject var session: EditSession
    let isNew: Bool
    let onSave: (Alarm) -> Void
    let onDelete: (Alarm) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let width: CGFloat = 460

    var body: some View {
        VStack(spacing: 0) {
            OverlayPreview(alarm: session.draft, date: previewDate)
                .padding(16)
            VStack(spacing: 16) {
                FieldRow(title: "시각") {
                    TimeEntry(hour: $session.draft.hour, minute: $session.draft.minute)
                }
                FieldRow(title: "내용") {
                    TextField("알람", text: $session.draft.label)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                }
                FieldRow(title: "반복") {
                    WeekdayPicker(weekdays: $session.draft.weekdays)
                }
                FieldRow(title: "색") {
                    ColorChooser(color: $session.draft.color)
                }
                FieldRow(title: "농도") {
                    HStack(spacing: 12) {
                        Slider(value: alphaBinding, in: RGBA.glassAlphaRange)
                            .controlSize(.small)
                        Text("\(Int((session.draft.color.glassTint.a * 100).rounded()))%")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            Divider()
            HStack(spacing: 8) {
                if !isNew {
                    Button("삭제", role: .destructive) {
                        onDelete(session.draft)
                        dismiss()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("저장") {
                    session.draft.isEnabled = isNew || session.draft.isEnabled
                    session.draft.color = session.draft.color.glassTint
                    onSave(session.draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .padding(16)
        }
        .frame(width: Self.width)
    }

    private var previewDate: Date? {
        var alarm = session.draft
        alarm.isEnabled = true
        return AlarmSchedule.nextFireDate(for: alarm, after: Date(), calendar: .current)
    }

    /// FR-2c: 저장값이 범위를 벗어나도 슬라이더는 잘린 값에서 시작한다.
    private var alphaBinding: Binding<Double> {
        Binding(
            get: { session.draft.color.glassTint.a },
            set: { session.draft.color.a = $0 }
        )
    }
}

private struct FieldRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 시각 (FR-2d)

private enum TimeField: Hashable {
    case hour
    case minute

    var modulo: Int { self == .hour ? 24 : 60 }
}

private struct TimeEntry: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @FocusState private var focus: TimeField?
    @StateObject private var scroll = ScrollStepper()
    /// 두 자리 입력 중 첫 자리. SwiftUI `@State` 매크로 플러그인이 CLT 에 없어 `State` 를 직접 보관한다.
    private let pendingDigit = State<Int?>(initialValue: nil)

    var body: some View {
        HStack(spacing: 4) {
            digitBox(.hour, value: hour)
            Text(":")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
            digitBox(.minute, value: minute)
        }
        .onAppear {
            focus = .hour
            scroll.install { field, delta in step(field, by: delta) }
        }
        .onDisappear { scroll.uninstall() }
        .onChange(of: focus) { pendingDigit.wrappedValue = nil }
    }

    private func digitBox(_ field: TimeField, value: Int) -> some View {
        let isFocused = focus == field
        return Text(String(format: "%02d", value))
            .font(.system(size: 32, weight: .regular).monospacedDigit())
            .frame(width: 72, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(isFocused ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFocused ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isFocused ? 2 : 1)
            )
            .contentShape(Rectangle())
            .focusable()
            .focused($focus, equals: field)
            .focusEffectDisabled()
            .onTapGesture { focus = field }
            .onHover { inside in
                if inside {
                    scroll.hovered = field
                } else if scroll.hovered == field {
                    scroll.hovered = nil
                }
            }
            .onKeyPress(.upArrow) {
                step(field, by: 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                step(field, by: -1)
                return .handled
            }
            .onKeyPress(characters: .decimalDigits) { press in
                type(press.characters, into: field)
                return .handled
            }
            .help("숫자를 입력하거나 ↑↓ 키, 스크롤로 조정")
    }

    private func set(_ field: TimeField, _ value: Int) {
        switch field {
        case .hour: hour = value
        case .minute: minute = value
        }
    }

    private func step(_ field: TimeField, by delta: Int) {
        pendingDigit.wrappedValue = nil
        set(field, TimeStep.cycle(field == .hour ? hour : minute, by: delta, modulo: field.modulo))
    }

    /// 두 자리를 연속으로 치면 그 값이 된다. 시를 다 입력하면 분으로 넘어간다.
    private func type(_ characters: String, into field: TimeField) {
        guard let digit = Int(characters) else { return }
        if let first = pendingDigit.wrappedValue, first * 10 + digit < field.modulo {
            set(field, first * 10 + digit)
            pendingDigit.wrappedValue = nil
            advance(from: field)
            return
        }
        set(field, digit)
        if digit * 10 < field.modulo {
            pendingDigit.wrappedValue = digit
        } else {
            pendingDigit.wrappedValue = nil
            advance(from: field)
        }
    }

    private func advance(from field: TimeField) {
        if field == .hour {
            focus = .minute
        }
    }
}

/// 숫자 칸 위에서 스크롤하면 값을 바꾼다. SwiftUI 에 스크롤 휠 이벤트가 없어 로컬 모니터를 쓴다.
@MainActor
private final class ScrollStepper: ObservableObject {
    var hovered: TimeField?

    private static let preciseStepDistance: CGFloat = 8
    private var monitor: Any?
    private var accumulated: CGFloat = 0

    func install(onStep: @escaping (TimeField, Int) -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let deltaY = event.scrollingDeltaY
            let isPrecise = event.hasPreciseScrollingDeltas
            let consumed = MainActor.assumeIsolated {
                self?.consume(deltaY: deltaY, isPrecise: isPrecise, onStep: onStep) ?? false
            }
            return consumed ? nil : event
        }
    }

    func uninstall() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func consume(deltaY: CGFloat, isPrecise: Bool, onStep: (TimeField, Int) -> Void) -> Bool {
        guard let field = hovered else { return false }
        if !isPrecise {
            if deltaY != 0 {
                onStep(field, deltaY > 0 ? 1 : -1)
            }
            return true
        }
        accumulated += deltaY
        let steps = Int(accumulated / Self.preciseStepDistance)
        if steps != 0 {
            accumulated -= CGFloat(steps) * Self.preciseStepDistance
            onStep(field, steps)
        }
        return true
    }
}

// MARK: - 반복

private struct WeekdayPicker: View {
    @Binding var weekdays: Set<Int>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.all, id: \.value) { day in
                let isOn = weekdays.contains(day.value)
                Button {
                    if isOn {
                        weekdays.remove(day.value)
                    } else {
                        weekdays.insert(day.value)
                    }
                } label: {
                    Text(day.symbol)
                        .font(.system(size: 13, weight: isOn ? .medium : .regular))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .frame(width: 32, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isOn ? Color.accentColor : Color.primary.opacity(0.06))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 8)
            preset("매일", Weekday.everyday)
            preset("평일", Weekday.weekdays)
            preset("주말", Weekday.weekend)
        }
        .help("아무 요일도 고르지 않으면 한 번만 울립니다")
    }

    /// 같은 묶음을 다시 누르면 해제한다.
    private func preset(_ title: String, _ days: Set<Int>) -> some View {
        Button(title) {
            weekdays = weekdays == days ? [] : days
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(weekdays == days ? Color.accentColor : Color.secondary)
    }
}

// MARK: - 색 (FR-2a, FR-2b)

private enum GlassPalette {
    struct Preset: Identifiable {
        let name: String
        let rgb: RGBA
        var id: String { name }
    }

    private static func hex(_ value: Int) -> RGBA {
        RGBA(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255,
            a: 1
        )
    }

    static let presets: [Preset] = [
        Preset(name: "먹", rgb: hex(0x000000)),
        Preset(name: "남", rgb: hex(0x1F3A5F)),
        Preset(name: "청록", rgb: hex(0x2A6F73)),
        Preset(name: "이끼", rgb: hex(0x4A6B3A)),
        Preset(name: "호박", rgb: hex(0xD99A2B)),
        Preset(name: "노을", rgb: hex(0xD9634A)),
        Preset(name: "장미", rgb: hex(0xB5476B)),
        Preset(name: "자두", rgb: hex(0x5B3A6E)),
        Preset(name: "안개", rgb: hex(0xE9E6DF)),
    ]

    private static let matchTolerance = 0.01

    static func matches(_ a: RGBA, _ b: RGBA) -> Bool {
        abs(a.r - b.r) < matchTolerance && abs(a.g - b.g) < matchTolerance && abs(a.b - b.b) < matchTolerance
    }
}

private struct ColorChooser: View {
    @Binding var color: RGBA
    @StateObject private var panel = ColorPanelBridge()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GlassPalette.presets) { preset in
                Button {
                    color = RGBA(r: preset.rgb.r, g: preset.rgb.g, b: preset.rgb.b, a: color.a)
                } label: {
                    Swatch(rgb: preset.rgb, isSelected: GlassPalette.matches(preset.rgb, color))
                }
                .buttonStyle(.plain)
                .help(preset.name)
            }
            if !GlassPalette.presets.contains(where: { GlassPalette.matches($0.rgb, color) }) {
                Swatch(rgb: color, isSelected: true)
            }
            Spacer(minLength: 8)
            Button {
                panel.open(current: color) { picked in
                    color = RGBA(r: picked.r, g: picked.g, b: picked.b, a: color.a)
                }
            } label: {
                Label("다른 색", systemImage: "eyedropper")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .onDisappear { panel.close() }
    }
}

private struct Swatch: View {
    let rgb: RGBA
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1))
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
            .frame(width: 20, height: 20)
            .padding(3)
            .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
            .contentShape(Circle())
    }
}

/// FR-2b: 시스템 색 패널을 편집 창 옆에 띄우고, 색상만 받는다(농도는 슬라이더 담당).
@MainActor
private final class ColorPanelBridge: NSObject, ObservableObject {
    private static let gap: CGFloat = 8
    private var onChange: ((RGBA) -> Void)?

    func open(current: RGBA, onChange: @escaping (RGBA) -> Void) {
        let anchor = NSApp.keyWindow
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = NSColor(srgbRed: current.r, green: current.g, blue: current.b, alpha: 1)
        self.onChange = onChange
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        if let anchor {
            place(panel, beside: anchor)
        }
        panel.orderFront(nil)
    }

    func close() {
        guard onChange != nil else { return }
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.orderOut(nil)
        onChange = nil
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
        onChange?(RGBA(r: rgb.redComponent, g: rgb.greenComponent, b: rgb.blueComponent, a: 1))
    }

    /// 창 오른쪽에 붙이고, 화면을 벗어나면 왼쪽에 붙인다.
    private func place(_ panel: NSPanel, beside window: NSWindow) {
        guard let visible = (window.screen ?? NSScreen.main)?.visibleFrame else { return }
        let size = panel.frame.size
        var x = window.frame.maxX + Self.gap
        if x + size.width > visible.maxX {
            x = window.frame.minX - Self.gap - size.width
        }
        x = min(max(x, visible.minX), visible.maxX - size.width)
        let y = min(max(window.frame.maxY - size.height, visible.minY), visible.maxY - size.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
