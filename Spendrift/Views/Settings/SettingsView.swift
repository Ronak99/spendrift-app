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

private enum SettingsTokens {
    static let screenBackground = Color(uiColor: .systemGroupedBackground)
    static let groupCard = Color(uiColor: .secondarySystemGroupedBackground)
    static let chevron = Color(uiColor: .tertiaryLabel)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let divider = Color(uiColor: .separator).opacity(0.35)
    static let fillSubtle = Color(uiColor: .tertiarySystemFill)
    static let rowPressHighlight = Color(uiColor: .quaternarySystemFill)
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
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case let .toggle(value):
            Toggle(title, isOn: value)
                .labelsHidden()
                .tint(accent)
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
        .padding(.vertical, 2)
        .padding(.horizontal, 16)
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

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
    @State private var showMessageAutomationGuide = false
    @State private var showMessageInboxDebug = false
    @State private var showDebugSwift = false
    @State private var showStatementImport = false
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var showReceiptScanOptions = false
    @State private var receiptShare = ReceiptCaptureController()

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
        CaptureShortcutItem(
            id: "upload-document",
            icon: "doc.text",
            title: "Upload document",
            subtitle: "Import a statement",
            url: nil
        ),
        CaptureShortcutItem(
            id: "scan-receipt",
            icon: "doc.viewfinder",
            title: "Scan receipt",
            subtitle: "From photo or camera",
            url: nil
        ),
    ]

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var accent: Color {
        Color.accentColor(forThemeIndex: selectedThemeIndex)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "Spendrift · v\(version)"
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

                    SettingsSection(title: "Messages") {
                        messageInboxCard
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

                            if dailyReminderEnabled {
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

                    if showsDeveloperTools {
                        SettingsSection(title: "Developer") {
                            SettingsCard {
                                #if DEBUG
                                SettingsRow(
                                    icon: "internaldrive.fill",
                                    title: "SQLite debugger",
                                    accent: accent,
                                    accentSoft: accentSoft,
                                    accessory: .chevron,
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
                                    accessory: .chevron,
                                    action: { showMessageInboxDebug = true }
                                )

                                if developerModeUnlocked {
                                    SettingsInsetDivider()

                                    SettingsRow(
                                        icon: "lock.fill",
                                        title: "Turn off developer mode",
                                        accent: accent,
                                        accentSoft: accentSoft,
                                        accessory: .chevron,
                                        action: { developerModeUnlocked = false }
                                    )
                                }
                            }
                        }
                    }

                    Text(appVersionLabel)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetDismissToolbarButton()
                        .foregroundStyle(accent)
                }
            }
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
        .onChange(of: selectedThemeIndex) { _, newIndex in
            legacyThemeColorName = Color.legacyThemeName(forThemeIndex: Color.normalizedThemeIndex(newIndex))
        }
        .sheet(isPresented: $showStatementImport) {
            StatementImportView()
        }
        .fullScreenCover(isPresented: $showReceiptCamera) {
            ReceiptCameraPicker { image in
                showReceiptCamera = false
                if let image {
                    processReceiptImage(image)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showReceiptLibrary) {
            PhotoLibraryPicker { image in
                showReceiptLibrary = false
                if let image {
                    processReceiptImage(image)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $receiptShare.reviewPayload) { payload in
            UpdateTransactionSheet(
                transaction: nil,
                draft: payload.draft,
                voiceReviewHint: payload.hint
            )
        }
        .confirmationDialog("Scan receipt", isPresented: $showReceiptScanOptions, titleVisibility: .visible) {
            Button("Take Photo") {
                showReceiptCamera = true
            }
            .disabled(!cameraAvailable || receiptShare.isProcessing)

            Button("Choose from Library") {
                showReceiptLibrary = true
            }
            .disabled(receiptShare.isProcessing)

            Button("Cancel", role: .cancel) {}
        }
        .alert("Couldn't Scan Receipt", isPresented: Binding(
            get: { if case .error = receiptShare.state { return true } else { return false } },
            set: { if !$0 { receiptShare.dismissError() } }
        )) {
            Button("OK", role: .cancel) { receiptShare.dismissError() }
        } message: {
            if case .error(let message) = receiptShare.state {
                Text(message)
            }
        }
        .sheet(isPresented: $showFeatureRequest) {
            FeatureRequestView()
        }
        .sheet(isPresented: $showReminderTimePicker) {
            reminderTimePickerSheet
                .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showMessageAutomationGuide) {
            messageAutomationGuideSheet
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

    private var showsDeveloperTools: Bool {
        developerModeUnlocked || DeveloperMode.isEnabled
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
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(captureShortcuts) { item in
                CaptureOptionTile(
                    item: item,
                    accent: accent,
                    accentSoft: accentSoft
                ) {
                    handleCaptureOptionTap(item)
                }
            }
        }
    }

    private func handleCaptureOptionTap(_ item: CaptureShortcutItem) {
        switch item.id {
        case "upload-document":
            showStatementImport = true
        case "scan-receipt":
            showReceiptScanOptions = true
        default:
            guard let url = item.url else { return }
            UIApplication.shared.open(url)
        }
    }

    private func processReceiptImage(_ image: UIImage) {
        receiptShare.process(
            image: image,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )
    }

    private var lastMessageCapturedLabel: String {
        guard let date = MessageInboxSettings.lastCapturedAt else {
            return "Never"
        }
        return Self.messageCapturedFormatter.string(from: date)
    }

    private var messageInboxCard: some View {
        SettingsCard {
            SettingsRow(
                icon: "clock.arrow.circlepath",
                title: "Last message captured",
                accent: accent,
                accentSoft: accentSoft,
                accessory: .value(lastMessageCapturedLabel),
                action: nil
            )

            SettingsInsetDivider()

            SettingsRow(
                icon: "list.bullet.rectangle",
                title: "Set up automations",
                accent: accent,
                accentSoft: accentSoft,
                accessory: .chevron,
                action: { showMessageAutomationGuide = true }
            )
        }
    }

    private var messageAutomationGuideSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Spendrift can capture bank SMS while the app is closed, then turn them into transactions when you open the app. Setting up the automation is consent to capture and parse those messages.")
                        .font(.body)
                        .foregroundStyle(SettingsTokens.textSecondary)

                    guideStep(number: 1, text: "Open the Shortcuts app and create a personal automation.")
                    guideStep(number: 2, text: "Choose Message as the trigger. Set Message Contains to \"credited\".")
                    guideStep(number: 3, text: "Turn on Run Immediately and turn off Notify When Run.")
                    guideStep(number: 4, text: "Add the Spendrift action \"Log Transaction Message\" (search Spendrift if needed). Set Message to Shortcut Input.")
                    guideStep(number: 5, text: "Duplicate the automation with Message Contains set to \"debited\".")
                    guideStep(number: 6, text: "Messages are redacted on device before upload. Open Spendrift to import captured messages as transactions.")

                    Text("Personal automations cannot be shared as a link. You need to create both triggers once on this iPhone.")
                        .font(.footnote)
                        .foregroundStyle(SettingsTokens.textTertiary)
                }
                .padding(20)
            }
            .background(SettingsTokens.screenBackground.ignoresSafeArea())
            .navigationTitle("Message automations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showMessageAutomationGuide = false
                    }
                    .foregroundStyle(accent)
                }
            }
        }
    }

    private func guideStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .background(accentSoft, in: Circle())
            Text(text)
                .font(.body)
                .foregroundStyle(SettingsTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
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

    private static let messageCapturedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
