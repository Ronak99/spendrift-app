//
//  ContentView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//
//  Hosts the one screen the app has - `HomeShellView` - plus the launch plumbing
//  that has to outlive any single pane: voice intents, shared receipts, the SMS
//  inbox drain and quick actions.

import Combine
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    @State private var paywallContext: PaywallContext?
    @State private var receiptImport: ReceiptSharePayload?
    @State private var messageInboxBanner: MessageInboxImportBanner?
    @State private var isMessageInboxSyncing = false
    /// Owned here rather than by the shell so a capture started by Siri or a widget
    /// survives any view that comes and goes.
    @State private var voiceInline = VoiceInlineCaptureController()

    var body: some View {
        @Bindable var voice = voiceInline

        return HomeShellView(
            voiceInline: voiceInline,
            receiptImport: receiptImport,
            messageInboxBanner: $messageInboxBanner
        )
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
        // Presented here rather than inside the shell so a voice capture started from
        // anywhere can hand off to manual review.
        .sheet(item: $voice.manualSheetPayload) { payload in
            UpdateTransactionSheet(
                transaction: nil,
                draft: payload.draft,
                voiceReviewHint: payload.hint
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
            NotificationCenter.default.post(name: .createTransactionRequested, object: nil)
        case "voiceExpense":
            ProAccess.attempt(.voice, paywall: $paywallContext) {
                voiceInline.beginCapture()
            }
        case "importStatement":
            ProAccess.attempt(.statementImport, paywall: $paywallContext) {
                NotificationCenter.default.post(name: .statementImportRequested, object: nil)
            }
        default:
            break
        }
    }

    /// A pushed route always means Settings, which the shell presents as a sheet.
    private func drainPendingRoute() {
        guard let route = router.consume() else { return }
        router.settingsPath = [route.settingsDestination]
        NotificationCenter.default.post(name: .settingsRequested, object: nil)
    }

    /// Picks up a receipt image shared via the Share Extension (stored in the App Group)
    /// and routes it into the receipt pipeline. Safe to call repeatedly; it no-ops when
    /// there is nothing pending.
    private func handlePendingReceiptShareIfNeeded() {
        guard let url = ReceiptShareInbox.consumePendingImageURL() else { return }
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
            }
        }
    }

    private func handleVoiceIntentLaunchIfNeeded() {
        let defaults = UserDefaults.standard

        if let path = defaults.string(forKey: VoiceExpenseIntent.pendingImportPathKey), !path.isEmpty {
            defaults.removeObject(forKey: VoiceExpenseIntent.pendingImportPathKey)
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return }
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
