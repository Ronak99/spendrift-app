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
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    var periodViewModel: TransactionViewModel
    /// Shared with `ContentView` so the capture started from the tab bar CTA is the same one
    /// this screen drives and renders.
    var voiceInline: VoiceInlineCaptureController
    @State private var createTransactionSheet: CreateTransactionSheetMode?
    @State private var showStatementImport = false
    @State private var paywallContext: PaywallContext?
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var receiptShare = ReceiptCaptureController()
    /// Drives the transient "Transaction added" confirmation after a shared receipt is created.
    @State private var showReceiptShareCreated = false
    @State private var selectedTransaction: Transaction?
    @State private var showAnalyticsSheet = false
    @State private var drillCategory: TransactionCategory?

    /// Content height of the summary card's list row, excluding its row insets.
    /// Enough for the totals, the curve, and the legend without crowding any of them.
    private static let analyticsCardHeight: CGFloat = 164
    /// Ids of the trigger payloads already handled, so a `.task(id:)` that restarts on
    /// tab reappearance does not reprocess the same (already-consumed) file and resurrect
    /// a previously dismissed error.
    @State private var lastProcessedReceiptImportID: UUID?
    @AppStorage("didFireFirstTransactionCreated") private var hasEverCreatedTransaction = false
    let receiptImport: ReceiptSharePayload?
    @Binding var messageInboxBanner: MessageInboxImportBanner?

    init(
        periodViewModel: TransactionViewModel,
        voiceInline: VoiceInlineCaptureController,
        receiptImport: ReceiptSharePayload? = nil,
        messageInboxBanner: Binding<MessageInboxImportBanner?> = .constant(nil)
    ) {
        self.periodViewModel = periodViewModel
        self.voiceInline = voiceInline
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

    private var isDark: Bool { colorScheme == .dark }

    private var canvas: Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    private var addBackground: Color {
        isDark ? Color.white.opacity(0.92) : Color(hex: "#111111")
    }

    private var addForeground: Color {
        isDark ? Color(hex: "#111111") : .white
    }

    /// Status of the receipt shared into the app via the Share Extension.
    /// Scanning is shown by the compact processing capsule below; this bar only
    /// surfaces the brief post-create confirmation.
    private var receiptShareStatus: ReceiptShareStatus {
        if showReceiptShareCreated { return .created }
        return .hidden
    }

    /// Tapping the summary card is now the only way into the full analytics screen,
    /// so this is where the audience tag is recorded.
    private func showAnalytics() {
        showAnalyticsSheet = true
        AudienceTags.markSeenAnalytics()
    }

    private func openCreateTransactionSheet() {
        if hasEverCreatedTransaction {
            createTransactionSheet = .standard
        } else {
            createTransactionSheet = .quickStartFirst
        }
    }

    var body: some View {
        @Bindable var periodViewModel = periodViewModel
        return NavigationStack {
            Group {
                if transactions.isEmpty {
                    emptyLedger
                } else {
                    List {
                        // Leads the ledger and scrolls away with it. The height is fixed
                        // rather than a fraction of the screen: inside a List a relative
                        // height resolves against the row, not the scroll view, which
                        // collapsed the card and clipped its labels.
                        Section {
                            PeriodAnalyticsCard(
                                transactions: transactions,
                                periodStart: periodViewModel.periodStart,
                                periodEnd: periodViewModel.periodEnd,
                                expenses: formattedExpenses,
                                income: formattedIncome,
                                savings: formattedSavings,
                                savingsValue: savings,
                                onOpenAnalytics: { showAnalytics() }
                            )
                            .listRowInsets(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
                            .frame(height: Self.analyticsCardHeight)
                        } header: {
                            Text("Analytics")
                        }

                        ForEach(transactions.groupedByDateRecentFirst, id: \.dayStart) { section in
                            Section {
                                ForEach(Array(section.transactions.enumerated()), id: \.element.id) { index, transaction in
                                    TransactionListItem(transaction: transaction)
                                        .listItemPositioned(index: index, count: section.transactions.count)
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
                    .scrollContentBackground(.hidden)
                    .softScrollEdge()
                }
            }
            .scrollingHeaderBar {
                // Only the period control is pinned now; the totals moved into the
                // scrolling ledger as the analytics card.
                VStack(spacing: 0) {
                    CapsuleDateSelector(
                        period: $periodViewModel.periodGranularity,
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
                    .padding(.bottom, 10)
                }
            }
            .background { canvas.ignoresSafeArea() }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAnalyticsSheet) {
                analyticsSheet
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    if let banner = messageInboxBanner {
                        MessageInboxImportBannerView(
                            count: banner.count,
                            blockedCount: banner.blockedCount,
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
                            },
                            onUpgrade: {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                    messageInboxBanner = nil
                                }
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
            // A capture can now be started from the tab bar CTA or a shortcut while this sheet
            // is open; close it so the recording bar is not hidden behind it.
            .onChange(of: voiceInline.displayState) { _, state in
                guard state == .recording || state == .processing else { return }
                createTransactionSheet = nil
            }
            // Tapping the Home tab again while analytics is up closes it and returns to
            // the ledger, matching the tab-bar's "tap to go back" affordance.
            .proPaywall($paywallContext)
            .onReceive(NotificationCenter.default.publisher(for: .homeTabReselected)) { _ in
                guard showAnalyticsSheet else { return }
                showAnalyticsSheet = false
            }
        }
    }
    
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

    /// Full analytics for the selected period. A sheet rather than an inline swap, so
    /// the ledger keeps its scroll position and the period capsule stays put behind it.
    /// The category drill lives in here, since a sheet cannot present another sheet
    /// from its presenting view while it is up.
    private var analyticsSheet: some View {
        NavigationStack {
            TransactionAnalyticsContent(
                periodViewModel: periodViewModel,
                drillCategory: $drillCategory
            )
            .background { canvas.ignoresSafeArea() }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                CustomSheetCloseToolbarItem()
            }
            .sheet(item: $drillCategory) { category in
                CategoryTransactionsSheet(
                    category: category,
                    initialDate: periodViewModel.selectedDate
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
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

            Text("Add one for \(periodViewModel.periodDescription).")
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
                    .background(addBackground, in: Capsule())
                    .foregroundStyle(addForeground)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
        }
    }

    private var addButton: some View {
        Button(action: openCreateTransactionSheet) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(addForeground)
                .frame(width: 32, height: 32)
                .background(addBackground, in: Circle())
        }
        .accessibilityLabel("Add transaction")
        .accessibilityIdentifier("transactionsAddButton")
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
    TransactionsView(
        periodViewModel: TransactionViewModel(),
        voiceInline: VoiceInlineCaptureController()
    )
    .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
