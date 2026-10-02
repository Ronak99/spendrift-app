//
//  SpendriftApp.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData
import AppIntents

// Add a run argument : -com.apple.CoreData.SQLDebug 1 to visualize the SQLite data

@main
struct SpendriftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let sharedContainer: ModelContainer

    init() {
        _ = DeviceIdentity.current
        Analytics.bootstrap()
        Diagnostics.bootstrap()
        DeviceLaunchLogger.record()

        // Ensure Shortcuts picks up newly added/changed intent parameters.
        Task {
            ExpenseAppShortcuts.updateAppShortcutParameters()
        }

        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")
        if isUITesting {
            // UI tests drive the AI flows directly; a paywall or a spent quota would
            // make them fail for reasons unrelated to what they assert.
            ProEntitlementCache.update(isPro: true, expiresAt: nil)
        }
        if let container = try? IntentSwiftData.makeModelContainer() {
            sharedContainer = container
            TransactionTypeMigration.normalizeNoneTypesIfNeeded(
                modelContext: ModelContext(container)
            )
            #if DEBUG
            DebugSwiftBootstrap.rememberStores(
                ledger: container,
                inbox: try? MessageInboxSwiftData.makeModelContainer()
            )
            #endif
        } else {
            // Last-resort fallback — should never be reached in production.
            Diagnostics.log(
                "ModelContainer bootstrap fell back to in-memory store",
                level: .error,
                tags: [
                    Diagnostics.Tag.feature: Diagnostics.Feature.app.rawValue,
                    Diagnostics.Tag.stage: Diagnostics.Stage.bootstrap.rawValue
                ]
            )
            let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
            sharedContainer = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: isUITesting)]
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootContainerView()
        }
        .modelContainer(sharedContainer)
    }
}

// MARK: - Root sheet priority queue

/// All sheets that RootContainerView can display, ordered by priority (highest first).
private enum RootSheet: Identifiable, Equatable {
    case mandatoryUpdate(version: String?, storeURL: URL?)
    case onboarding
    case optionalUpdate(version: String?, storeURL: URL?)
    case paywall(PaywallContext)

    var id: String {
        switch self {
        case .mandatoryUpdate: "mandatoryUpdate"
        case .onboarding:      "onboarding"
        case .optionalUpdate:  "optionalUpdate"
        case .paywall(let context): "paywall.\(context.id)"
        }
    }
}

// MARK: - Root container

private struct RootContainerView: View {
    @Environment(\.modelContext) private var modelContext

    /// Stores the onboarding version the user has completed.
    /// 0 = never shown. Bump `OnboardingFlowView.currentVersion` in code to re-show on major updates.
    @AppStorage("spendriftOnboardingVersion") private var onboardingVersion = 0

    @State private var checker = AppUpdateChecker()
    @State private var entitlement = ProEntitlement.shared
    @State private var activeSheet: RootSheet?
    /// Finish. parks onboarding for the rest of this launch. `@State` so a cold start
    /// presents it again even when `spendriftOnboardingVersion` is already current.
    @State private var finishedOnboardingThisLaunch = false
    /// Guards against starting the background seed more than once per launch.
    @State private var didStartSeeding = false

    /// A Pro moment that has been earned but not yet shown. Held rather than presented
    /// immediately so it can queue behind the notification opt-in alert and behind the
    /// success animation of whichever feature just ran.
    @State private var pendingPaywall: PaywallContext?
    @State private var isReminderAlertVisible = false
    /// One paywall per launch. Four celebrations plus quota walls could otherwise
    /// stack up in a single session and read as nagging.
    @State private var didPresentPaywallThisSession = false

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    private var needsOnboarding: Bool {
        guard OnboardingFlowView.isEnabled, !isUITesting else { return false }
        if finishedOnboardingThisLaunch { return false }
        if OnboardingFlowView.showsEveryLaunch { return true }
        return onboardingVersion < OnboardingFlowView.currentVersion
    }

    /// Onboarding is a full page, not a card, so it is presented separately from the
    /// sheet queue. `activeSheet` still owns the priority ordering; these two bindings
    /// just route the winner to the right presentation.
    private var onboardingPresentation: Binding<Bool> {
        Binding(
            get: { activeSheet == .onboarding },
            set: { isPresented in
                guard !isPresented, activeSheet == .onboarding else { return }
                activeSheet = nil
            }
        )
    }

    private var sheetPresentation: Binding<RootSheet?> {
        Binding(
            get: { activeSheet == .onboarding ? nil : activeSheet },
            set: { newValue in
                guard newValue == nil, activeSheet != .onboarding else { return }
                activeSheet = nil
            }
        )
    }

    var body: some View {
        ContentView()
            .preferredColorScheme(.dark)
            .environment(AppRouter.shared)
            .task {
                entitlement.start()
                await checker.check()
                resolveActiveSheet()
                seedDefaultDataIfOnboardingDisabled()
            }
            // Completing onboarding updates `onboardingVersion` only; `activeSheet` must be cleared here
            // or the sheet never dismisses (onDisappear never runs while `.onboarding` stays set).
            .onChange(of: onboardingVersion) { _, _ in
                resolveActiveSheet()
            }
            // Seeding is unified here: the moment onboarding starts we seed the default
            // account and categories if the local store is empty.
            .onChange(of: activeSheet) { _, sheet in
                guard case .onboarding = sheet, !didStartSeeding else { return }
                didStartSeeding = true
                DefaultDataSeeder.seedIfNeeded(modelContext: modelContext)
            }
            // A feature just delivered its first win. Offer the trial on the payoff.
            .onReceive(NotificationCenter.default.publisher(for: .proMomentReached)) { note in
                guard let raw = note.userInfo?[ProGate.featureUserInfoKey] as? String,
                      let feature = ProFeature(rawValue: raw) else { return }
                queuePaywall(.celebration(feature))
            }
            // The user hit a wall rather than a win.
            .onReceive(NotificationCenter.default.publisher(for: .proQuotaExhausted)) { note in
                guard let raw = note.userInfo?[ProGate.featureUserInfoKey] as? String,
                      let feature = ProFeature(rawValue: raw) else { return }
                queuePaywall(.quotaExhausted(feature))
            }
            // The notification opt-in is a plain alert on ContentView. Presenting a
            // sheet over it would swallow the alert, so the paywall waits its turn.
            .onReceive(NotificationCenter.default.publisher(for: .reminderOptInShown)) { _ in
                isReminderAlertVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .reminderOptInDismissed)) { _ in
                isReminderAlertVisible = false
                resolveActiveSheet()
            }
            .onChange(of: entitlement.status) { _, _ in
                refreshTrialReminder()
                NotificationManager.refreshQuotaRefillReminder()
                resolveActiveSheet()
            }
            .sheet(isPresented: onboardingPresentation) {
                OnboardingFlowView(onboardingVersion: $onboardingVersion) {
                    finishedOnboardingThisLaunch = true
                    resolveActiveSheet()
                }
                .onDisappear { resolveActiveSheet() }
            }
            .sheet(item: sheetPresentation) { sheet in
                switch sheet {
                case .mandatoryUpdate(let version, let url):
                    AppUpdateSheet(kind: .mandatory, latestVersion: version, storeURL: url)
                        .interactiveDismissDisabled(true)

                case .onboarding:
                    // Presented by `fullScreenCover` above.
                    EmptyView()

                case .optionalUpdate(let version, let url):
                    AppUpdateSheet(kind: .optional, latestVersion: version, storeURL: url)

                case .paywall(let context):
                    ProPaywallView(context: context)
                        .onDisappear {
                            pendingPaywall = nil
                            resolveActiveSheet()
                        }
                }
            }
    }

    // MARK: - Paywall queueing

    /// Records a paywall to show and tries to surface it. Voice, receipts and imports
    /// all end with an on-screen success state; a short delay lets the user register
    /// the result they just got before being asked to pay for more of it.
    private func queuePaywall(_ context: PaywallContext) {
        guard !entitlement.isPro, !didPresentPaywallThisSession else { return }
        pendingPaywall = context
        Task {
            try? await Task.sleep(for: .milliseconds(1_200))
            resolveActiveSheet()
        }
    }

    private var canPresentPaywall: Bool {
        pendingPaywall != nil
            && !isReminderAlertVisible
            && !didPresentPaywallThisSession
            && !entitlement.isPro
            && !isUITesting
    }

    // MARK: - Trial reminder

    /// Re-stamps the day-5 trial reminder with a live count of what Pro has actually
    /// done, so the notification recaps value instead of just warning about a charge.
    private func refreshTrialReminder() {
        guard let trialEndsAt = entitlement.trialEndsAt else {
            ProTrialReminder.cancel()
            return
        }
        ProTrialReminder.refresh(
            trialEndsAt: trialEndsAt,
            aiTransactionCount: aiTransactionCount()
        )
    }

    private func aiTransactionCount() -> Int {
        let aiSources = Set(ProFeature.allCases.map(\.rawValue))
        let descriptor = FetchDescriptor<Transaction>()
        guard let all = try? modelContext.fetch(descriptor) else { return 0 }
        return all.filter { aiSources.contains($0.source) }.count
    }

    /// Default data is normally seeded when onboarding appears.
    /// With onboarding disabled, seed on launch so first-run still has a
    /// starter account and categories.
    private func seedDefaultDataIfOnboardingDisabled() {
        guard !OnboardingFlowView.isEnabled, !didStartSeeding else { return }
        didStartSeeding = true
        DefaultDataSeeder.seedIfNeeded(modelContext: modelContext)
    }

    /// Determines which sheet to surface based on priority:
    /// mandatory update > onboarding > optional update > paywall.
    private func resolveActiveSheet() {
        if case .mandatoryUpdate = activeSheet { return }

        if checker.updateKind == .mandatory {
            activeSheet = .mandatoryUpdate(
                version: checker.latestVersion,
                storeURL: checker.storeURL
            )
        } else if needsOnboarding {
            activeSheet = .onboarding
        } else if checker.updateKind == .optional {
            activeSheet = .optionalUpdate(
                version: checker.latestVersion,
                storeURL: checker.storeURL
            )
        } else if let pendingPaywall, canPresentPaywall {
            didPresentPaywallThisSession = true
            activeSheet = .paywall(pendingPaywall)
        } else {
            activeSheet = nil
        }
    }
}
