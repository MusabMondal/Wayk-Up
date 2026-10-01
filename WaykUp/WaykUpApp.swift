import SwiftUI

@main struct WaykUpApp: App {
    @State private var store = AlarmStore(scheduler: SystemAlarmScheduler(), repository: FileAlarmRepository(),
                                          generator: RandomMathQuestionGenerator(), sound: AlarmSoundPlayer())
    var body: some Scene {
        WindowGroup { AlarmHomeView(store: store).preferredColorScheme(.dark) }
    }
}
