import Foundation

struct ScheduledAlarmSnapshot {
    let id: UUID
    let isAlerting: Bool
}

@MainActor protocol AlarmScheduling {
    func schedule(_ alarm: WakeAlarm) async throws
    func cancel(id: UUID) throws
    func stop(id: UUID) throws
    func currentAlarms() throws -> [ScheduledAlarmSnapshot]
    func changes() -> AsyncStream<Void>
}


@MainActor protocol AlarmSoundPlaying {
    func prepare() throws
    func play() throws
    func stop()
}

