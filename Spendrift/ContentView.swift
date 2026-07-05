//
//  ContentView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//  To Trigger Workflow

import Combine
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex
    @AppStorage(Color.legacyThemeColorKey) private var legacyThemeColorName = "Blue"
    @AppStorage(NotificationManager.Keys.dailyReminderEnabled) private var dailyReminderEnabled = true
    @AppStorage(NotificationManager.Keys.dailyReminderHour) private var dailyReminderHour = NotificationManager.defaultHour
    @AppStorage(NotificationManager.Keys.dailyReminderMinute) private var dailyReminderMinute = NotificationManager.defaultMinute
    @AppStorage("spendriftOnboardingVersion") private var onboardingVersion = 0
    @State private var showReminderOptIn = false
    @State private var selectedTab = 0
    @State private var showCreateTransaction = false
    @State private var showStatementImport = false
    @State private var voiceCaptureTrigger: UUID?
    @State private var shortcutImportedAudio: ShortcutImportedAudioPayload?
    @State private var receiptImport: ReceiptSharePayload?
    @State private var useCompactVoiceCapture = false
    @State private var showSettingsSheet = false
    @State private var transactionPeriodViewModel = TransactionViewModel()

    private var accentColor: Color {
        Color.accentColor(forThemeIndex: selectedThemeIndex)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TransactionsView(
                periodViewModel: transactionPeriodViewModel,
                voiceCaptureTrigger: voiceCaptureTrigger,
                useCompactVoiceCapture: useCompactVoiceCapture,
                shortcutImportedAudio: shortcutImportedAudio,
                receiptImport: receiptImport
            )
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Transactions")
                }
                .tag(0)
            AccountsView()
                .tabItem {
                    Image(systemName: "creditcard")
                    Text("Accounts")
                }
                .tag(1)

            CategoriesView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("Categories")
                }
                .tag(2)

            StatisticsView(periodViewModel: transactionPeriodViewModel)
                .tabItem {
                    Image(systemName: "chart.pie")
                    Text("Analytics")
                }
                .tag(3)
        }
        .tint(accentColor)
        .environment(\.openSettings) {
            showSettingsSheet = true
        }
        .onAppear {
            migrateThemeIfNeeded()
            QuickActionsManager.setupQuickActions()
            seedDefaultCategoriesIfNeeded()
            ScreenshotDemoData.seedIfNeeded(modelContext: modelContext)
            handleVoiceIntentLaunchIfNeeded()
            handlePendingReceiptShareIfNeeded()
            Analytics.capture(.appOpened, [Analytics.Key.daysSinceInstall: Analytics.daysSinceInstall])
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            handleVoiceIntentLaunchIfNeeded()
            handlePendingReceiptShareIfNeeded()
            Analytics.capture(.appOpened, [Analytics.Key.daysSinceInstall: Analytics.daysSinceInstall])
        }
        .onChange(of: selectedTab) { _, newTab in
            Analytics.capture(.screenViewed, [Analytics.Key.tab: Self.tabName(for: newTab)])
            Diagnostics.breadcrumb(
                category: .navigation,
                message: "tab_changed",
                data: [Diagnostics.Tag.tab: Self.tabName(for: newTab)]
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceExpenseIntentTriggered)) { _ in
            handleVoiceIntentLaunchIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptShareImportTriggered)) { _ in
            handlePendingReceiptShareIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .firstTransactionCreated)) { _ in
            guard !dailyReminderEnabled else { return }
            showReminderOptIn = true
        }
        .onOpenURL { url in
            handleQuickAction(url: url)
        }
        .alert("Stay on top of your spending?", isPresented: $showReminderOptIn) {
            Button("Enable reminders") { enableDailyReminders() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Get a daily nudge to log your spending and keep your budget accurate.")
        }
        .sheet(isPresented: $showCreateTransaction) {
            UpdateTransactionSheet(transaction: nil)
        }
        .sheet(isPresented: $showStatementImport) {
            StatementImportView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
    }
    
    private static func tabName(for index: Int) -> String {
        switch index {
        case 0: "transactions"
        case 1: "accounts"
        case 2: "categories"
        case 3: "analytics"
        default: "unknown"
        }
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

    private func enableDailyReminders() {
        Task {
            let granted = await NotificationManager.requestAuthorization()
            guard granted else { return }
            dailyReminderEnabled = true
            NotificationManager.reschedule(
                enabled: true,
                hour: dailyReminderHour,
                minute: dailyReminderMinute
            )
        }
    }

    private func handleQuickAction(url: URL) {
        guard url.scheme == "spendrift" else { return }

        if url.host == "importReceipt" {
            handlePendingReceiptShareIfNeeded()
            return
        }

        Analytics.capture(.widgetTapped, [Analytics.Key.kind: url.host ?? "open"])

        switch url.host {
        case "createTransaction":
            showCreateTransaction = true
            selectedTab = 0
            useCompactVoiceCapture = false
        case "voiceExpense":
            showCreateTransaction = false
            selectedTab = 0
            useCompactVoiceCapture = true
            voiceCaptureTrigger = UUID()
        case "importStatement":
            showCreateTransaction = false
            useCompactVoiceCapture = false
            selectedTab = 0
            showStatementImport = true
        default:
            useCompactVoiceCapture = false
            break
        }
    }

    /// Picks up a receipt image shared via the Share Extension (stored in the App Group)
    /// and routes it into the receipt pipeline. Safe to call repeatedly; it no-ops when
    /// there is nothing pending.
    private func handlePendingReceiptShareIfNeeded() {
        guard let url = ReceiptShareInbox.consumePendingImageURL() else { return }
        showCreateTransaction = false
        selectedTab = 0
        useCompactVoiceCapture = false
        receiptImport = ReceiptSharePayload(id: UUID(), fileURL: url)
        Analytics.capture(.shortcutUsed, [Analytics.Key.kind: "receipt_share"])
    }

    private func handleVoiceIntentLaunchIfNeeded() {
        let defaults = UserDefaults.standard

        if let path = defaults.string(forKey: VoiceExpenseIntent.pendingImportPathKey), !path.isEmpty {
            defaults.removeObject(forKey: VoiceExpenseIntent.pendingImportPathKey)
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return }
            showCreateTransaction = false
            selectedTab = 0
            useCompactVoiceCapture = true
            shortcutImportedAudio = ShortcutImportedAudioPayload(id: UUID(), fileURL: url)
            Analytics.capture(.shortcutUsed, [Analytics.Key.kind: "voice_import"])
            return
        }

        guard defaults.object(forKey: VoiceExpenseIntent.launchTriggerKey) != nil else {
            return
        }

        defaults.removeObject(forKey: VoiceExpenseIntent.launchTriggerKey)
        showCreateTransaction = false
        selectedTab = 0
        useCompactVoiceCapture = true
        voiceCaptureTrigger = UUID()
        Analytics.capture(.shortcutUsed, [Analytics.Key.kind: "voice"])
    }

    private var shouldSeedCategoriesOnLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    /// Production seeding is unified in `DefaultDataSeeder` and triggered when onboarding
    /// starts. UI tests skip onboarding, so they get a synchronous category seed here.
    private func seedDefaultCategoriesIfNeeded() {
        guard shouldSeedCategoriesOnLaunch else { return }
        DefaultCategorySeeder.seedIfNeeded(modelContext: modelContext)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
