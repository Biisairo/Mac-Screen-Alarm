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
            NSApp.activate()
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
