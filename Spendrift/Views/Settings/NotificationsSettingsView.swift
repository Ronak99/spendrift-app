//
//  NotificationsSettingsView.swift
//  Spendrift
//

import SwiftUI

struct NotificationsSettingsView: View {
    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex
    @AppStorage(NotificationManager.Keys.dailyReminderEnabled) private var dailyReminderEnabled = true
    @AppStorage(NotificationManager.Keys.dailyReminderHour) private var dailyReminderHour = NotificationManager.defaultHour
    @AppStorage(NotificationManager.Keys.dailyReminderMinute) private var dailyReminderMinute = NotificationManager.defaultMinute
    @AppStorage(NotificationManager.Keys.dailyReminderTimeInterval) private var reminderTimeInterval = NotificationManager.defaultReminderTimeInterval

    @State private var showReminderTimePicker = false

    private var accent: Color { Color.accentColor(forThemeIndex: selectedThemeIndex) }
    private var accentSoft: Color { accent.opacity(0.16) }

    private var reminderDate: Date {
        Date(timeIntervalSince1970: reminderTimeInterval)
    }

    private var reminderDisplayValue: String {
        Self.reminderFormatter.string(from: reminderDate)
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { dailyReminderEnabled },
            set: { isOn in
                handleReminderToggle(isOn)
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { reminderDate },
            set: { newDate in
                reminderTimeInterval = newDate.timeIntervalSince1970
                syncReminderClockComponents(with: newDate)
                rescheduleIfEnabled()
            }
        )
    }

    var body: some View {
        SettingsScreen(title: "Notifications") {
            Section {
                SettingsListItem(
                    icon: "bell.fill",
                    title: "Daily reminder",
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .toggle(reminderEnabledBinding)
                )
                .listItemPositioned(dailyReminderEnabled ? .first : .only)

                if dailyReminderEnabled {
                    Button {
                        showReminderTimePicker = true
                    } label: {
                        SettingsListItem(
                            icon: nil,
                            title: "Time",
                            accent: accent,
                            accentSoft: accentSoft,
                            accessory: .valueChevron(reminderDisplayValue)
                        )
                        .listItemPositioned(.last)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .tint(accent)
        .animation(.easeInOut(duration: 0.2), value: dailyReminderEnabled)
        .task {
            migrateReminderTimeIfNeeded()
            syncReminderClockComponents(with: reminderDate)
        }
        .sheet(isPresented: $showReminderTimePicker) {
            reminderTimePickerSheet
                .presentationDetents([.height(320)])
        }
    }

    private var reminderTimePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Reminder time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, 20)
                .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .background(AppTheme.listBackground.ignoresSafeArea())
            .navigationTitle("Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showReminderTimePicker = false
                    }
                    .foregroundStyle(accent)
                }
            }
        }
    }

    private func handleReminderToggle(_ isOn: Bool) {
        guard isOn else {
            dailyReminderEnabled = false
            NotificationManager.reschedule(
                enabled: false,
                hour: dailyReminderHour,
                minute: dailyReminderMinute
            )
            return
        }

        dailyReminderEnabled = true
        Task {
            let granted = await NotificationManager.requestAuthorization()
            await MainActor.run {
                if granted {
                    dailyReminderEnabled = true
                    rescheduleIfEnabled()
                } else {
                    dailyReminderEnabled = false
                }
            }
        }
    }

    private func rescheduleIfEnabled() {
        guard dailyReminderEnabled else { return }
        NotificationManager.reschedule(
            enabled: true,
            hour: dailyReminderHour,
            minute: dailyReminderMinute
        )
    }

    private func syncReminderClockComponents(with date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        dailyReminderHour = components.hour ?? NotificationManager.defaultHour
        dailyReminderMinute = components.minute ?? NotificationManager.defaultMinute
    }

    private func migrateReminderTimeIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: NotificationManager.Keys.dailyReminderTimeInterval) == nil else { return }
        let migratedDate = Calendar.current.date(
            from: DateComponents(hour: dailyReminderHour, minute: dailyReminderMinute)
        ) ?? NotificationManager.defaultReminderDate
        reminderTimeInterval = migratedDate.timeIntervalSince1970
    }

    private static let reminderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
