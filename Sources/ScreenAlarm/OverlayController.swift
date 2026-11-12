import AlarmCore
import AppKit

/// FR-20~FR-24: 모든 화면을 덮는 블러 오버레이.
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

    private func makeContent(alarm: Alarm, showsCard: Bool) -> NSView {
        let blur = NSVisualEffectView()
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active

        let tint = NSView()
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor(alarm.color).cgColor
        pin(tint, to: blur)

        if showsCard {
            let card = makeCard(alarm: alarm)
            blur.addSubview(card)
            NSLayoutConstraint.activate([
                card.centerXAnchor.constraint(equalTo: blur.centerXAnchor),
                card.centerYAnchor.constraint(equalTo: blur.centerYAnchor),
                card.widthAnchor.constraint(lessThanOrEqualTo: blur.widthAnchor, multiplier: 0.6),
            ])
        }
        return blur
    }

    private func makeCard(alarm: Alarm) -> NSView {
        let card = NSVisualEffectView()
        card.material = .hudWindow
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false

        let time = NSTextField(labelWithString: String(format: "%02d:%02d", alarm.hour, alarm.minute))
        time.font = .monospacedDigitSystemFont(ofSize: 56, weight: .semibold)

        let label = NSTextField(wrappingLabelWithString: alarm.label)
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.alignment = .center

        let button = NSButton(title: "알람 끄기", target: self, action: #selector(dismissTapped))
        button.bezelStyle = .push
        button.controlSize = .large
        button.font = .systemFont(ofSize: 17, weight: .semibold)
        button.keyEquivalent = ""
        button.refusesFirstResponder = true

        let stack = NSStackView(views: [time, label, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 20
        stack.setCustomSpacing(32, after: label)
        stack.edgeInsets = NSEdgeInsets(top: 40, left: 56, bottom: 40, right: 56)
        pin(stack, to: card)
        return card
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

extension NSColor {
    convenience init(_ rgba: RGBA) {
        self.init(srgbRed: rgba.r, green: rgba.g, blue: rgba.b, alpha: rgba.a)
    }
}
