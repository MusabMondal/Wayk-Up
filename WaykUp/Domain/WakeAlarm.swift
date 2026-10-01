import Foundation

struct WakeAlarm: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var label: String
    var isEnabled: Bool
    init(id: UUID = UUID(), date: Date, label: String = "Rise and shine", isEnabled: Bool = true) {
        self.id = id; self.date = date; self.label = label; self.isEnabled = isEnabled
    }
}
