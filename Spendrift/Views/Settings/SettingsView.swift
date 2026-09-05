//
//  SettingsView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData
import UIKit
#if DEBUG
import DebugSwift
#endif

struct SettingsView: View {
    @Environment(\.openURL) private var openURL

    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex
    @AppStorage(Color.legacyThemeColorKey) private var legacyThemeColorName = "Blue"
    @AppStorage(NotificationManager.Keys.dailyReminderEnabled) private var dailyReminderEnabled = true
    @AppStorage(NotificationManager.Keys.dailyReminderHour) private var dailyReminderHour = NotificationManager.defaultHour
    @AppStorage(NotificationManager.Keys.dailyReminderMinute) private var dailyReminderMinute = NotificationManager.defaultMinute
    @AppStorage(NotificationManager.Keys.dailyReminderTimeInterval) private var reminderTimeInterval = NotificationManager.defaultReminderTimeInterval
    @AppStorage(DeveloperMode.defaultsKey, store: DeveloperMode.store) private var developerModeUnlocked = false

    @State private var showFeatureRequest = false
    @State private var showReminderTimePicker = false
    @State private var showInviteSheet = false
    @State private var showMessageInboxDebug = false
    @State private var showDebugSwift = false
    @State private var lastMessageCapturedAt: Date?
    @State private var versionTapCount = 0

    /// Taps on the version footer needed to reveal the developer tools.
    private static let developerRevealTapCount = 5

    private let helpFAQURL = URL(string: "https://spendrift.app/faq")

    private var accent: Color {
        Color.accentColor(forThemeIndex: selectedThemeIndex)
    }

    private var accentSoft: Color {
        accent.opacity(0.16)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "Spendrift · v\(version)"
    }

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
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    generalCard
                    remindersSection
                    spendriftSection

                    if showsDeveloperTools {
                        developerSection
                    }

                    versionFooter
                }
                .padding(.horizontal, SettingsTokens.screenInset)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(SettingsTokens.screenBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(accent)
        .animation(.easeInOut(duration: 0.2), value: selectedThemeIndex)
        .animation(.easeInOut(duration: 0.2), value: dailyReminderEnabled)
        .animation(.easeInOut(duration: 0.2), value: developerModeUnlocked)
        .task {
            migrateThemeIfNeeded()
            selectedThemeIndex = Color.normalizedThemeIndex(selectedThemeIndex)
            migrateReminderTimeIfNeeded()
            syncReminderClockComponents(with: reminderDate)
        }
        .onAppear { lastMessageCapturedAt = MessageInboxSettings.lastCapturedAt }
        .onChange(of: selectedThemeIndex) { _, newIndex in
            legacyThemeColorName = Color.legacyThemeName(forThemeIndex: Color.normalizedThemeIndex(newIndex))
        }
        .sheet(isPresented: $showFeatureRequest) {
            FeatureRequestView()
        }
        .sheet(isPresented: $showReminderTimePicker) {
            reminderTimePickerSheet
                .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showInviteSheet) {
            ShareSheet(items: [AppShareContent.fullShareText])
        }
        .sheet(isPresented: $showMessageInboxDebug) {
            MessageInboxDebugView()
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showDebugSwift, onDismiss: {
            DebugSwift.debugViewControllerDidDismiss()
        }) {
            DebugSwiftViewControllerRepresentable(onDismiss: { showDebugSwift = false })
                .ignoresSafeArea()
        }
        #endif
    }

    // MARK: - Groups

    private var generalCard: some View {
        SettingsCard {
            ThemeStripRow(
                selectedIndex: $selectedThemeIndex,
                accent: accent,
                accentSoft: accentSoft
            )

            SettingsInsetDivider()

            NavigationLink {
                CaptureSettingsView()
            } label: {
                SettingsRow(
                    icon: "plus.circle.fill",
                    title: "Capture & shortcuts",
                    subtitle: "Speak, type, scan, import, SMS",
                    accent: accent,
                    accentSoft: accentSoft
                )
                .content
            }
            .buttonStyle(SettingsPressStyle())

            SettingsInsetDivider()

            NavigationLink {
                BankSMSSettingsView()
            } label: {
                SettingsRow(
                    icon: "message.fill",
                    title: "Bank SMS",
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .valueChevron(
                        BankSMSSettingsView.statusLabel(lastCapturedAt: lastMessageCapturedAt)
                    )
                )
                .content
            }
            .buttonStyle(SettingsPressStyle())
        }
    }

    private var remindersSection: some View {
        SettingsSection(title: "Reminders") {
            SettingsCard {
                SettingsRow(
                    icon: "bell.fill",
                    title: "Daily reminder",
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .toggle(reminderEnabledBinding)
                )

                if dailyReminderEnabled {
                    SettingsInsetDivider()

                    SettingsRow(
                        icon: nil,
                        title: "Time",
                        accent: accent,
                        accentSoft: accentSoft,
                        accessory: .valueChevron(reminderDisplayValue),
                        action: { showReminderTimePicker = true }
                    )
                }
            }
        }
    }

    private var spendriftSection: some View {
        SettingsSection(title: "Spendrift") {
            SettingsCard {
                SettingsRow(
                    icon: "lightbulb.fill",
                    title: "Request a feature",
                    accent: accent,
                    accentSoft: accentSoft,
                    action: { showFeatureRequest = true }
                )

                SettingsInsetDivider()

                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & FAQ",
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .externalLink,
                    action: openHelpFAQ
                )

                SettingsInsetDivider()

                SettingsRow(
                    icon: "square.and.arrow.up.fill",
                    title: "Invite friends",
                    accent: accent,
                    accentSoft: accentSoft,
                    action: { showInviteSheet = true }
                )

                SettingsInsetDivider()

                SettingsRow(
                    icon: "star.fill",
                    title: "Rate Spendrift",
                    accent: accent,
                    accentSoft: accentSoft,
                    action: {
                        AppStoreReviewRequest.requestIfFirstTime(forKey: AppStoreReviewRequest.Keys.settingsRateTap)
                    }
                )
            }
        }
    }

    private var developerSection: some View {
        SettingsSection(title: "Developer") {
            SettingsCard {
                #if DEBUG
                SettingsRow(
                    icon: "internaldrive.fill",
                    title: "SQLite debugger",
                    accent: accent,
                    accentSoft: accentSoft,
                    action: {
                        DebugSwift.debugViewControllerWillPresent()
                        showDebugSwift = true
                    }
                )

                SettingsInsetDivider()
                #endif

                SettingsRow(
                    icon: "ladybug.fill",
                    title: "Message inbox debug",
                    accent: accent,
                    accentSoft: accentSoft,
                    action: { showMessageInboxDebug = true }
                )

                if developerModeUnlocked {
                    SettingsInsetDivider()

                    SettingsRow(
                        icon: "lock.fill",
                        title: "Turn off developer mode",
                        accent: accent,
                        accentSoft: accentSoft,
                        action: { developerModeUnlocked = false }
                    )
                }
            }
        }
    }

    private var versionFooter: some View {
        Text(appVersionLabel)
            .font(.system(size: 12))
            .foregroundStyle(SettingsTokens.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 24)
            .contentShape(Rectangle())
            .onTapGesture { registerVersionTap() }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap five times to reveal developer tools")
    }

    private var showsDeveloperTools: Bool {
        developerModeUnlocked || DeveloperMode.isEnabled
    }

    /// Hidden unlock from the design: five taps on the version label. The
    /// passphrase in Request a feature still works too.
    private func registerVersionTap() {
        guard !developerModeUnlocked else { return }
        versionTapCount += 1
        guard versionTapCount >= Self.developerRevealTapCount else { return }
        versionTapCount = 0
        developerModeUnlocked = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Sheets

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
            .background(SettingsTokens.screenBackground.ignoresSafeArea())
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

    // MARK: - Reminders

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

    // MARK: - Theme

    private func migrateThemeIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Color.selectedThemeIndexKey) == nil else { return }
        if let legacyIndex = Color.themeIndex(forLegacyThemeName: legacyThemeColorName) {
            selectedThemeIndex = legacyIndex
        } else {
            selectedThemeIndex = Color.defaultThemeIndex
        }
        legacyThemeColorName = Color.legacyThemeName(forThemeIndex: selectedThemeIndex)
    }

    private func openHelpFAQ() {
        guard let helpFAQURL else { return }
        openURL(helpFAQURL)
    }

    private static let reminderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
