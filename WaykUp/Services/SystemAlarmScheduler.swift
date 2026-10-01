@preconcurrency import AlarmKit
import AppIntents
import SwiftUI

struct WakeMetadata: AlarmMetadata {}

struct OpenChallengeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Solve wake-up challenge"
    static let openAppWhenRun = true
    @Parameter(title: "Alarm ID") var alarmID: String
    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(alarmID, forKey: "pendingChallenge")
        return .result()
    }
}

@MainActor final class SystemAlarmScheduler: AlarmScheduling {
    private let manager = AlarmManager.shared
    func schedule(_ alarm: WakeAlarm) async throws {
        guard Bundle.main.url(forResource: "wake", withExtension: "wav") != nil else {
            throw CocoaError(.fileNoSuchFile)
        }
        let authorization = try await manager.requestAuthorization()
        guard authorization == .authorized else { throw SchedulingError.permissionDenied }
        let alert = AlarmPresentation.Alert(
            title: "Wayk Up", stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: AlarmButton(text: "Solve math", textColor: .white, systemImageName: "plus.forwardslash.minus"),
            secondaryButtonBehavior: .custom)
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: WakeMetadata(), tintColor: .orange)
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(alarm.date), attributes: attributes,
            stopIntent: OpenChallengeIntent(alarmID: alarm.id),
            secondaryIntent: OpenChallengeIntent(alarmID: alarm.id),
            sound: .named("wake.wav"))
        _ = try await manager.schedule(id: alarm.id, configuration: configuration)
    }
    func cancel(id: UUID) throws { try manager.cancel(id: id) }
    func stop(id: UUID) throws {
        if try manager.alarms.contains(where: { $0.id == id }) { try manager.stop(id: id) }
    }
    func currentAlarms() throws -> [ScheduledAlarmSnapshot] {
        try manager.alarms.map { ScheduledAlarmSnapshot(id: $0.id, isAlerting: $0.state == .alerting) }
    }
    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                for await _ in manager.alarmUpdates {
                    guard !Task.isCancelled else { break }
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    enum SchedulingError: LocalizedError {
        case permissionDenied
        var errorDescription: String? { "Allow alarms for Wayk Up in Settings to schedule a wake-up alarm." }
    }
}
