import SwiftUI

struct MathChallengeView: View {
    @Bindable var store: AlarmStore
    @State private var answer = ""
    @State private var feedback: String?
    @FocusState private var focused: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "sun.max.fill").font(.system(size: 56)).foregroundStyle(.orange)
                Text(store.isPreview ? "Practice morning" : "Time to Wayk Up").font(.largeTitle.bold())
                Text(store.activeAlarm?.label ?? "").foregroundStyle(.secondary)
                if let session = store.session {
                    ProgressView(value: Double(session.completedCount), total: 2).tint(.orange)
                    if let question = session.currentQuestion {
                        Text("QUESTION \(session.completedCount + 1) OF 2").font(.caption.bold()).foregroundStyle(.orange)
                        Text(question.prompt).font(.system(size: 64, weight: .bold, design: .rounded)).minimumScaleFactor(0.5)
                        TextField("Your answer", text: $answer)
                            .keyboardType(.numberPad).focused($focused)
                            .font(.largeTitle).multilineTextAlignment(.center)
                            .padding().background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                            .onSubmit(submit)
                            .accessibilityLabel("Answer to \(question.prompt)")
                        if let feedback { Text(feedback).foregroundStyle(.orange).accessibilityLabel(feedback) }
                        Button("Check answer", action: submit).buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(Int(answer) == nil)
                    } else {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(.green)
                        Text("You’re awake!").font(.title.bold())
                        Text("Both questions complete.").foregroundStyle(.secondary)
                        Button("Stop alarm") { store.stop() }.buttonStyle(.borderedProminent).controlSize(.large)
                        Button(store.isPreview ? "Finish practice" : "Snooze for \(store.snoozeMinutes) minutes") {
                            Task { await store.snooze() }
                        }.buttonStyle(.bordered).controlSize(.large)
                    }
                }
            }.padding(32).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }.background(Color(red: 0.055, green: 0.065, blue: 0.1)).tint(.orange)
            .disabled(store.isBusy)
            .alert("Alarm action failed", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
    }
    private func submit() {
        guard let number = Int(answer) else { return }
        if store.submit(number) {
            answer = ""; feedback = nil
            if store.session?.isComplete == true { focused = false }
        } else { feedback = "Not quite. Try again."; answer = "" }
    }
}
