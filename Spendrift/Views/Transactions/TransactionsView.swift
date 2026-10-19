//
//  TransactionsView.swift
//  Spendrift
//
//  One month of the ledger, grouped by day, under a search bar and a month row.
//  Search is global: tapping the bar pushes the search screen over this tab.
//

import SwiftUI
import SwiftData
import UIKit

/// Drives the manual create-transaction sheet so quick-start mode is chosen atomically with presentation.
enum CreateTransactionSheetMode: Identifiable {
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
    /// Shared with Analytics, so picking a month on either tab carries over.
    @Binding var month: MonthRef
    /// Shared with `ContentView` so the capture started from the tab bar CTA is the same one
    /// this screen drives and renders.
    var voiceInline: VoiceInlineCaptureController
    @State private var showMonthPicker = false
    @State private var createTransactionSheet: CreateTransactionSheetMode?
    @State private var showStatementImport = false
    @State private var paywallContext: PaywallContext?
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var receiptShare = ReceiptCaptureController()
    /// Drives the transient "Transaction added" confirmation after a shared receipt is created.
    @State private var showReceiptShareCreated = false
    @State private var selectedTransaction: Transaction?

    /// Ids of the trigger payloads already handled, so a `.task(id:)` that restarts on
    /// tab reappearance does not reprocess the same (already-consumed) file and resurrect
    /// a previously dismissed error.
    @State private var lastProcessedReceiptImportID: UUID?
    @AppStorage("didFireFirstTransactionCreated") private var hasEverCreatedTransaction = false
    let receiptImport: ReceiptSharePayload?
    @Binding var messageInboxBanner: MessageInboxImportBanner?

    private let today = Date()

    init(
        month: Binding<MonthRef>,
        voiceInline: VoiceInlineCaptureController,
        receiptImport: ReceiptSharePayload? = nil,
        messageInboxBanner: Binding<MessageInboxImportBanner?> = .constant(nil)
    ) {
        self._month = month
        self.voiceInline = voiceInline
        self.receiptImport = receiptImport
        self._messageInboxBanner = messageInboxBanner
    }

    private var transactions: [Transaction] {
        let range = month.dateRange()
        return allTransactions.filter { transaction in
            transaction.isPersisted && range.contains(transaction.date)
        }
    }

    private var categoriesSortedByLastUsed: [TransactionCategory] {
        categories.sortedByLastUsage()
    }

    private var isCurrentMonth: Bool {
        month.contains(today)
    }

    private var earliestYear: Int {
        allTransactions.last(where: \.isPersisted)?.date.year ?? today.year
    }

    /// Status of the receipt shared into the app via the Share Extension.
    /// Scanning is shown by the compact processing capsule below; this bar only
    /// surfaces the brief post-create confirmation.
    private var receiptShareStatus: ReceiptShareStatus {
        if showReceiptShareCreated { return .created }
        return .hidden
    }

    private func openCreateTransactionSheet() {
        if hasEverCreatedTransaction {
            createTransactionSheet = .standard
        } else {
            createTransactionSheet = .quickStartFirst
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    emptyLedger
                } else {
                    ledger
                }
            }
            .ledgerSearchHeader { monthRow }
            .background(AppTheme.canvas.ignoresSafeArea())
            .ledgerNavigationTitle(HomeTab.transactions.title)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                LedgerToolbar(
                    addAccessibilityLabel: "Add transaction",
                    addAccessibilityIdentifier: "transactionsAddButton",
                    onAdd: openCreateTransactionSheet
                )
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    if let banner = messageInboxBanner {
                        MessageInboxImportBannerView(
                            count: banner.count,
                            blockedCount: banner.blockedCount,
                            onUndo: {
                                let ids = banner.transactionIDs
                                dismissBanner()
                                MessageInboxSyncService.undoImport(
                                    transactionIDs: ids,
                                    modelContext: modelContext
                                )
                            },
                            onDismiss: dismissBanner,
                            onUpgrade: {
                                dismissBanner()
                                paywallContext = .quotaExhausted(.messageImport)
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
            .sheet(isPresented: $showMonthPicker) {
                MonthYearPickerSheet(
                    selection: month,
                    earliestYear: earliestYear,
                    today: today
                ) { picked in
                    month = picked
                }
            }
            .sheet(isPresented: $showStatementImport) {
                StatementImportView()
            }
            .fullScreenCover(isPresented: $showReceiptCamera) {
                ReceiptCameraPicker { image in
                    showReceiptCamera = false
                    if let image {
                        ProAccess.attempt(.receiptScan, paywall: $paywallContext) {
                            processReceiptImage(image)
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showReceiptLibrary) {
                PhotoLibraryPicker { image in
                    showReceiptLibrary = false
                    if let image {
                        ProAccess.attempt(.receiptScan, paywall: $paywallContext) {
                            processReceiptImage(image)
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(item: $createTransactionSheet) { mode in
                UpdateTransactionSheet(
                    transaction: nil,
                    quickStartFirstTransaction: mode.quickStartFirstTransaction,
                    onVoiceCreate: startVoiceQuickAdd,
                    voiceCaptureDisabled: voiceInline.blocksNewCapture
                )
            }
            .sheet(item: $selectedTransaction) { transaction in
                UpdateTransactionSheet(transaction: transaction)
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
            // A capture can be started from the tab bar CTA or a shortcut while this sheet
            // is open; close it so the recording bar is not hidden behind it.
            .onChange(of: voiceInline.displayState) { _, state in
                guard state == .recording || state == .processing else { return }
                createTransactionSheet = nil
            }
            .proPaywall($paywallContext)
        }
    }

    // MARK: Header

    /// The month on show, pinned under the search bar. The label opens the picker; the chevrons step a month at a time,
    /// as the period capsule used to, and never past the month in progress.
    private var monthRow: some View {
        HStack(spacing: 8) {
            Button {
                showMonthPicker = true
            } label: {
                LedgerDropdownLabel(text: month.title(relativeTo: today))
            }
            .buttonStyle(HomePressStyle(scale: 1))
            .accessibilityLabel("Change month")
            .accessibilityValue(month.title(relativeTo: today))
            .accessibilityIdentifier("transactionsMonthButton")

            Spacer(minLength: 8)

            monthStep(systemImage: "chevron.left", label: "Previous month", enabled: true) {
                month = month.previous
            }
            monthStep(systemImage: "chevron.right", label: "Next month", enabled: !isCurrentMonth) {
                month = month.next
            }
        }
        .padding(.horizontal, 4)
    }

    private func monthStep(
        systemImage: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.inkSecondary)
                .frame(width: 30, height: 30)
                .background(AppTheme.cardAlternate, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    // MARK: Ledger

    private var ledger: some View {
        List {
            ForEach(transactions.groupedByDateRecentFirst, id: \.dayStart) { section in
                Section {
                    ForEach(Array(section.transactions.enumerated()), id: \.element.id) { index, transaction in
                        TransactionListItem(transaction: transaction)
                            .listItemPositioned(index: index, count: section.transactions.count)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTransaction = transaction
                            }
                            .listRowBackground(AppTheme.card)
                    }
                    .onDelete { indexSet in
                        deleteTransactions(at: indexSet, in: section.transactions)
                    }
                } header: {
                    Text(section.title)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.1)
                        .textCase(nil)
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        // Air between the header bar and the first day, scrolling with the rows.
        .contentMargins(.top, 4, for: .scrollContent)
        .softScrollEdge()
    }

    private var emptyLedger: some View {
        VStack {
            CategoryEnamelTile(
                systemImage: "tray.fill",
                color: CategoryEnamel.uncategorized
            )
            .frame(width: 72, height: 72)
            .padding(.top, 24)

            Spacer()
                .frame(height: 16)

            Text("No transactions")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)

            Spacer()
                .frame(height: 8)

            Text("Add one for \(month.title(relativeTo: today)).")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: 24)

            Button(action: openCreateTransactionSheet) {
                Text("Add transaction")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.actionBackground, in: Capsule())
                    .foregroundStyle(AppTheme.actionForeground)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: Behaviour

    /// Starts an in-app voice quick-add and records the entry point. Fired for every
    /// in-app voice affordance (persistent mic, add-menu "Speak", empty-state "Speak")
    /// so voice-entry usage is tracked. The Siri/Shortcuts launch path fires its own
    /// `shortcut_used` in `ContentView`, so it deliberately does not route through here
    /// and is not double-counted; `source` distinguishes the in-app CTA from that path.
    private func startVoiceQuickAdd() {
        // Checked before the mic opens: starting a recording that the service layer
        // will refuse would waste the user's breath.
        ProAccess.attempt(.voice, paywall: $paywallContext) {
            Analytics.capture(.shortcutUsed, [
                Analytics.Key.kind: "voice",
                Analytics.Key.source: "transactions_cta"
            ])
            voiceInline.beginCapture()
        }
    }

    private func dismissBanner() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            messageInboxBanner = nil
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

extension MonthRef {
    /// The month after this one. The step buttons never go past the month in progress.
    var next: MonthRef {
        month == 12 ? MonthRef(year: year + 1, month: 1) : MonthRef(year: year, month: month + 1)
    }
}

#Preview {
    TransactionsView(
        month: .constant(MonthRef.of(Date())),
        voiceInline: VoiceInlineCaptureController()
    )
    .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
