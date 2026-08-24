//
//  TransactionsView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.

import SwiftUI
import SwiftData
import UIKit

/// Drives the manual create-transaction sheet so quick-start mode is chosen atomically with presentation.
private enum CreateTransactionSheetMode: Identifiable {
    case standard
    case quickStartFirst

    var id: Self { self }

    var quickStartFirstTransaction: Bool {
        self == .quickStartFirst
    }
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    var periodViewModel: TransactionViewModel
    @State private var createTransactionSheet: CreateTransactionSheetMode?
    @State private var showStatementImport = false
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var voiceInline = VoiceInlineCaptureController()
    @State private var receiptShare = ReceiptCaptureController()
    /// Drives the transient "Transaction added" confirmation after a shared receipt is created.
    @State private var showReceiptShareCreated = false
    @State private var selectedTransaction: Transaction?
    /// Ids of the trigger payloads already handled, so a `.task(id:)` that restarts on
    /// tab reappearance does not reprocess the same (already-consumed) file and resurrect
    /// a previously dismissed error.
    @State private var lastProcessedReceiptImportID: UUID?
    @State private var lastProcessedShortcutAudioID: UUID?
    @AppStorage("didFireFirstTransactionCreated") private var hasEverCreatedTransaction = false
    let voiceCaptureTrigger: UUID?
    let useCompactVoiceCapture: Bool
    let shortcutImportedAudio: ShortcutImportedAudioPayload?
    let receiptImport: ReceiptSharePayload?
    @Binding var messageInboxBanner: MessageInboxImportBanner?

    init(
        periodViewModel: TransactionViewModel,
        voiceCaptureTrigger: UUID? = nil,
        useCompactVoiceCapture: Bool = false,
        shortcutImportedAudio: ShortcutImportedAudioPayload? = nil,
        receiptImport: ReceiptSharePayload? = nil,
        messageInboxBanner: Binding<MessageInboxImportBanner?> = .constant(nil)
    ) {
        self.periodViewModel = periodViewModel
        self.voiceCaptureTrigger = voiceCaptureTrigger
        self.useCompactVoiceCapture = useCompactVoiceCapture
        self.shortcutImportedAudio = shortcutImportedAudio
        self.receiptImport = receiptImport
        self._messageInboxBanner = messageInboxBanner
    }
    
    private var transactions: [Transaction] {
        allTransactions.filter { transaction in
            transaction.isPersisted &&
            transaction.date >= periodViewModel.periodStart &&
            transaction.date <= periodViewModel.periodEnd
        }
    }
    
    
    private var totalExpenses: Double {
        transactions.totalExpenses
    }

    private var totalIncome: Double {
        transactions.totalIncome
    }

    private var savings: Double {
        transactions.savings
    }

    /// Round summary figures when there are many transactions — decimal precision
    /// adds noise rather than clarity at that scale.
    private var usesRoundedSummary: Bool {
        transactions.count > 10
    }

    private var formattedExpenses: String {
        usesRoundedSummary ? totalExpenses.formatCurrencyRounded : totalExpenses.formatCurrency
    }

    private var formattedIncome: String {
        usesRoundedSummary ? totalIncome.formatCurrencyRounded : totalIncome.formatCurrency
    }

    private var formattedSavings: String {
        usesRoundedSummary ? savings.formatCurrencyRounded : savings.formatCurrency
    }

    private var categoriesSortedByLastUsed: [TransactionCategory] {
        categories.sortedByLastUsage()
    }

    /// Status of the receipt shared into the app via the Share Extension.
    /// Scanning is shown by the compact processing capsule below; this bar only
    /// surfaces the brief post-create confirmation.
    private var receiptShareStatus: ReceiptShareStatus {
        if showReceiptShareCreated { return .created }
        return .hidden
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var receiptScanActions: ReceiptScanMenuActions {
        ReceiptScanMenuActions(
            onTakePhoto: { showReceiptCamera = true },
            onChooseFromLibrary: { showReceiptLibrary = true },
            cameraDisabled: !cameraAvailable,
            disabled: receiptShare.isProcessing
        )
    }


    /// Empty-state add menu. Before the user has ever created a transaction it shows a focused
    /// two-option menu (Create Expense / Speak Expense); afterwards it mirrors the toolbar add menu.
    private var emptyStateAddMenu: EmptyStateAddTransactionMenu {
        if hasEverCreatedTransaction {
            return EmptyStateAddTransactionMenu(
                onSpeak: { voiceInline.beginCapture() },
                onType: { createTransactionSheet = .standard },
                onUploadDocument: { showStatementImport = true },
                receiptScan: receiptScanActions,
                voiceDisabled: voiceInline.blocksNewCapture
            )
        }
        return EmptyStateAddTransactionMenu(
            onSpeak: { voiceInline.beginCapture() },
            onType: { createTransactionSheet = .quickStartFirst },
            onUploadDocument: { showStatementImport = true },
            voiceDisabled: voiceInline.blocksNewCapture,
            typeLabel: "Create Expense",
            speakLabel: "Speak Expense",
            showsUploadAndScan: false
        )
    }

    var body: some View {
        @Bindable var voice = voiceInline
        @Bindable var periodViewModel = periodViewModel
        NavigationStack {
            VStack(spacing: 0) {
                // Header with date selector
                VStack(spacing: 16) {
                    CapsuleDateSelector(
                        period: periodViewModel.periodGranularity,
                        title: periodViewModel.capsuleTitle,
                        date: periodViewModel.selectedDate,
                        isCurrentPeriod: periodViewModel.isCurrentPeriod,
                        onPrevious: { periodViewModel.decrementPeriod() },
                        onNext: { periodViewModel.incrementPeriod() },
                        onToday: { periodViewModel.goToCurrentPeriod() },
                        onJumpToDate: { periodViewModel.goToDate($0) }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Statistics bar
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expenses")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedExpenses)
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text("Income")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedIncome)
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Savings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedSavings)
                                .font(.headline)
                                .foregroundColor(savings >= 0 ? .green : .red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
                
                // Transaction list
                if transactions.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "No Transactions",
                        description: "Get started by adding your first transaction for \(periodViewModel.periodDescription)",
                        actionTitle: "Add Transaction",
                        addTransactionMenu: emptyStateAddMenu
                    )
                } else {
                    List {
                        ForEach(transactions.groupedByDateRecentFirst, id: \.dayStart) { section in
                            Section {
                                ForEach(section.transactions, id: \.id) { transaction in
                                    TransactionListItem(transaction: transaction)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedTransaction = transaction
                                        }
                                }
                                .onDelete { indexSet in
                                    deleteTransactions(at: indexSet, in: section.transactions)
                                }
                            } header: {
                                Text(section.title)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                if !transactions.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        TransactionPeriodToolbarMenu(period: $periodViewModel.periodGranularity)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        if !transactions.isEmpty {
                            Menu {
                                Button {
                                    createTransactionSheet = .standard
                                } label: {
                                    Label("Type", systemImage: "keyboard")
                                }

                                Button {
                                    voiceInline.beginCapture()
                                } label: {
                                    Label("Speak", systemImage: "mic")
                                }
                                .disabled(voiceInline.blocksNewCapture)


                                Button {
                                    showStatementImport = true
                                } label: {
                                    Label("Upload document", systemImage: "doc.text")
                                }

                                Menu {
                                    Button {
                                        showReceiptCamera = true
                                    } label: {
                                        Label("Take Photo", systemImage: "camera")
                                    }
                                    .disabled(!cameraAvailable || receiptShare.isProcessing)

                                    Button {
                                        showReceiptLibrary = true
                                    } label: {
                                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                                    }
                                    .disabled(receiptShare.isProcessing)
                                } label: {
                                    Label("Scan receipt", systemImage: "doc.viewfinder")
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                            .menuOrder(.fixed)
                            .accessibilityLabel("Add transaction")
                            .accessibilityIdentifier("transactionsAddMenu")
                        }

                        ProfileSettingsToolbarButton()
                    }
                    .padding(.horizontal, transactions.isEmpty ? 0 : 8)
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    if let banner = messageInboxBanner {
                        MessageInboxImportBannerView(
                            count: banner.count,
                            onUndo: {
                                let ids = banner.transactionIDs
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                    messageInboxBanner = nil
                                }
                                MessageInboxSyncService.undoImport(
                                    transactionIDs: ids,
                                    modelContext: modelContext
                                )
                            },
                            onDismiss: {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                    messageInboxBanner = nil
                                }
                            }
                        )
                    }

                    ReceiptShareStatusBar(status: receiptShareStatus)

                    if receiptShare.isProcessing {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Reading receipt…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                        )
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        VoiceInlineRecordingBar(
                            controller: voiceInline,
                            accounts: accounts,
                            categories: categoriesSortedByLastUsed
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: voiceInline.displayState)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: receiptShare.isProcessing)
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
            .sheet(item: $createTransactionSheet) { mode in
                UpdateTransactionSheet(
                    transaction: nil,
                    quickStartFirstTransaction: mode.quickStartFirstTransaction
                )
            }
            .sheet(item: $selectedTransaction) { transaction in
                UpdateTransactionSheet(transaction: transaction)
            }
            .sheet(item: $voice.manualSheetPayload) { payload in
                UpdateTransactionSheet(
                    transaction: nil,
                    draft: payload.draft,
                    voiceReviewHint: payload.hint
                )
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
            .task(id: receiptImport?.id) {
                guard let payload = receiptImport else { return }
                guard lastProcessedReceiptImportID != payload.id else { return }
                lastProcessedReceiptImportID = payload.id
                createTransactionSheet = nil
                showReceiptShareCreated = false
                receiptShare.processSharedImage(
                    fileURL: payload.fileURL,
                    accounts: accounts,
                    categories: categories,
                    modelContext: modelContext
                )
            }
            .onChange(of: receiptShare.didCreate) { _, created in
                guard created else { return }
                receiptShare.acknowledgeCreate()
                showReceiptShareCreated = true
                Task {
                    try? await Task.sleep(for: .seconds(2.2))
                    showReceiptShareCreated = false
                }
            }
            .onChange(of: voiceCaptureTrigger) { _, trigger in
                guard trigger != nil else { return }
                createTransactionSheet = nil
                voiceInline.beginCapture()
            }
            .task(id: shortcutImportedAudio?.id) {
                guard let payload = shortcutImportedAudio else { return }
                guard lastProcessedShortcutAudioID != payload.id else { return }
                lastProcessedShortcutAudioID = payload.id
                createTransactionSheet = nil
                voiceInline.processImportedAudio(
                    fileURL: payload.fileURL,
                    modelContext: modelContext,
                    accounts: accounts,
                    categories: categories
                )
            }
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet, in transactionsForDay: [Transaction]) {
        for index in offsets {
            modelContext.delete(transactionsForDay[index])
        }
        try? modelContext.save()
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
    TransactionsView(periodViewModel: TransactionViewModel())
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
