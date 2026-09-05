//
//  SettingsView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftData
import SwiftUI
import UIKit

#if DEBUG
    import DebugSwift
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex =
        Color.defaultThemeIndex
    @AppStorage(Color.legacyThemeColorKey) private var legacyThemeColorName =
        "Blue"
    @AppStorage(DeveloperMode.defaultsKey, store: DeveloperMode.store) private
        var developerModeUnlocked = false

    @State private var showMessageInboxDebug = false
    @State private var showDebugSwift = false
    @State private var versionTapCount = 0
    @State private var showReceiptScanOptions = false
    @State private var showStatementImport = false
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var receiptShare = ReceiptCaptureController()

    /// Taps on the version footer needed to reveal the developer tools.
    private static let developerRevealTapCount = 5

    private var accent: Color {
        Color.accentColor(forThemeIndex: selectedThemeIndex)
    }

    private var accentSoft: Color {
        accent.opacity(0.16)
    }

    private var appVersionLabel: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "-"
        return "Spendrift · v\(version)"
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            SettingsScreen(title: "Settings") {
                hubCard
                supportSection

                if showsDeveloperTools {
                    developerSection
                }

                versionFooter
            }
        }
        .tint(accent)
        .animation(.easeInOut(duration: 0.2), value: selectedThemeIndex)
        .animation(.easeInOut(duration: 0.2), value: developerModeUnlocked)
        .task {
            migrateThemeIfNeeded()
            selectedThemeIndex = Color.normalizedThemeIndex(selectedThemeIndex)
        }
        .sheet(isPresented: $showMessageInboxDebug) {
            MessageInboxDebugView()
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

    private var hubCard: some View {
        SettingsCard {
            ThemeStripRow(
                selectedIndex: $selectedThemeIndex,
                accent: accent,
                accentSoft: accentSoft
            )

            SettingsInsetDivider()

            NavigationLink {
                ExploreSettingsView()
            } label: {
                SettingsRow(
                    icon: "sparkles",
                    title: "Explore",
                    accent: accent,
                    accentSoft: accentSoft
                )
                .content
            }
            .buttonStyle(SettingsPressStyle())

            SettingsInsetDivider()

            SettingsRow(
                icon: "doc.viewfinder",
                title: "Scan receipt",
                subtitle: "From photo or camera",
                accent: accent,
                accentSoft: accentSoft,
                action: { showReceiptScanOptions = true }
            )

            SettingsInsetDivider()

            SettingsRow(
                icon: "doc.text",
                title: "Import bank statement",
                subtitle: "Upload a bank statement",
                accent: accent,
                accentSoft: accentSoft,
                action: { showStatementImport = true }
            )
        }
    }

    private var supportSection: some View {
        SettingsSection(title: "Support") {
            HelpSettingsCard()
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

    // MARK: - Theme

    private func processReceiptImage(_ image: UIImage) {
        receiptShare.process(
            image: image,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )
    }

    private func migrateThemeIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Color.selectedThemeIndexKey) == nil else {
            return
        }
        if let legacyIndex = Color.themeIndex(
            forLegacyThemeName: legacyThemeColorName
        ) {
            selectedThemeIndex = legacyIndex
        } else {
            selectedThemeIndex = Color.defaultThemeIndex
        }
        legacyThemeColorName = Color.legacyThemeName(
            forThemeIndex: selectedThemeIndex
        )
    }
}

#Preview {
    SettingsView()
        .modelContainer(
            for: [Transaction.self, Account.self, TransactionCategory.self],
            inMemory: true
        )
}
