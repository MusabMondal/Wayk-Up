import AVFoundation

@MainActor final class AlarmSoundPlayer: AlarmSoundPlaying {
    private var player: AVAudioPlayer?
    private var wantsPlayback = false
    private var isInterrupted = false
    private var notificationTask: Task<Void, Never>?

    init() {
        notificationTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
                guard !Task.isCancelled else { return }
                guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { continue }
                self?.handleInterruption(type)
            }
        }
    }
    deinit { notificationTask?.cancel() }

    private func handleInterruption(_ rawType: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        isInterrupted = type == .began
        if type == .ended, wantsPlayback {
            // Only resume an outstanding alarm; never resurrect one stopped or snoozed.
            do { try play() } catch { /* Foreground reconciliation retries playback. */ }
        }
    }
    func prepare() throws {
        guard player == nil else { return }
        guard let url = Bundle.main.url(forResource: "wake", withExtension: "wav") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let audioPlayer = try AVAudioPlayer(contentsOf: url)
        // Full player gain; device output volume remains under user control.
        audioPlayer.volume = 1.0
        audioPlayer.numberOfLoops = -1
        guard audioPlayer.prepareToPlay() else { throw PlaybackError.unavailable }
        player = audioPlayer
    }
    func play() throws {
        wantsPlayback = true
        guard !isInterrupted else { return }
        guard player?.isPlaying != true else { return }
        try prepare()
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        guard player?.play() == true else { throw PlaybackError.unavailable }
    }
    enum PlaybackError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Could not play wake.wav. Check the bundled audio file and try again." }
    }
    func stop() {
        wantsPlayback = false
        player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
