import SwiftUI

@main
struct ScreenAlarmApp: App {
    @StateObject private var controller = AlarmController()

    var body: some Scene {
        MenuBarExtra("ScreenAlarm", systemImage: "alarm") {
            MenuContent(controller: controller)
        }

        Window("ScreenAlarm", id: AlarmListView.windowID) {
            AlarmListView(controller: controller)
        }
        .windowResizability(.contentSize)
    }
}

/// FR-31, FR-33, FR-35
private struct MenuContent: View {
    @ObservedObject var controller: AlarmController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(controller.nextFireText)
        Divider()
        Button("알람 관리…") {
            openWindow(id: AlarmListView.windowID)
            ManageWindow.bringToFront()
        }
        Toggle(loginTitle, isOn: Binding(
            get: { controller.loginStatus == .enabled || controller.loginStatus == .requiresApproval },
            set: { controller.setLaunchAtLogin($0) }
        ))
        Divider()
        Button("종료") { NSApp.terminate(nil) }
    }

    private var loginTitle: String {
        controller.loginStatus == .requiresApproval ? "로그인 시 실행 (승인 필요)" : "로그인 시 실행"
    }
}

/// FR-32: 메뉴바 앱은 협조적 활성화(`NSApp.activate()`)가 무시될 수 있어, 창을 직접 맨 앞으로 올린다.
@MainActor
private enum ManageWindow {
    static func bringToFront() {
        // 메뉴가 닫힌 뒤에 실행해야 활성화가 메뉴 추적에 묻히지 않는다.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix(AlarmListView.windowID) == true }) else {
                return
            }
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
