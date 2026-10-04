//
//  SettingsView.swift
//  Spendrift
//
//  Settings hub. Enamel rows and capsule controls match Transactions
//  and Categories so the tabs feel like one box.
//

import SwiftData
import SwiftUI
import UIKit
import UserNotifications

#if DEBUG
    import DebugSwift
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @AppStorage(DeveloperMode.defaultsKey, store: DeveloperMode.store) private
        var developerModeUnlocked = false

    @State private var entitlement = ProEntitlement.shared
    @State private var showMessageInboxDebug = false
    @State private var showDebugSwift = false
    @State private var versionTapCount = 0
    @State private var showDeveloperUnlock = false
    @State private var showReceiptScanOptions = false
    @State private var showStatementImport = false
    @State private var paywallContext: PaywallContext?
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var receiptShare = ReceiptCaptureController()
    @State private var notificationAuthorization: UNAuthorizationStatus?
    @State private var awaitingSystemGrant = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router

    /// Taps on the version footer needed to reveal the developer tools.
    private static let developerRevealTapCount = 5

    private var accent: Color {
        AppTheme.accent
    }

    private var appVersionLabel: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "-"
        return "Spendrift v\(version)"
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.settingsPath) {
            SettingsScreen(title: "Settings", showsAtmosphere: false) {
                proSection
                hubSection
                supportSection

                if showsDeveloperTools {
                    developerSection
                }

                versionSection
            }
            .navigationDestination(for: AppRouter.SettingsDestination.self) { destination in
                switch destination {
                case .feedback:
                    FeedbackView()
                case .explore:
                    ExploreSettingsView()
                case .emailReceipts:
                    EmailReceiptsSettingsView()
                case .backup:
                    BackupSettingsView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: developerModeUnlocked)
        .task { await refreshNotificationAuthorization() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshNotificationAuthorization() }
        }
        .sheet(isPresented: $showMessageInboxDebug) {
            MessageInboxDebugView()
        }
        .sheet(isPresented: $showDeveloperUnlock) {
            DeveloperUnlockSheet {
                developerModeUnlocked = true
            }
        }
        .proPaywall($paywallContext)
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
        #if DEBUG
            .fullScreenCover(
                isPresented: $showDebugSwift,
                onDismiss: {
                    DebugSwift.debugViewControllerDidDismiss()
                }
            ) {
                DebugSwiftViewControllerRepresentable(onDismiss: {
                    showDebugSwift = false
                })
                .ignoresSafeArea()
            }
        #endif
    }

    // MARK: - Hub

    private var showsNotificationOptIn: Bool {
        guard let notificationAuthorization else { return false }
        return notificationAuthorization == .notDetermined
            || notificationAuthorization == .denied
    }

    // Rows actually rendered: Feedback, optional notification opt-in, Explore,
    // Backup & restore, and Email receipts while developer mode is on. The count
    // drives the first/last padding, so it must not include the commented-out
    // rows below.
    private var hubRowCount: Int {
        var count = 3
        if showsNotificationOptIn { count += 1 }
        if showsDeveloperTools { count += 1 }
        return count
    }

    private var exploreIndex: Int { showsNotificationOptIn ? 2 : 1 }
    private var backupIndex: Int { exploreIndex + 1 }
    private var emailReceiptsIndex: Int { backupIndex + 1 }
    private var receiptIndex: Int { showsNotificationOptIn ? 3 : 2 }
    private var statementIndex: Int { showsNotificationOptIn ? 4 : 3 }

    @ViewBuilder
    private var hubSection: some View {
        Section {
            NavigationLink(value: AppRouter.SettingsDestination.feedback) {
                SettingsListItem(
                    icon: "bubble.left.and.text.bubble.right.fill",
                    title: "Feedback",
                    accent: accent
                )
                .listItemPositioned(index: 0, count: hubRowCount)
            }

            if showsNotificationOptIn {
                notificationOptInRow
            }

            NavigationLink(value: AppRouter.SettingsDestination.explore) {
                SettingsListItem(
                    icon: "sparkles",
                    title: "Explore",
                    accent: accent
                )
                .listItemPositioned(index: exploreIndex, count: hubRowCount)
            }

            NavigationLink(value: AppRouter.SettingsDestination.backup) {
                SettingsListItem(
                    icon: "icloud.and.arrow.up.fill",
                    title: "Backup & restore",
                    accent: accent
                )
                .listItemPositioned(index: backupIndex, count: hubRowCount)
            }

            if showsDeveloperTools {
                NavigationLink(value: AppRouter.SettingsDestination.emailReceipts) {
                    SettingsListItem(
                        icon: "envelope.fill",
                        title: "Email receipts",
                        subtitle: "Forward receipts to your own address",
                        accent: accent
                    )
                    .listItemPositioned(index: emailReceiptsIndex, count: hubRowCount)
                }
            }

            // Button {
            //     showReceiptScanOptions = true
            // } label: {
            //     SettingsListItem(
            //         icon: "doc.viewfinder",
            //         title: "Scan Receipts",
            //         accent: accent,
            //         accessory: .chevron
            //     )
            //     .listItemPositioned(index: receiptIndex, count: hubRowCount)
            // }
            // .buttonStyle(.plain)
            // .confirmationDialog("Scan receipt", isPresented: $showReceiptScanOptions, titleVisibility: .visible) {
            //     Button("Take Photo") {
            //         ProAccess.attempt(.receiptScan, paywall: $paywallContext) {
            //             showReceiptCamera = true
            //         }
            //     }
            //     .disabled(!cameraAvailable || receiptShare.isProcessing)

            //     Button("Choose from Library") {
            //         ProAccess.attempt(.receiptScan, paywall: $paywallContext) {
            //             showReceiptLibrary = true
            //         }
            //     }
            //     .disabled(receiptShare.isProcessing)

            //     Button("Cancel", role: .cancel) {}
            // }

            // Button {
            //     ProAccess.attempt(.statementImport, paywall: $paywallContext) {
            //         showStatementImport = true
            //     }
            // } label: {
            //     SettingsListItem(
            //         icon: "doc.text",
            //         title: "Bank Statements",
            //         accent: accent,
            //         accessory: .chevron
            //     )
            //         .listItemPositioned(index: statementIndex, count: hubRowCount)
            // }
            // .buttonStyle(.plain)
        }
    }

    private var notificationOptInRow: some View {
        SettingsListItem(
            icon: "bell.badge.fill",
            title: "Turn on notifications",
            subtitle: "Budget alerts, weekly notes, and refill reminders.",
            accent: accent,
            accessory: .toggle(notificationToggle)
        )
        .listItemPositioned(index: 1, count: hubRowCount)
    }

    private var notificationToggle: Binding<Bool> {
        Binding(
            get: { false },
            set: { newValue in
                guard newValue else { return }
                Task { await enableNotificationsFromToggle() }
            }
        )
    }

    private var proSection: some View {
        Section("Spendrift Pro") {
            ProSettingsRows(paywallContext: $paywallContext)
        }
    }

    private var supportSection: some View {
        Section("Support") {
            HelpSettingsRows()
        }
    }

    private var developerRowCount: Int {
        var count = 1
        #if DEBUG
            count += 2
        #endif
        if developerModeUnlocked { count += 1 }
        return count
    }

    @ViewBuilder
    private var developerSection: some View {
        Section("Developer") {
            #if DEBUG
                Button {
                    DebugSwift.debugViewControllerWillPresent()
                    showDebugSwift = true
                } label: {
                    SettingsListItem(
                        icon: "internaldrive.fill",
                        title: "SQLite debugger",
                        accent: accent,
                        accessory: .chevron
                    )
                    .listItemPositioned(index: 0, count: developerRowCount)
                }
                .buttonStyle(.plain)
            #endif

            SettingsListItem(
                    icon: "crown.fill",
                    title: "Force Pro",
                    subtitle: "Act as a subscriber, however the app launches",
                    accent: accent,
                    accessory: .toggle(forcedProBinding)
            )
            .listItemPositioned(index: 1, count: developerRowCount)

            Button {
                showMessageInboxDebug = true
            } label: {
                SettingsListItem(
                    icon: "ladybug.fill",
                    title: "Message inbox debug",
                    accent: accent,
                    accessory: .chevron
                )
                .listItemPositioned(index: messageInboxDeveloperOffset, count: developerRowCount)
            }
            .buttonStyle(.plain)

            if developerModeUnlocked {
                Button {
                    developerModeUnlocked = false
                } label: {
                    SettingsListItem(
                        icon: "lock.fill",
                        title: "Turn off developer mode",
                        accent: accent
                    )
                    .listItemPositioned(.last)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var forcedProBinding: Binding<Bool> {
        Binding(
            get: { entitlement.isForcedPro },
            set: { entitlement.setForcedPro($0) }
        )
    }

    private var messageInboxDeveloperOffset: Int {
        #if DEBUG
            2
        #else
            0
        #endif
    }

    private var versionSection: some View {
        Section {
            Text(appVersionLabel)
                .font(.system(size: 12))
                .foregroundStyle(SettingsTokens.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .contentShape(Rectangle())
                .onTapGesture { registerVersionTap() }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Tap five times to unlock developer tools with a password")
        }
    }

    private var showsDeveloperTools: Bool {
        developerModeUnlocked || DeveloperMode.isEnabled
    }

    /// Hidden unlock: five taps on the version label open a password prompt;
    /// only DEVELOPER_PASSWORD unlocks the developer section.
    private func registerVersionTap() {
        guard !developerModeUnlocked else { return }
        versionTapCount += 1
        guard versionTapCount >= Self.developerRevealTapCount else { return }
        versionTapCount = 0
        showDeveloperUnlock = true
    }

    private func processReceiptImage(_ image: UIImage) {
        receiptShare.process(
            image: image,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )
    }

    private func refreshNotificationAuthorization() async {
        let status = await NotificationManager.authorizationStatus()
        if awaitingSystemGrant, NotificationManager.isPermissionGranted(status) {
            awaitingSystemGrant = false
            _ = await PushNotifications.enableFromSettings()
        }
        notificationAuthorization = status
    }

    private func enableNotificationsFromToggle() async {
        let status = await NotificationManager.authorizationStatus()
        if status == .denied {
            awaitingSystemGrant = true
        }
        let granted = await PushNotifications.enableFromSettings()
        await refreshNotificationAuthorization()
        if granted {
            withAnimation(.easeInOut(duration: 0.2)) {
                notificationAuthorization = .authorized
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppRouter.shared)
        .modelContainer(
            for: [Transaction.self, Account.self, TransactionCategory.self],
            inMemory: true
        )
}
