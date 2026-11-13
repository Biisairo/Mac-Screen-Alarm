import AlarmCore
import AppKit
import SwiftUI

/// FR-20~FR-24: 모든 화면을 덮는 반투명 색 오버레이.
@MainActor
final class OverlayController: NSObject {
    var onDismiss: () -> Void = {}

    private var panels: [OverlayPanel] = []

    func show(_ alarm: Alarm) {
        hide()
        let primary = NSScreen.screens.first
        for screen in NSScreen.screens {
            let panel = OverlayPanel(screen: screen)
            panel.contentView = makeContent(alarm: alarm, showsCard: screen == primary)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        panels.first?.makeKey()
        NSApp.activate()
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    @objc private func dismissTapped() {
        onDismiss()
    }

    /// FR-21: 블러 없이 색만 덮는다. 아래 화면이 그대로 비쳐 보인다.
    private func makeContent(alarm: Alarm, showsCard: Bool) -> NSView {
        let tint = alarm.color.glassTint
        let cover = NSView()
        cover.wantsLayer = true
        cover.layer?.backgroundColor = NSColor(tint).cgColor

        if showsCard {
            let message = makeMessage(alarm: alarm, ink: GlassInk(tint))
            cover.addSubview(message)
            NSLayoutConstraint.activate([
                message.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
                message.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
                message.widthAnchor.constraint(lessThanOrEqualTo: cover.widthAnchor, multiplier: 0.7),
            ])
        }
        return cover
    }

    /// FR-22: 카드 없이 색 덮개 위에 날짜·시각·내용·끄기 버튼을 놓는다.
    private func makeMessage(alarm: Alarm, ink: GlassInk) -> NSView {
        let date = NSTextField(labelWithString: OverlayText.date(Date()))
        date.font = .systemFont(ofSize: 17)
        date.textColor = NSColor(ink.secondary)

        let time = NSTextField(labelWithString: OverlayText.time(alarm))
        time.font = .monospacedDigitSystemFont(ofSize: 128, weight: .regular)
        time.textColor = NSColor(ink.primary)

        let label = NSTextField(wrappingLabelWithString: alarm.label.isEmpty ? Alarm.defaultLabel : alarm.label)
        label.font = .systemFont(ofSize: 28)
        label.textColor = NSColor(ink.primary)
        label.alignment = .center

        let button = GlassButton(title: "알람 끄기", ink: ink, target: self, action: #selector(dismissTapped))

        let stack = NSStackView(views: [date, time, label, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(0, after: date)
        stack.setCustomSpacing(48, after: label)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(ink.shadow)
        shadow.shadowBlurRadius = GlassInk.shadowRadius
        shadow.shadowOffset = .zero
        stack.wantsLayer = true
        stack.shadow = shadow
        return stack
    }

    private func pin(_ child: NSView, to parent: NSView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        ])
    }
}

/// 다른 앱이 활성 상태여도 키 입력을 가로채도록 nonactivating 패널을 쓴다.
private final class OverlayPanel: NSPanel {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // FR-24: 키보드로는 해제·조작할 수 없다.
    override func keyDown(with event: NSEvent) {}
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
}

/// FR-24: 마우스로만 누를 수 있는 유리 버튼.
private final class GlassButton: NSButton {
    private static let height: CGFloat = 48
    private static let minWidth: CGFloat = 200
    private static let cornerRadius: CGFloat = 12
    private static let pressedOpacity: Float = 0.7

    private let fill: NSColor
    private let hoverFill: NSColor
    private var hoverArea: NSTrackingArea?

    init(title: String, ink: GlassInk, target: AnyObject, action: Selector) {
        fill = NSColor(ink.fill)
        hoverFill = NSColor(ink.hoverFill)
        super.init(frame: .zero)
        self.target = target
        self.action = action
        isBordered = false
        keyEquivalent = ""
        refusesFirstResponder = true
        attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor(ink.primary),
            .font: NSFont.systemFont(ofSize: 17, weight: .medium),
        ])
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(ink.border).cgColor
        layer?.backgroundColor = fill.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minWidth),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea {
            removeTrackingArea(hoverArea)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = hoverFill.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = fill.cgColor
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        layer?.opacity = flag ? Self.pressedOpacity : 1
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

extension NSColor {
    convenience init(_ rgba: RGBA) {
        self.init(srgbRed: rgba.r, green: rgba.g, blue: rgba.b, alpha: rgba.a)
    }
}
