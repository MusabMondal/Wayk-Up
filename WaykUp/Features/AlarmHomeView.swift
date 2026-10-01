import SwiftUI

struct AlarmHomeView: View {
    @Bindable var store: AlarmStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingEditor = false
    var body: some View {
        ZStack {
            home
                .allowsHitTesting(store.activeAlarm == nil)
                .accessibilityHidden(store.activeAlarm != nil)
            if let alarm = store.activeAlarm {
                MathChallengeView(store: store)
                    .id(alarm.id)
                    .zIndex(1)
            }
        }
        .task { await store.observe() }
        .task {
            store.setForeground(scenePhase == .active)
            while !Task.isCancelled {
                store.foregroundTick()
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in store.setForeground(phase == .active) }
        .onChange(of: store.activeAlarm?.id) { _, id in
            if id != nil { showingEditor = false }
        }
    }
    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MAKE MORNINGS COUNT").font(.caption.weight(.bold)).foregroundStyle(.orange)
                        Text("Wayk Up").font(.system(size: 46, weight: .bold, design: .rounded))
                        Text("Two small questions. One fresh start.").foregroundStyle(.secondary)
                    }
                    HStack(spacing: 14) {
                        Image(systemName: "sun.max.fill").font(.largeTitle).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Wake your mind").font(.headline)
                            Text("Solve 2 math questions to unlock Snooze and Stop in the app.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(22).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 24))
                    HStack {
                        Text("Your alarms").font(.title2.bold())
                        Spacer()
                        Button { showingEditor = true } label: { Image(systemName: "plus.circle.fill").font(.title) }
                            .accessibilityLabel("Add alarm")
                    }
                    if store.alarms.isEmpty {
                        ContentUnavailableView("A better morning starts here", systemImage: "alarm", description: Text("Add your first alarm to get started."))
                    }
                    ForEach(store.alarms.sorted(by: { $0.date < $1.date })) { alarm in
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(alarm.date, style: .time).font(.system(size: 36, weight: .semibold, design: .rounded))
                                Text(alarm.label).font(.subheadline)
                                Text(alarm.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { store.delete(alarm) } label: { Image(systemName: "trash") }
                                .accessibilityLabel("Delete \(alarm.label) alarm")
                                .disabled(alarm.date <= .now || store.isBusy)
                        }.padding(22).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                    }
                    Button("Try the math challenge", systemImage: "plus.forwardslash.minus") { store.preview() }
                        .buttonStyle(.bordered).frame(maxWidth: .infinity)
                    Text("Snooze lasts 5 minutes and starts a fresh set of 2 questions. Alarms are one-time. iOS also provides a system Stop control that can bypass the in-app challenge.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }.background(Color(red: 0.055, green: 0.065, blue: 0.1))
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showingEditor) { AlarmEditorView(store: store) }
                .alert("Wayk Up", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("OK") { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
        }.tint(.orange)
    }
}

private struct AlarmEditorView: View {
    @Bindable var store: AlarmStore
    @Environment(\.dismiss) private var dismiss
    @State private var time = Date.now.addingTimeInterval(3600)
    @State private var label = "Rise and shine"
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Wake-up time", selection: $time, displayedComponents: .hourAndMinute)
                TextField("Alarm name", text: $label)
                Section {
                    Label("2 questions · addition and multiplication", systemImage: "brain.head.profile")
                    Label("5-minute snooze", systemImage: "zzz")
                    Text("Schedules the next occurrence of this time.").foregroundStyle(.secondary)
                }
            }.navigationTitle("New alarm")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                            guard let date = Calendar.current.nextDate(after: .now, matching: components, matchingPolicy: .nextTime) else { return }
                            Task { if await store.add(date: date, label: label.trimmingCharacters(in: .whitespacesAndNewlines)) { dismiss() } }
                        }.disabled(store.isBusy)
                    }
                }
                .alert("Couldn’t save alarm", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("OK") { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
        }
    }
}
