import Foundation
import Observation

@MainActor @Observable final class AlarmStore {
    private(set) var alarms: [WakeAlarm] = []
    private(set) var activeAlarm: WakeAlarm?
    private(set) var session: MathChallengeSession?
    private(set) var isPreview = false
    private(set) var isBusy = false
    private(set) var isForeground = true
    var errorMessage: String?
    let snoozeMinutes = 5
    private let scheduler: any AlarmScheduling
    private let repository: any AlarmPersisting
    private let generator: any MathQuestionGenerating
    private let sound: any AlarmSoundPlaying
    private let now: () -> Date

    init(scheduler: any AlarmScheduling, repository: any AlarmPersisting,
         generator: any MathQuestionGenerating, sound: any AlarmSoundPlaying,
         now: @escaping () -> Date = { .now }) {
        self.scheduler = scheduler; self.repository = repository
        self.generator = generator; self.sound = sound; self.now = now
        do {
            let saved = try repository.load()
            alarms = saved.filter(\.isEnabled)
            if alarms != saved { try repository.save(alarms) }
        } catch { errorMessage = error.localizedDescription }
    }
    func add(date: Date, label: String) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true; defer { isBusy = false }
        let alarm = WakeAlarm(date: date, label: label.isEmpty ? "Rise and shine" : label)
        do {
            try await scheduler.schedule(alarm)
            do { try replaceAlarms(alarms + [alarm]) }
            catch { try? scheduler.cancel(id: alarm.id); throw error }
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func delete(_ alarm: WakeAlarm) {
        // Due alarms stay pending until their challenge is solved.
        guard !isBusy, activeAlarm?.id != alarm.id, alarm.date > now() else { return }
        do {
            try scheduler.cancel(id: alarm.id)
            try replaceAlarms(alarms.filter { $0.id != alarm.id })
        } catch { errorMessage = error.localizedDescription }
    }
    func preview() {
        guard activeAlarm == nil, !isBusy else { return }
        begin(WakeAlarm(date: now(), label: "Try your wake-up challenge"), preview: true)
    }
    private func begin(_ alarm: WakeAlarm, preview: Bool = false) {
        guard activeAlarm == nil else { return }
        activeAlarm = alarm; isPreview = preview
        session = MathChallengeSession(generator: generator)
        do {
            // Validate the file before silencing system playback.
            try sound.prepare()
            if !preview { try scheduler.stop(id: alarm.id) }
            try sound.play()
        } catch { errorMessage = error.localizedDescription }
    }
    func submit(_ answer: Int) -> Bool { session?.submit(answer) ?? false }
    func stop() {
        guard session?.isComplete == true, let alarm = activeAlarm, !isBusy else { return }
        do {
            if !isPreview {
                try scheduler.stop(id: alarm.id)
                try replaceAlarms(alarms.filter { $0.id != alarm.id })
            }
            finish()
            foregroundTick()
        } catch { errorMessage = error.localizedDescription }
    }
    func snooze() async {
        guard session?.isComplete == true, let previous = activeAlarm, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        if isPreview { finish(); return }
        // A fresh occurrence avoids stale system state from a previously stopped ID.
        let next = WakeAlarm(date: now().addingTimeInterval(Double(snoozeMinutes * 60)), label: previous.label)
        do {
            try await scheduler.schedule(next)
            do {
                try scheduler.stop(id: previous.id)
                let updated = alarms.map { $0.id == previous.id ? next : $0 }
                try replaceAlarms(updated)
            } catch {
                try? scheduler.cancel(id: next.id)
                throw error
            }
            finish()
        } catch { errorMessage = error.localizedDescription }
    }
    private func replaceAlarms(_ updated: [WakeAlarm]) throws {
        // Publish only after persistence succeeds.
        try repository.save(updated)
        alarms = updated
    }
    private func finish() {
        sound.stop(); activeAlarm = nil; session = nil; isPreview = false
    }
    func setForeground(_ foreground: Bool) {
        isForeground = foreground
        if foreground { synchronize(); foregroundTick() }
    }
    func foregroundTick() {
        guard isForeground, !isBusy else { return }
        if activeAlarm != nil {
            // Reclaim system playback if a delayed alert arrives after the handoff.
            do {
                if !isPreview, let alarm = activeAlarm { try scheduler.stop(id: alarm.id) }
                try sound.play()
            } catch { errorMessage = error.localizedDescription }
            return
        }
        if let due = alarms.filter({ $0.isEnabled && $0.date <= now() }).min(by: { $0.date < $1.date }) {
            begin(due)
        }
    }
    func synchronize() {
        // AlarmKit updates can arrive during an awaited schedule; do not reconcile half a transaction.
        guard !isBusy else { return }
        do {
            let systemAlarms = try scheduler.currentAlarms()
            let pending = UserDefaults.standard.string(forKey: "pendingChallenge").flatMap(UUID.init(uuidString:))
            if isForeground {
                UserDefaults.standard.removeObject(forKey: "pendingChallenge")
                let ringingID = systemAlarms.first(where: { $0.isAlerting })?.id
                if let id = ringingID ?? pending,
                   let alarm = alarms.first(where: { $0.id == id && $0.isEnabled }) { begin(alarm) }
            }
            let systemIDs = Set(systemAlarms.map(\.id))
            // A system dismissal or hardware-button silence is not math completion.
            // Due records remain active and resume their challenge on the next foreground run.
            let retained = alarms.filter {
                $0.isEnabled && (systemIDs.contains($0.id) || $0.date <= now() || activeAlarm?.id == $0.id)
            }
            if retained != alarms { try replaceAlarms(retained) }
            foregroundTick()
        } catch { errorMessage = error.localizedDescription }
    }
    func observe() async {
        synchronize()
        for await _ in scheduler.changes() {
            guard !Task.isCancelled else { return }
            synchronize()
        }
    }
}
