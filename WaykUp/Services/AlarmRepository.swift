import Foundation

protocol AlarmPersisting {
    func load() throws -> [WakeAlarm]
    func save(_ alarms: [WakeAlarm]) throws
}

struct FileAlarmRepository: AlarmPersisting {
    private let url: URL
    init() {
        url = URL.applicationSupportDirectory.appending(path: "WaykUp/alarms.json")
    }
    func load() throws -> [WakeAlarm] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([WakeAlarm].self, from: Data(contentsOf: url))
    }
    func save(_ alarms: [WakeAlarm]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(alarms).write(to: url, options: .atomic)
    }
}
