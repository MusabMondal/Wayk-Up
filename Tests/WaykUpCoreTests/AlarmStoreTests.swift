import Foundation
import Testing
@testable import WaykUpCore

private final class MemoryRepository: AlarmPersisting {
    var alarms: [WakeAlarm]
    init(_ alarms: [WakeAlarm] = []) { self.alarms = alarms }
    func load() throws -> [WakeAlarm] { alarms }
    func save(_ alarms: [WakeAlarm]) throws { self.alarms = alarms }
}
@MainActor private final class FakeScheduler: AlarmScheduling {
    var snapshots: [ScheduledAlarmSnapshot] = []
    var stopped: [UUID] = []
    var onSchedule: (() -> Void)?
    var shouldFailSchedule = false
    func schedule(_ alarm: WakeAlarm) async throws {
        if shouldFailSchedule { throw CocoaError(.fileWriteUnknown) }
        onSchedule?()
        await Task.yield()
        snapshots.removeAll { $0.id == alarm.id }
        snapshots.append(ScheduledAlarmSnapshot(id: alarm.id, isAlerting: false))
    }
    func cancel(id: UUID) throws { snapshots.removeAll { $0.id == id } }
    func stop(id: UUID) throws { stopped.append(id); try cancel(id: id) }
    func currentAlarms() throws -> [ScheduledAlarmSnapshot] { snapshots }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}
@MainActor private final class FakeSound: AlarmSoundPlaying {
    var playing = false
    func prepare() throws {}
    func play() throws { playing = true }
    func stop() { playing = false }
}
private struct KnownQuestions: MathQuestionGenerating {
    func makeQuestions(count: Int) -> [MathQuestion] {
        [MathQuestion(left: 2, right: 3, operation: .addition),
         MathQuestion(left: 2, right: 3, operation: .multiplication)]
    }
}
@MainActor @Test func completedHistoryIsRemovedOnLoad() {
    let active = WakeAlarm(date: .now.addingTimeInterval(3600))
    let repository = MemoryRepository([active, WakeAlarm(date: .now, isEnabled: false)])
    let store = AlarmStore(scheduler: FakeScheduler(), repository: repository, generator: KnownQuestions(), sound: FakeSound())
    #expect(store.alarms == [active])
    #expect(repository.alarms == [active])
}
@MainActor @Test func audioHandoffKeepsChallengeThenStopRemovesRecord() {
    let alarm = WakeAlarm(date: .now)
    let repository = MemoryRepository([alarm])
    let scheduler = FakeScheduler()
    let sound = FakeSound()
    scheduler.snapshots = [ScheduledAlarmSnapshot(id: alarm.id, isAlerting: true)]
    let store = AlarmStore(scheduler: scheduler, repository: repository, generator: KnownQuestions(), sound: sound)
    store.synchronize()
    #expect(scheduler.stopped.contains(alarm.id))
    #expect(sound.playing)
    store.synchronize()
    #expect(store.alarms == [alarm])
    store.stop()
    #expect(store.activeAlarm != nil)
    _ = store.submit(5); _ = store.submit(6)
    store.stop()
    #expect(store.alarms.isEmpty)
    #expect(repository.alarms.isEmpty)
    #expect(store.activeAlarm == nil)
    #expect(!sound.playing)
}
@MainActor @Test func snoozedAlarmRemainsAndRequiresFreshQuestions() async {
    let alarm = WakeAlarm(date: .now)
    let repository = MemoryRepository([alarm])
    let scheduler = FakeScheduler()
    scheduler.snapshots = [ScheduledAlarmSnapshot(id: alarm.id, isAlerting: true)]
    let store = AlarmStore(scheduler: scheduler, repository: repository, generator: KnownQuestions(), sound: FakeSound())
    store.synchronize()
    _ = store.submit(5); _ = store.submit(6)
    await store.snooze()
    #expect(store.activeAlarm == nil)
    #expect(store.alarms.count == 1)
    #expect(repository.alarms == store.alarms)
    #expect(store.alarms[0].date > .now.addingTimeInterval(290))
    let nextID = store.alarms[0].id
    #expect(nextID != alarm.id)
    scheduler.snapshots = [ScheduledAlarmSnapshot(id: nextID, isAlerting: true)]
    store.synchronize()
    #expect(store.session?.completedCount == 0)
    #expect(store.session?.isComplete == false)
}
@MainActor @Test func systemSilencingDoesNotCompleteDueAlarm() {
    let alarm = WakeAlarm(date: .now.addingTimeInterval(-60))
    let repository = MemoryRepository([alarm])
    let store = AlarmStore(scheduler: FakeScheduler(), repository: repository, generator: KnownQuestions(), sound: FakeSound())
    store.setForeground(false)
    store.synchronize()
    #expect(store.activeAlarm == nil)
    #expect(repository.alarms == [alarm])
    store.setForeground(true)
    #expect(store.activeAlarm?.id == alarm.id)
    #expect(store.session?.completedCount == 0)
    #expect(repository.alarms == [alarm])
}

@MainActor @Test func repeatedSnoozesUseFreshOccurrencesAndNeverLosePendingAlarm() async {
    var time = Date.now
    let alarm = WakeAlarm(date: time)
    let repository = MemoryRepository([alarm])
    let scheduler = FakeScheduler()
    let sound = FakeSound()
    let store = AlarmStore(scheduler: scheduler, repository: repository, generator: KnownQuestions(), sound: sound, now: { time })
    scheduler.snapshots = [ScheduledAlarmSnapshot(id: alarm.id, isAlerting: true)]
    store.synchronize()
    var seenIDs = Set([alarm.id])
    for _ in 0..<3 {
        let previousID = store.activeAlarm?.id
        _ = store.submit(5); _ = store.submit(6)
        // Reproduce an update while the old alarm is already stopped and schedule is awaiting.
        scheduler.onSchedule = { store.synchronize() }
        await store.snooze()
        #expect(store.activeAlarm == nil)
        #expect(!sound.playing)
        #expect(store.alarms.count == 1)
        #expect(repository.alarms == store.alarms)
        let next = store.alarms[0]
        #expect(next.id != previousID)
        #expect(!seenIDs.contains(next.id))
        seenIDs.insert(next.id)
        time = next.date.addingTimeInterval(1)
        // No AlarmKit event: foreground deadline detection must still show the challenge.
        store.foregroundTick()
        #expect(store.activeAlarm?.id == next.id)
        #expect(store.session?.completedCount == 0)
        #expect(sound.playing)
    }
    #expect(seenIDs.count == 4)
}
@MainActor @Test func foregroundDeadlineWorksWithoutSystemEventAndCannotBeDeleted() {
    var time = Date.now
    let alarm = WakeAlarm(date: time.addingTimeInterval(60))
    let repository = MemoryRepository([alarm])
    let scheduler = FakeScheduler()
    scheduler.snapshots = [ScheduledAlarmSnapshot(id: alarm.id, isAlerting: false)]
    let sound = FakeSound()
    let store = AlarmStore(scheduler: scheduler, repository: repository, generator: KnownQuestions(), sound: sound, now: { time })
    store.foregroundTick()
    #expect(store.activeAlarm == nil)
    time = alarm.date
    store.delete(alarm)
    #expect(store.alarms.count == 1)
    store.foregroundTick()
    #expect(store.activeAlarm?.id == alarm.id)
    #expect(sound.playing)
}
@MainActor @Test func failedSnoozeKeepsCompletedChallengeAndAudioForRetry() async {
    let alarm = WakeAlarm(date: .now)
    let repository = MemoryRepository([alarm])
    let scheduler = FakeScheduler()
    let sound = FakeSound()
    let store = AlarmStore(scheduler: scheduler, repository: repository, generator: KnownQuestions(), sound: sound)
    store.foregroundTick()
    _ = store.submit(5); _ = store.submit(6)
    scheduler.shouldFailSchedule = true
    await store.snooze()
    #expect(store.activeAlarm?.id == alarm.id)
    #expect(store.session?.isComplete == true)
    #expect(store.alarms == [alarm])
    #expect(sound.playing)
    #expect(!store.isBusy)
    scheduler.shouldFailSchedule = false
    await store.snooze()
    #expect(store.activeAlarm == nil)
    #expect(store.alarms.count == 1)
    #expect(store.alarms[0].id != alarm.id)
}
@MainActor @Test func canceledFutureAlarmIsRemovedWithoutStartingChallenge() {
    let repository = MemoryRepository([WakeAlarm(date: .now.addingTimeInterval(600))])
    let store = AlarmStore(scheduler: FakeScheduler(), repository: repository, generator: KnownQuestions(), sound: FakeSound())
    store.synchronize()
    #expect(store.alarms.isEmpty)
    #expect(repository.alarms.isEmpty)
    #expect(store.activeAlarm == nil)
}
