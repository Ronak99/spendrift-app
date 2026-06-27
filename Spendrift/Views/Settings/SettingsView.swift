//
//  SettingsView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import UIKit

private enum SettingsTokens {
    static let screenBackground = Color(hex: "#000000")
    static let groupCard = Color(hex: "#1C1C1E")
    static let toggleOff = Color(hex: "#39393D")
    static let chevron = Color(hex: "#48484A")
    static let textPrimary = Color(hex: "#FFFFFF")
    static let textSecondary = Color(hex: "#8E8E93")
    static let textTertiary = Color(hex: "#48484A")
    static let divider = Color.white.opacity(0.08)
    static let fillSubtle = Color(red: 118 / 255, green: 118 / 255, blue: 128 / 255).opacity(0.24)
    static let rowPressHighlight = Color.white.opacity(0.04)
}

private struct CaptureShortcutItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let url: URL?
}

private struct SettingsIconTile: View {
    let systemName: String
    let accent: Color
    let accentSoft: Color
    let size: CGFloat
    let cornerRadius: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(accentSoft)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(accent)
            }
    }
}

private struct SettingsRow: View {
    enum Accessory {
        case toggle(Binding<Bool>)
        case value(String)
        case chevron
    }

    let icon: String
    let title: String
    let accent: Color
    let accentSoft: Color
    let accessory: Accessory
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(SettingsPressStyle())
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 13) {
            SettingsIconTile(
                systemName: icon,
                accent: accent,
                accentSoft: accentSoft,
                size: 30,
                cornerRadius: 8,
                symbolSize: 18
            )

            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(SettingsTokens.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            accessoryView
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case let .toggle(value):
            SettingsToggle(isOn: value, accent: accent)
        case let .value(value):
            Text(value)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(SettingsTokens.textPrimary)
                .padding(.vertical, 5)
                .padding(.horizontal, 11)
                .background(SettingsTokens.fillSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SettingsTokens.chevron)
                .frame(width: 9, height: 15)
        }
    }
}

private struct SettingsToggle: View {
    @Binding var isOn: Bool
    let accent: Color

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15.5, style: .continuous)
                    .fill(isOn ? accent : SettingsTokens.toggleOff)
                    .frame(width: 51, height: 31)

                Circle()
                    .fill(Color.white)
                    .frame(width: 27, height: 27)
                    .offset(x: isOn ? 22 : 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Daily reminder")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

private struct SettingsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? SettingsTokens.rowPressHighlight : Color.clear)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SettingsTokens.textSecondary)
                .padding(.leading, 4)
            content
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(SettingsTokens.groupCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingsInsetDivider: View {
    var body: some View {
        Rectangle()
            .fill(SettingsTokens.divider)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.leading, 59)
    }
}

private struct CaptureOptionTile: View {
    let item: CaptureShortcutItem
    let accent: Color
    let accentSoft: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsIconTile(
                    systemName: item.icon,
                    accent: accent,
                    accentSoft: accentSoft,
                    size: 38,
                    cornerRadius: 10,
                    symbolSize: 22
                )

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SettingsTokens.textPrimary)

                    Text(item.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(SettingsTokens.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(SettingsTokens.groupCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(SettingsPressStyle())
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex
    @AppStorage(Color.legacyThemeColorKey) private var legacyThemeColorName = "Blue"
    @AppStorage(NotificationManager.Keys.dailyReminderEnabled) private var dailyReminderEnabled = true
    @AppStorage(NotificationManager.Keys.dailyReminderHour) private var dailyReminderHour = NotificationManager.defaultHour
    @AppStorage(NotificationManager.Keys.dailyReminderMinute) private var dailyReminderMinute = NotificationManager.defaultMinute
    @AppStorage(NotificationManager.Keys.dailyReminderTimeInterval) private var reminderTimeInterval = NotificationManager.defaultReminderTimeInterval

    @State private var showFeatureRequest = false
    @State private var showReminderTimePicker = false
    @State private var showInviteSheet = false

    private let helpFAQURL = URL(string: "https://spendrift.app/faq")

    private let captureShortcuts: [CaptureShortcutItem] = [
        CaptureShortcutItem(
            id: "speak",
            icon: "mic.fill",
            title: "Speak",
            subtitle: "Add by voice",
            url: OnboardingShortcutShareLinks.voiceRecordExpense
        ),
        CaptureShortcutItem(
            id: "type",
            icon: "keyboard",
            title: "Type",
            subtitle: "Add manually",
            url: OnboardingShortcutShareLinks.logExpenseAmount
        ),
    ]

    private var accent: Color {
        Color.accentColor(forThemeIndex: selectedThemeIndex)
    }

    private var accentSoft: Color {
        accent.opacity(0.16)
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
                    SettingsSection(title: "Theme") {
                        themeCard
                    }

                    SettingsSection(title: "Capture") {
                        captureCard
                    }

                    SettingsSection(title: "Reminders") {
                        SettingsCard {
                            SettingsRow(
                                icon: "bell.fill",
                                title: "Daily reminder",
                                accent: accent,
                                accentSoft: accentSoft,
                                accessory: .toggle(reminderEnabledBinding),
                                action: nil
                            )

                            SettingsInsetDivider()

                            SettingsRow(
                                icon: "clock.fill",
                                title: "Time",
                                accent: accent,
                                accentSoft: accentSoft,
                                accessory: .value(reminderDisplayValue),
                                action: { showReminderTimePicker = true }
                            )
                        }
                    }

                    SettingsSection(title: "Support") {
                        SettingsCard {
                            SettingsRow(
                                icon: "lightbulb.fill",
                                title: "Request a feature",
                                accent: accent,
                                accentSoft: accentSoft,
                                accessory: .chevron,
                                action: { showFeatureRequest = true }
                            )

                            SettingsInsetDivider()

                            SettingsRow(
                                icon: "questionmark.circle.fill",
                                title: "Help & FAQ",
                                accent: accent,
                                accentSoft: accentSoft,
                                accessory: .chevron,
                                action: openHelpFAQ
                            )
                        }
                    }

                    SettingsSection(title: "Community") {
                        SettingsCard {
                            SettingsRow(
                                icon: "person.badge.plus",
                                title: "Invite friends",
                                accent: accent,
                                accentSoft: accentSoft,
                                accessory: .chevron,
                                action: { showInviteSheet = true }
                            )

                            SettingsInsetDivider()

                            SettingsRow(
                                icon: "star.fill",
                                title: "Rate Spendrift",
                                accent: accent,
                                accentSoft: accentSoft,
                                accessory: .chevron,
                                action: {
                                    AppStoreReviewRequest.requestIfFirstTime(forKey: AppStoreReviewRequest.Keys.settingsRateTap)
                                }
                            )
                        }
                    }

                    Text("Spendrift · v2.1")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(SettingsTokens.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(SettingsTokens.screenBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(accent)
        .animation(.easeInOut(duration: 0.2), value: selectedThemeIndex)
        .task {
            migrateThemeIfNeeded()
            selectedThemeIndex = Color.normalizedThemeIndex(selectedThemeIndex)
            migrateReminderTimeIfNeeded()
            syncReminderClockComponents(with: reminderDate)
        }
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
    }

    private var themeCard: some View {
        SettingsCard {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 4),
                spacing: 18
            ) {
                ForEach(Array(Color.themePalette.enumerated()), id: \.offset) { index, color in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedThemeIndex = index
                        }
                    } label: {
                        themeSwatch(color: color, isSelected: index == selectedThemeIndex)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
        }
    }

    private var captureCard: some View {
        HStack(spacing: 12) {
            ForEach(captureShortcuts) { item in
                CaptureOptionTile(
                    item: item,
                    accent: accent,
                    accentSoft: accentSoft
                ) {
                    guard let url = item.url else { return }
                    UIApplication.shared.open(url)
                }
            }
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
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func themeSwatch(color: Color, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 56, height: 56)

            if isSelected {
                Circle()
                    .stroke(SettingsTokens.groupCard, lineWidth: 3)
                    .frame(width: 62, height: 62)

                Circle()
                    .stroke(accent, lineWidth: 2)
                    .frame(width: 66, height: 66)

                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 56, height: 56)
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
}
