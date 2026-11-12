import AlarmCore
import Foundation

var failures = 0
var passes = 0

@MainActor func check(_ condition: Bool, _ name: String, line: Int = #line) {
    if condition {
        passes += 1
    } else {
        failures += 1
        print("FAIL [\(line)] \(name)")
    }
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

/// 2026-11-13 (금, weekday 6) 기준 날짜 생성.
@MainActor func on(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
}

@MainActor func at(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date { on(13, hour, minute, second) }

@MainActor func alarm(_ hour: Int, _ minute: Int, weekdays: Set<Int> = [], enabled: Bool = true, label: String = "a") -> Alarm {
    Alarm(hour: hour, minute: minute, label: label, weekdays: weekdays, isEnabled: enabled, color: .defaultBlur)
}

@MainActor func due(_ alarms: [Alarm], _ from: Date, _ to: Date) -> [Alarm] {
    AlarmSchedule.dueAlarms(alarms, from: from, to: to, calendar: calendar)
}

// MARK: - FR-11 발화 판정

let tenAM = alarm(10, 0)
check(due([tenAM], at(9, 59, 59), at(10, 0, 0)) == [tenAM], "FR-11 구간 끝(to)과 같은 발화 시각은 포함")
check(due([tenAM], at(10, 0, 0), at(10, 0, 1)).isEmpty, "FR-11 구간 시작(from)과 같은 발화 시각은 제외")
check(due([tenAM], at(10, 0, 1), at(10, 0, 2)).isEmpty, "FR-11 지난 발화 시각은 제외")
check(due([alarm(10, 0, enabled: false)], at(9, 59, 59), at(10, 0, 0)).isEmpty, "FR-11 비활성 알람 제외")
check(due([alarm(10, 0, weekdays: [6])], at(9, 59, 59), at(10, 0, 0)).count == 1, "FR-11 요일 일치(금)")
check(due([alarm(10, 0, weekdays: [1, 2])], at(9, 59, 59), at(10, 0, 0)).isEmpty, "FR-11 요일 불일치")
check(due([], at(9, 59, 59), at(10, 0, 0)).isEmpty, "FR-11 빈 목록")

// 자정 경계: 11/13(금) 23:59:59 → 11/14(토) 00:00:00
let midnightSat = alarm(0, 0, weekdays: [7])
let midnightFri = alarm(0, 0, weekdays: [6])
check(due([midnightSat], on(13, 23, 59, 59), on(14, 0, 0, 0)).count == 1, "FR-11 자정 경계: 다음 날 요일로 판정")
check(due([midnightFri], on(13, 23, 59, 59), on(14, 0, 0, 0)).isEmpty, "FR-11 자정 경계: 이전 날 요일은 제외")

// 같은 시각 알람은 모두 발화
let a1 = alarm(10, 0, label: "first")
let a2 = alarm(10, 0, label: "second")
check(due([a1, alarm(11, 0), a2], at(9, 59, 59), at(10, 0, 0)).map(\.label) == ["first", "second"], "FR-14 같은 시각 알람은 모두 발화")

// MARK: - FR-12 구간 길이 제한

check(due([tenAM], at(9, 59, 50), at(10, 0, 0)).count == 1, "FR-12 구간 정확히 10초는 허용")
check(due([tenAM], at(9, 59, 49), at(10, 0, 0)).isEmpty, "FR-12 구간 10초 초과(잠자기 복귀)는 건너뜀")
check(due([tenAM], at(10, 0, 0), at(10, 0, 0)).isEmpty, "FR-12 구간 길이 0은 건너뜀")
check(due([tenAM], at(10, 0, 5), at(10, 0, 0)).isEmpty, "FR-12 시계 역행은 건너뜀")

// MARK: - FR-13 1회성 알람 비활성화

let once = alarm(10, 0, label: "once")
let repeating = alarm(10, 0, weekdays: [6], label: "rep")
let other = alarm(11, 0, label: "other")
let after = AlarmSchedule.afterFiring([once, repeating, other], fired: [once, repeating])
check(after.first { $0.id == once.id }?.isEnabled == false, "FR-13 1회성 알람은 발화 후 비활성")
check(after.first { $0.id == repeating.id }?.isEnabled == true, "FR-13 반복 알람은 활성 유지")
check(after.first { $0.id == other.id } == other, "FR-13 발화하지 않은 알람은 그대로")
check(after.map(\.id) == [once.id, repeating.id, other.id], "FR-13 순서 유지")

// MARK: - 다음 발화 시각 (FR-31)

check(AlarmSchedule.nextFireDate(for: tenAM, after: at(9, 0), calendar: calendar) == at(10, 0), "다음 발화: 오늘 이후")
check(AlarmSchedule.nextFireDate(for: tenAM, after: at(10, 0), calendar: calendar) == on(14, 10, 0), "다음 발화: 정각 동일 시각은 다음 날")
check(AlarmSchedule.nextFireDate(for: tenAM, after: at(11, 0), calendar: calendar) == on(14, 10, 0), "다음 발화: 지났으면 다음 날")
check(AlarmSchedule.nextFireDate(for: alarm(10, 0, weekdays: [6]), after: at(11, 0), calendar: calendar) == on(20, 10, 0), "다음 발화: 같은 요일 다음 주")
check(AlarmSchedule.nextFireDate(for: alarm(10, 0, weekdays: [2]), after: at(11, 0), calendar: calendar) == on(16, 10, 0), "다음 발화: 다음 월요일")
check(AlarmSchedule.nextFireDate(for: alarm(10, 0, enabled: false), after: at(9, 0), calendar: calendar) == nil, "다음 발화: 비활성은 nil")

let next = AlarmSchedule.nextFire(in: [alarm(12, 0, label: "noon"), alarm(9, 0, label: "nine"), alarm(10, 30, label: "half")], after: at(10, 0), calendar: calendar)
check(next?.alarm.label == "half" && next?.date == at(10, 30), "다음 발화: 전체 중 가장 이른 것")
check(AlarmSchedule.nextFire(in: [alarm(9, 0, enabled: false)], after: at(10, 0), calendar: calendar) == nil, "다음 발화: 활성 알람 없으면 nil")

// MARK: - FR-5 정렬

check(AlarmSchedule.sorted([alarm(12, 0, label: "c"), alarm(9, 30, label: "a"), alarm(9, 45, label: "b")]).map(\.label) == ["a", "b", "c"], "FR-5 시:분 오름차순")

// MARK: - FR-1 기본값

let d1 = Alarm.makeDefault(now: at(10, 15, 30), calendar: calendar)
check(d1.hour == 10 && d1.minute == 16, "FR-1 다음 분")
let d2 = Alarm.makeDefault(now: at(10, 15, 0), calendar: calendar)
check(d2.hour == 10 && d2.minute == 16, "FR-1 정각 초에서도 다음 분")
let d3 = Alarm.makeDefault(now: at(23, 59, 30), calendar: calendar)
check(d3.hour == 0 && d3.minute == 0, "FR-1 자정 넘김")
check(d1.label == "알람" && d1.weekdays.isEmpty && d1.isEnabled && d1.color == RGBA(r: 0, g: 0, b: 0, a: 0.4), "FR-1 기본 내용·반복·활성·색상")

// MARK: - FR-6, FR-7 저장소

let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("screen-alarm-test-\(UUID().uuidString)")
let fileURL = tempDir.appendingPathComponent("nested/alarms.json")
let store = AlarmStore(fileURL: fileURL)

check(store.load().isEmpty, "FR-7 파일 없으면 빈 목록")

let saved = [alarm(7, 30, weekdays: [2, 3], label: "출근"), alarm(22, 0, enabled: false, label: "취침")]
check(store.save(saved), "FR-6 저장 성공(중간 디렉터리 생성)")
check(store.load() == saved, "FR-6 저장 후 복원")

let corrupt = Data("{not json".utf8)
try! FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try! corrupt.write(to: fileURL)
check(store.load().isEmpty, "FR-7 해석 불가 파일은 빈 목록")
let backupURL = fileURL.appendingPathExtension("bak")
check((try? Data(contentsOf: backupURL)) == corrupt, "FR-7 원본을 .bak 으로 보존")
check(!FileManager.default.fileExists(atPath: fileURL.path), "FR-7 원본 파일은 옮겨짐")

try! corrupt.write(to: fileURL)
check(store.load().isEmpty && (try? Data(contentsOf: backupURL)) == corrupt, "FR-7 기존 .bak 이 있어도 덮어써 보존")

try? FileManager.default.removeItem(at: tempDir)

// MARK: - FR-14 큐

var queue = AlarmQueue()
check(queue.current == nil, "FR-14 초기 상태 비어 있음")
queue.enqueue([])
check(queue.current == nil, "FR-14 빈 입력은 무시")
queue.enqueue([a1])
check(queue.current == a1, "FR-14 비어 있으면 바로 현재 알람")
queue.enqueue([a2])
check(queue.current == a1, "FR-14 표시 중 발화는 대기")
queue.dismiss()
check(queue.current == a2, "FR-14 해제 후 다음 알람")
queue.dismiss()
check(queue.current == nil, "FR-14 모두 해제하면 비어 있음")
queue.dismiss()
check(queue.current == nil, "FR-14 빈 큐 해제는 무해")

// MARK: - 결과

print("passed: \(passes), failed: \(failures)")
exit(failures == 0 ? 0 : 1)
