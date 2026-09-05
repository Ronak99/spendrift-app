//
//  CaptureSettingsView.swift
//  Spendrift
//
//  Drill-in listing every way a transaction can get into Spendrift
//  by hand: speak, type, scan a receipt, or import a statement.
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

    private static let rowCount = 4

    var body: some View {
        SettingsScreen(title: "Capture") {
            Section {
                Button {
                    open(OnboardingShortcutShareLinks.voiceRecordExpense)
                } label: {
                    SettingsListItem(
                        icon: "mic.fill",
                        title: "Speak",
                        subtitle: "Add by voice · Siri Shortcut",
                        accent: accent,
                        accentSoft: accentSoft,
                        accessory: .chevron
                    )
                    .listItemPositioned(index: 0, count: Self.rowCount)
                }
                .buttonStyle(.plain)

                Button {
                    open(OnboardingShortcutShareLinks.logExpenseAmount)
                } label: {
                    SettingsListItem(
                        icon: "keyboard",
                        title: "Type",
                        subtitle: "Add manually · Siri Shortcut",
                        accent: accent,
                        accentSoft: accentSoft,
                        accessory: .chevron
                    )
                    .listItemPositioned(index: 1, count: Self.rowCount)
                }
                .buttonStyle(.plain)

                Button {
                    showReceiptScanOptions = true
                } label: {
                    SettingsListItem(
                        icon: "doc.viewfinder",
                        title: "Scan receipt",
                        subtitle: "From photo or camera",
                        accent: accent,
                        accentSoft: accentSoft,
                        accessory: .chevron
                    )
                    .listItemPositioned(index: 2, count: Self.rowCount)
                }
                .buttonStyle(.plain)

                Button {
                    showStatementImport = true
                } label: {
                    SettingsListItem(
                        icon: "doc.text",
                        title: "Import statement",
                        subtitle: "Upload a bank statement",
                        accent: accent,
                        accentSoft: accentSoft,
                        accessory: .chevron
                    )
                    .listItemPositioned(index: 3, count: Self.rowCount)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Add a transaction")
            }
        }
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
