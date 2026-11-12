import Foundation

/// FR-6, FR-7: JSON 파일 저장소.
public struct AlarmStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ScreenAlarm/alarms.json")
    }

    public var backupURL: URL { fileURL.appendingPathExtension("bak") }

    public func load() -> [Alarm] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        if let data = try? Data(contentsOf: fileURL),
           let alarms = try? JSONDecoder().decode([Alarm].self, from: data) {
            return alarms
        }
        if fileManager.fileExists(atPath: backupURL.path) {
            try? fileManager.removeItem(at: backupURL)
        }
        try? fileManager.moveItem(at: fileURL, to: backupURL)
        return []
    }

    @discardableResult
    public func save(_ alarms: [Alarm]) -> Bool {
        let directory = fileURL.deletingLastPathComponent()
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil,
              let data = try? JSONEncoder().encode(alarms)
        else { return false }
        return (try? data.write(to: fileURL, options: .atomic)) != nil
    }
}
