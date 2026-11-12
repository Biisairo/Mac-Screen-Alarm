import AlarmCore
import AppKit
import ServiceManagement

@MainActor
final class AlarmController: ObservableObject {
    @Published private(set) var alarms: [Alarm]
    @Published private(set) var nextFireText = ""
    @Published private(set) var loginStatus = SMAppService.mainApp.status

    private static let tickInterval: TimeInterval = 1
    private static let tickTolerance: TimeInterval = 0.2
    private static let loginStatusRefreshSeconds = 10
    private static let didAutoRegisterLoginKey = "didAutoRegisterLoginItem"

    private let store: AlarmStore
    private let overlay = OverlayController()
    private var queue = AlarmQueue()
    private var lastCheck = Date()
    private var timer: Timer?

    init(store: AlarmStore = AlarmStore(fileURL: AlarmStore.defaultFileURL())) {
        self.store = store
        alarms = AlarmSchedule.sorted(store.load())
        overlay.onDismiss = { [weak self] in self?.dismissCurrent() }
        refreshNextFireText(now: lastCheck)
        registerLoginItemOnFirstLaunch()
        startTimer()
    }

    // MARK: - 알람 관리 (FR-2~FR-6)

    func upsert(_ alarm: Alarm) {
        var updated = alarms.filter { $0.id != alarm.id }
        updated.append(alarm)
        commit(updated)
    }

    func delete(_ alarm: Alarm) {
        commit(alarms.filter { $0.id != alarm.id })
    }

    func setEnabled(_ alarm: Alarm, _ isEnabled: Bool) {
        var updated = alarm
        updated.isEnabled = isEnabled
        upsert(updated)
    }

    // MARK: - 로그인 시 실행 (FR-33~FR-35)

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        if enabled {
            try? service.register()
        } else {
            try? service.unregister()
        }
        loginStatus = service.status
        if enabled, loginStatus == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func registerLoginItemOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.didAutoRegisterLoginKey) else { return }
        defaults.set(true, forKey: Self.didAutoRegisterLoginKey)
        setLaunchAtLogin(true)
    }

    /// 시스템 설정에서 승인·해제한 결과를 메뉴에 반영한다.
    private func refreshLoginStatus(now: Date) {
        guard Int(now.timeIntervalSince1970) % Self.loginStatusRefreshSeconds == 0 else { return }
        let status = SMAppService.mainApp.status
        if status != loginStatus {
            loginStatus = status
        }
    }

    // MARK: - 발화 (FR-10~FR-14)

    private func startTimer() {
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = Self.tickTolerance
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = Date()
        let due = AlarmSchedule.dueAlarms(alarms, from: lastCheck, to: now, calendar: .current)
        lastCheck = now
        if !due.isEmpty {
            commit(AlarmSchedule.afterFiring(alarms, fired: due))
            let wasIdle = queue.current == nil
            queue.enqueue(due)
            if wasIdle, let current = queue.current {
                overlay.show(current)
            }
        }
        refreshNextFireText(now: now)
        refreshLoginStatus(now: now)
    }

    private func dismissCurrent() {
        queue.dismiss()
        if let next = queue.current {
            overlay.show(next)
        } else {
            overlay.hide()
        }
    }

    // MARK: - 내부

    private func commit(_ updated: [Alarm]) {
        alarms = AlarmSchedule.sorted(updated)
        store.save(alarms)
        refreshNextFireText(now: Date())
    }

    private func refreshNextFireText(now: Date) {
        let text: String
        if let next = AlarmSchedule.nextFire(in: alarms, after: now, calendar: .current) {
            text = "다음 알람: " + next.date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        } else {
            text = "예정된 알람 없음"
        }
        if text != nextFireText {
            nextFireText = text
        }
    }
}
