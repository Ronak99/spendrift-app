//
//  ContentView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//  To Trigger Workflow

import Combine
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    @AppStorage(NotificationManager.Keys.dailyReminderEnabled) private var dailyReminderEnabled = true
    @AppStorage(NotificationManager.Keys.dailyReminderHour) private var dailyReminderHour = NotificationManager.defaultHour
    @AppStorage(NotificationManager.Keys.dailyReminderMinute) private var dailyReminderMinute = NotificationManager.defaultMinute
    @AppStorage("spendriftOnboardingVersion") private var onboardingVersion = 0
    @State private var showReminderOptIn = false
    @State private var selectedTab = 0
    @State private var showCreateTransaction = false
    @State private var showStatementImport = false
    @State private var paywallContext: PaywallContext?
    @State private var receiptImport: ReceiptSharePayload?
    @State private var transactionPeriodViewModel = TransactionViewModel()
    @State private var messageInboxBanner: MessageInboxImportBanner?
    @State private var isMessageInboxSyncing = false
    /// Owned here rather than by `TransactionsView` so voice capture can be started from - and
    /// stay visible on top of - any tab.
    @State private var voiceInline = VoiceInlineCaptureController()
    /// Sentinel selection value for the voice CTA. It is never committed to `selectedTab`.
    private static let voiceTabTag = 99

    /// Turns the voice tab into an action: the setter starts capture and drops the tag on the
    /// floor, so the current tab stays selected and its content is never swapped out.
    private var tabSelection: Binding<Int> {
        Binding {
            selectedTab
        } set: { newValue in
            guard newValue != Self.voiceTabTag else {
                startVoiceCaptureFromTabBar()
                return
            }
            // Re-tapping the already-selected Home tab collapses its analytics view back to
            // the transactions list; TransactionsView listens for this and no-ops otherwise.
            if newValue == 0, selectedTab == 0 {
                NotificationCenter.default.post(name: .homeTabReselected, object: nil)
            }
            selectedTab = newValue
        }
    }

    /// The Liquid Glass tab bar ignores SwiftUI foreground styles on tab labels, so the mic is
    /// pre-tinted as an `.alwaysOriginal` image to keep its muted red CTA colour.
    private func voiceTabIcon(disabled: Bool) -> UIImage {
        let activeTint: UIColor = colorScheme == .dark
            ? UIColor(red: 0.96, green: 0.47, blue: 0.45, alpha: 1)
            : UIColor(red: 0.76, green: 0.24, blue: 0.23, alpha: 1)
        let tint = disabled
            ? UIColor.tertiaryLabel
            : activeTint
        return UIImage(systemName: "mic.fill")?
            .withTintColor(tint, renderingMode: .alwaysOriginal) ?? UIImage()
    }

    var body: some View {
        @Bindable var voice = voiceInline

        return TabView(selection: tabSelection) {
            Tab(value: 0) {
                TransactionsView(
                    periodViewModel: transactionPeriodViewModel,
                    voiceInline: voiceInline,
                    receiptImport: receiptImport,
                    messageInboxBanner: $messageInboxBanner
                )
            } label: {
                Label("", systemImage: "house.fill")
            }

            Tab(value: 1) {
                AccountsView()
                    .voiceCaptureBar(controller: voiceInline)
            } label: {
                Label("", systemImage: "creditcard")
            }

            Tab(value: 2) {
                CategoriesView()
                    .voiceCaptureBar(controller: voiceInline)
            } label: {
                Label("", systemImage: "folder")
            }

            Tab(value: 3) {
                SettingsView()
                    .voiceCaptureBar(controller: voiceInline)
            } label: {
                Label("", systemImage: "gearshape.fill")
            }

            // `role: .search` is the only public API that lifts a tab item out of the tab bar
            // into its own circular Liquid Glass button, which is the shape this CTA needs.
            // Selection is intercepted in `tabSelection`, so the placeholder content below is
            // never actually presented.
            Tab(value: Self.voiceTabTag, role: .search) {
                Color.clear
            } label: {
                Label {
                    Text("Speak")
                } icon: {
                    Image(uiImage: voiceTabIcon(disabled: voice.blocksNewCapture))
                }
                .accessibilityLabel("Speak a transaction")
                .accessibilityHint(
                    voice.blocksNewCapture
                        ? "Unavailable while a voice note is being recorded or processed"
                        : "Records a voice note and turns it into a transaction"
                )
            }
            // Must sit on the `Tab`, not on the `Label` inside it: disabling the label only
            // dims the icon and leaves the tab item tappable, and a tap that lands while a
            // capture is in flight commits `TabView` to this tab. `selectedTab` never takes
            // the sentinel, so the binding reports no change, SwiftUI reasserts nothing, and
            // the empty placeholder above stays on screen as a blank black screen until the
            // user picks another tab by hand.
            .disabled(voice.blocksNewCapture)
        }
        .tint(AppTheme.accent)
        .environment(\.openSettings) {
            selectedTab = 3
        }
        .onAppear {
            TransactionTypeMigration.normalizeNoneTypesIfNeeded(modelContext: modelContext)
            QuickActionsManager.setupQuickActions()
            seedDefaultCategoriesIfNeeded()
            ScreenshotDemoData.seedIfNeeded(modelContext: modelContext)
            handleVoiceIntentLaunchIfNeeded()
            handlePendingReceiptShareIfNeeded()
            drainMessageInboxIfNeeded()
            Analytics.capture(.appOpened, [Analytics.Key.daysSinceInstall: Analytics.daysSinceInstall])
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            handleVoiceIntentLaunchIfNeeded()
            handlePendingReceiptShareIfNeeded()
            drainMessageInboxIfNeeded()
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
        // The Pro paywall queues behind this alert; without the broadcast a sheet
        // presented at the same moment would swallow it.
        .onChange(of: showReminderOptIn) { _, isVisible in
            NotificationCenter.default.post(
                name: isVisible ? .reminderOptInShown : .reminderOptInDismissed,
                object: nil
            )
        }
        .alert("Stay on top of your spending?", isPresented: $showReminderOptIn) {
            Button("Enable reminders") { enableDailyReminders() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Get a daily nudge to log your spending and keep your budget accurate.")
        }
        .proPaywall($paywallContext)
        .sheet(isPresented: $showCreateTransaction) {
            UpdateTransactionSheet(transaction: nil)
        }
        .sheet(isPresented: $showStatementImport) {
            StatementImportView()
        }
        // Presented here rather than per-tab so a voice capture started from any tab can hand
        // off to manual review.
        .sheet(item: $voice.manualSheetPayload) { payload in
            UpdateTransactionSheet(
                transaction: nil,
                draft: payload.draft,
                voiceReviewHint: payload.hint
            )
        }
    }

    /// Entry point for the tab bar voice CTA. No-ops while a capture is already in flight so a
    /// stray tap cannot interrupt an in-progress recording.
    private func startVoiceCaptureFromTabBar() {
        guard !voiceInline.blocksNewCapture else { return }
        ProAccess.attempt(.voice, paywall: $paywallContext) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Analytics.capture(.shortcutUsed, [
                Analytics.Key.kind: "voice",
                Analytics.Key.source: "tab_bar_cta"
            ])
            voiceInline.beginCapture()
        }
    }

    
    private static func tabName(for index: Int) -> String {
        switch index {
        case 0: "transactions"
        case 1: "accounts"
        case 2: "categories"
        case 3: "settings"
        default: "unknown"
        }
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
        case "voiceExpense":
            showCreateTransaction = false
            selectedTab = 0
            ProAccess.attempt(.voice, paywall: $paywallContext) {
                voiceInline.beginCapture()
            }
        case "importStatement":
            showCreateTransaction = false
            selectedTab = 0
            ProAccess.attempt(.statementImport, paywall: $paywallContext) {
                showStatementImport = true
            }
        default:
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
        receiptImport = ReceiptSharePayload(id: UUID(), fileURL: url)
        Analytics.capture(.shortcutUsed, [Analytics.Key.kind: "receipt_share"])
    }

    /// Drains SMS inbox rows into the ledger when the user has opted in.
    private func drainMessageInboxIfNeeded() {
        if DeveloperMode.isEnabled, MessageInboxDebugLog.isDrainPaused { return }
        guard !isMessageInboxSyncing else { return }
        isMessageInboxSyncing = true
        Task { @MainActor in
            defer { isMessageInboxSyncing = false }
            if let banner = await MessageInboxSyncService.syncIfNeeded(
                ledgerContext: modelContext,
                accounts: accounts,
                categories: categories
            ) {
                messageInboxBanner = banner
                selectedTab = 0
            }
        }
    }

    private func handleVoiceIntentLaunchIfNeeded() {
        let defaults = UserDefaults.standard

        if let path = defaults.string(forKey: VoiceExpenseIntent.pendingImportPathKey), !path.isEmpty {
            defaults.removeObject(forKey: VoiceExpenseIntent.pendingImportPathKey)
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return }
            showCreateTransaction = false
            selectedTab = 0
            voiceInline.processImportedAudio(
                fileURL: url,
                modelContext: modelContext,
                accounts: accounts,
                categories: categories
            )
            Analytics.capture(.shortcutUsed, [Analytics.Key.kind: "voice_import"])
            return
        }

        guard defaults.object(forKey: VoiceExpenseIntent.launchTriggerKey) != nil else {
            return
        }

        defaults.removeObject(forKey: VoiceExpenseIntent.launchTriggerKey)
        showCreateTransaction = false
        selectedTab = 0
        // A Siri/Shortcuts launch lands here with no capture started yet, so the gate
        // still gets a chance to show the paywall rather than a mid-flow error.
        ProAccess.attempt(.voice, paywall: $paywallContext) {
            voiceInline.beginCapture()
            Analytics.capture(.shortcutUsed, [Analytics.Key.kind: "voice"])
        }
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
