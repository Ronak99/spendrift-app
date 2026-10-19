//
//  ContentView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//
//  The tab bar - Transactions, Accounts, Categories, Analytics - plus the launch
//  plumbing that has to outlive any single tab: voice intents, shared receipts,
//  the SMS inbox drain and quick actions. Settings is a sheet, opened from the
//  gear in every tab's title bar.

import Combine
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppRouter.self) private var router
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    @AppStorage("spendriftOnboardingVersion") private var onboardingVersion = 0
    @State private var selectedTab = HomeTab.transactions.rawValue
    @State private var categoryTabType: CategoryType = .expense
    /// One month for Transactions and Analytics, so picking it on either tab carries over.
    @State private var month = MonthRef.of(Date())
    @State private var showSettings = false
    @State private var showCreateTransaction = false
    @State private var showStatementImport = false
    @State private var paywallContext: PaywallContext?
    @State private var receiptImport: ReceiptSharePayload?
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
            selectedTab = newValue
        }
    }

    /// The Liquid Glass tab bar ignores SwiftUI foreground styles on tab labels, so icons that
    /// must keep a specific colour are pre-tinted as `.alwaysOriginal` images.
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

    /// Selected ledger icons use the app wash; unselected stay template so they remain gray.
    private func ledgerTabIcon(_ tab: HomeTab) -> UIImage {
        let image = UIImage(systemName: tab.symbol) ?? UIImage()
        guard selectedTab == tab.rawValue else {
            return image.withRenderingMode(.alwaysTemplate)
        }
        return image.withTintColor(UIColor(AppTheme.atmosphere), renderingMode: .alwaysOriginal)
    }

    var body: some View {
        @Bindable var voice = voiceInline

        return TabView(selection: tabSelection) {
            Tab(value: HomeTab.transactions.rawValue) {
                TransactionsView(
                    month: $month,
                    voiceInline: voiceInline,
                    receiptImport: receiptImport,
                    messageInboxBanner: $messageInboxBanner
                )
            } label: {
                tabLabel(.transactions)
            }

            Tab(value: HomeTab.accounts.rawValue) {
                AccountsView()
                    .voiceCaptureBar(controller: voiceInline)
            } label: {
                tabLabel(.accounts)
            }

            Tab(value: HomeTab.categories.rawValue) {
                CategoriesView(selectedType: $categoryTabType)
                    .voiceCaptureBar(controller: voiceInline)
            } label: {
                tabLabel(.categories)
            }

            Tab(value: HomeTab.analytics.rawValue) {
                AnalyticsView(month: $month) { tab in
                    selectedTab = tab.rawValue
                }
                .voiceCaptureBar(controller: voiceInline)
            } label: {
                tabLabel(.analytics)
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
        .tint(AppTheme.atmosphere)
        .environment(\.openSettings) {
            showSettings = true
        }
        .onAppear {
            TransactionTypeMigration.normalizeNoneTypesIfNeeded(modelContext: modelContext)
            QuickActionsManager.setupQuickActions()
            seedDefaultCategoriesIfNeeded()
            ScreenshotDemoData.seedIfNeeded(modelContext: modelContext)
            handleVoiceIntentLaunchIfNeeded()
            handlePendingReceiptShareIfNeeded()
            drainMessageInboxIfNeeded()
            drainPendingRoute()
            Analytics.captureAppOpened()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // The tap that brought the app forward belongs to this activation
                // only; drop it so the next open isn't credited to a notification
                // the user tapped a while ago.
                NotificationOpenAttribution.clear()
                return
            }
            guard newPhase == .active else { return }
            handleVoiceIntentLaunchIfNeeded()
            handlePendingReceiptShareIfNeeded()
            drainMessageInboxIfNeeded()
            drainPendingRoute()
            PushNotifications.handleForeground()
            Analytics.captureAppOpened()
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
        .onOpenURL { url in
            handleQuickAction(url: url)
        }
        .onChange(of: router.pending) { _, _ in
            drainPendingRoute()
        }
        .proPaywall($paywallContext)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
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

    private func tabLabel(_ tab: HomeTab) -> some View {
        Label {
            Text("")
        } icon: {
            Image(uiImage: ledgerTabIcon(tab))
        }
        .accessibilityLabel(tab.title)
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
        HomeTab(rawValue: index)?.eventName ?? "unknown"
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
            selectedTab = HomeTab.transactions.rawValue
        case "voiceExpense":
            showCreateTransaction = false
            selectedTab = HomeTab.transactions.rawValue
            ProAccess.attempt(.voice, paywall: $paywallContext) {
                voiceInline.beginCapture()
            }
        case "importStatement":
            showCreateTransaction = false
            selectedTab = HomeTab.transactions.rawValue
            ProAccess.attempt(.statementImport, paywall: $paywallContext) {
                showStatementImport = true
            }
        default:
            break
        }
    }

    /// A pushed route always means Settings, which is presented as a sheet. The path is
    /// set first so the sheet opens straight on the destination.
    private func drainPendingRoute() {
        guard let route = router.consume() else { return }
        router.settingsPath = [route.settingsDestination]
        showSettings = true
    }

    /// Picks up a receipt image shared via the Share Extension (stored in the App Group)
    /// and routes it into the receipt pipeline. Safe to call repeatedly; it no-ops when
    /// there is nothing pending.
    private func handlePendingReceiptShareIfNeeded() {
        guard let url = ReceiptShareInbox.consumePendingImageURL() else { return }
        showCreateTransaction = false
        selectedTab = HomeTab.transactions.rawValue
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
                selectedTab = HomeTab.transactions.rawValue
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
            selectedTab = HomeTab.transactions.rawValue
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
        selectedTab = HomeTab.transactions.rawValue
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
