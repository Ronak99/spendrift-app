//
//  CaptureSettingsView.swift
//  Spendrift
//
//  Drill-in listing every way a transaction can get into Spendrift:
//  the four manual entry points plus the SMS automation shortcut.
//

import SwiftUI
import SwiftData
import UIKit

struct CaptureSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex

    @State private var showStatementImport = false
    @State private var showReceiptScanOptions = false
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var receiptShare = ReceiptCaptureController()

    private var accent: Color { Color.accentColor(forThemeIndex: selectedThemeIndex) }
    private var accentSoft: Color { accent.opacity(0.16) }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                SettingsSection(title: "Add a transaction") {
                    SettingsCard {
                        SettingsRow(
                            icon: "mic.fill",
                            title: "Speak",
                            subtitle: "Add by voice · Siri Shortcut",
                            accent: accent,
                            accentSoft: accentSoft,
                            action: { open(OnboardingShortcutShareLinks.voiceRecordExpense) }
                        )

                        SettingsInsetDivider()

                        SettingsRow(
                            icon: "keyboard",
                            title: "Type",
                            subtitle: "Add manually · Siri Shortcut",
                            accent: accent,
                            accentSoft: accentSoft,
                            action: { open(OnboardingShortcutShareLinks.logExpenseAmount) }
                        )

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
                            title: "Import statement",
                            subtitle: "Upload a bank statement",
                            accent: accent,
                            accentSoft: accentSoft,
                            action: { showStatementImport = true }
                        )
                    }
                }

                if let logMessageURL = OnboardingShortcutShareLinks.logTransactionMessage {
                    automateSection(shortcutURL: logMessageURL)
                }
            }
            .padding(.horizontal, SettingsTokens.screenInset)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(SettingsTokens.screenBackground.ignoresSafeArea())
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
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
    }

    private func automateSection(shortcutURL: URL) -> some View {
        SettingsSection(title: "Automate") {
            VStack(alignment: .leading, spacing: 8) {
                SettingsCard {
                    SettingsRow(
                        icon: "message.fill",
                        title: "Log message",
                        subtitle: "Send the latest SMS to Spendrift",
                        accent: accent,
                        accentSoft: accentSoft,
                        action: { open(shortcutURL) }
                    )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Add this shortcut to a Messages automation and bank SMS get logged on arrival.")
                        .foregroundStyle(SettingsTokens.textSecondary)

                    NavigationLink {
                        BankSMSSettingsView()
                    } label: {
                        Text("See setup steps")
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 13))
                .padding(.horizontal, SettingsTokens.rowLeading)
            }
        }
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    private func processReceiptImage(_ image: UIImage) {
        receiptShare.process(
            image: image,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )
    }
}

#Preview {
    NavigationStack {
        CaptureSettingsView()
    }
    .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
