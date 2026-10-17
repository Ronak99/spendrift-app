//
//  HomeShellView.swift
//  Spendrift
//
//  The app's one screen. The editor heroes' blue atmosphere behind the title, a
//  search bar and a tab strip that pin together, four panes that each own the
//  bottom with the only control that creates a transaction.
//

import SwiftUI
import SwiftData
import UIKit

/// Drives the manual create-transaction sheet so quick-start mode is chosen atomically
/// with presentation.
enum CreateTransactionSheetMode: Identifiable {
    case standard
    case quickStartFirst

    var id: Self { self }

    var quickStartFirstTransaction: Bool { self == .quickStartFirst }
}

/// Which screen's month the picker is about to change.
private enum MonthPickerTarget: Identifiable {
    case home
    case ledger

    var id: Self { self }
}

/// A category editor opened with a reason, so the budget field can take focus.
private struct CategoryEditRequest: Identifiable {
    let category: TransactionCategory
    var focusBudget = false

    var id: UUID { category.id }
}

struct HomeShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppRouter.self) private var router
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: [
        SortDescriptor(\TransactionCategory.sortOrder),
        SortDescriptor(\TransactionCategory.name)
    ])
    private var categories: [TransactionCategory]
    @AppStorage(MonthlyBudget.totalKey) private var totalBudget: Double = 0
    @AppStorage("didFireFirstTransactionCreated") private var hasEverCreatedTransaction = false

    /// Shared with `ContentView` so a capture started from a shortcut is the one this
    /// screen renders.
    var voiceInline: VoiceInlineCaptureController
    let receiptImport: ReceiptSharePayload?
    @Binding var messageInboxBanner: MessageInboxImportBanner?

    @State private var selectedTab: HomeTab = .all
    @State private var path: [HomeRoute] = []
    @State private var homeMonth = MonthRef.of(Date())
    @State private var ledgerMonth = MonthRef.of(Date())
    @State private var categoryType: CategoryType = .expense
    @State private var isTrayOpen = false
    /// True once the visible pane has scrolled enough to put the title row away.
    @State private var isTitleCollapsed = false

    @State private var createTransactionSheet: CreateTransactionSheetMode?
    @State private var transactionToEdit: Transaction?
    @State private var showCreateAccount = false
    @State private var accountToEdit: Account?
    @State private var showCreateCategory = false
    @State private var categoryEdit: CategoryEditRequest?
    @State private var monthPicker: MonthPickerTarget?
    @State private var showTypePicker = false
    @State private var showTotalBudgetSheet = false
    @State private var showAddBudgetSheet = false
    @State private var showSettings = false
    @State private var showStatementImport = false
    @State private var showReceiptCamera = false
    @State private var showReceiptLibrary = false
    @State private var showLastAccountAlert = false
    @State private var categoryToDelete: TransactionCategory?
    @State private var showAnalyticsSheet = false
    @State private var analyticsDrillCategory: TransactionCategory?
    /// Scopes the full analytics screen. Re-anchored to the month Home is showing
    /// whenever that screen is opened.
    @State private var analyticsPeriod = TransactionViewModel()
    @State private var paywallContext: PaywallContext?
    @State private var receiptShare = ReceiptCaptureController()
    /// Drives the transient "Transaction added" confirmation after a shared receipt is created.
    @State private var showReceiptShareCreated = false
    /// Ids of the trigger payloads already handled, so a task that restarts does not
    /// reprocess a consumed file.
    @State private var lastProcessedReceiptImportID: UUID?

    private let today = Date()

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationStack(path: $path) {
            shell
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .search:
                        SearchScreen()
                    }
                }
        }
        .environment(\.openSettings) { showSettings = true }
        .proPaywall($paywallContext)
        .modifier(HomeCaptureSheets(
            showStatementImport: $showStatementImport,
            showReceiptCamera: $showReceiptCamera,
            showReceiptLibrary: $showReceiptLibrary,
            receiptShare: receiptShare,
            paywallContext: $paywallContext,
            onProcessImage: processReceiptImage
        ))
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $createTransactionSheet) { mode in
            UpdateTransactionSheet(
                transaction: nil,
                quickStartFirstTransaction: mode.quickStartFirstTransaction,
                onVoiceCreate: startVoiceQuickAdd,
                voiceCaptureDisabled: voiceInline.blocksNewCapture
            )
        }
        .sheet(item: $transactionToEdit) { transaction in
            UpdateTransactionSheet(transaction: transaction)
        }
        .sheet(isPresented: $showCreateAccount) {
            UpdateAccountSheet(account: nil)
        }
        .sheet(item: $accountToEdit) { account in
            UpdateAccountSheet(account: account)
        }
        .sheet(isPresented: $showCreateCategory) {
            UpdateCategorySheet(category: nil, defaultTypeWhenCreating: categoryType)
        }
        .sheet(item: $categoryEdit) { request in
            UpdateCategorySheet(category: request.category, focusBudgetWhenOpening: request.focusBudget)
        }
        .sheet(item: $monthPicker) { target in
            MonthYearPickerSheet(
                selection: target == .home ? homeMonth : ledgerMonth,
                earliestYear: earliestYear,
                today: today
            ) { picked in
                switch target {
                case .home: homeMonth = picked
                case .ledger: ledgerMonth = picked
                }
            }
        }
        .sheet(isPresented: $showTypePicker) {
            CategoryTypePickerSheet(selection: categoryType) { picked in
                categoryType = picked
            }
        }
        .sheet(isPresented: $showAnalyticsSheet) {
            analyticsSheet
        }
        .sheet(isPresented: $showTotalBudgetSheet) {
            TotalBudgetSheet()
        }
        .sheet(isPresented: $showAddBudgetSheet) {
            AddCategoryBudgetSheet { category in
                categoryEdit = CategoryEditRequest(category: category, focusBudget: true)
            }
        }
        .alert("Keep at least one account", isPresented: $showLastAccountAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Spendrift records transactions against an account. Add another one before deleting this.")
        }
        .confirmationDialog(
            "Delete “\(categoryToDelete?.name ?? "")”?",
            isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: categoryToDelete
        ) { category in
            Button("Delete Category and Its Transactions", role: .destructive) {
                delete(category)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Deleting a category also deletes all transactions assigned to it.")
        }
        .task(id: receiptImport?.id) {
            guard let payload = receiptImport, lastProcessedReceiptImportID != payload.id else { return }
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
        // A capture can be started from a shortcut while the create sheet is open; close
        // it so the recording bar is not hidden behind it.
        .onChange(of: voiceInline.displayState) { _, state in
            guard state == .recording || state == .processing else { return }
            createTransactionSheet = nil
        }
        .onChange(of: selectedTab) { _, tab in
            // Each pane owns its scroll, and a fresh one starts at the top: the title
            // row comes back with it.
            isTitleCollapsed = false
            Analytics.capture(.screenViewed, [Analytics.Key.tab: tab.eventName])
            Diagnostics.breadcrumb(
                category: .navigation,
                message: "tab_changed",
                data: [Diagnostics.Tag.tab: tab.eventName]
            )
        }
        .onAppear { healPrimaryAccount() }
        .onReceive(NotificationCenter.default.publisher(for: .settingsRequested)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .createTransactionRequested)) { _ in
            selectedTab = .all
            openCreateTransactionSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .statementImportRequested)) { _ in
            showStatementImport = true
        }
    }

    // MARK: Shell

    private var shell: some View {
        VStack(spacing: 0) {
            header
            pane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) { tray }
        .overlay { trayScrim }
        .overlay(alignment: .bottom) { trayMenu }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isTrayOpen)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: voiceInline.displayState)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: receiptShare.isProcessing)
    }

    /// Title, search and tab strip. The header sits above the pane rather than inside
    /// it, so the status bar always wears the wash and nothing can scroll out from
    /// under it. Only the title row collapses, and it does so with the scroll.
    private var header: some View {
        VStack(spacing: 0) {
            HomeTitleBar(title: selectedTab.title) { showSettings = true }
                .frame(height: titleRowHeight, alignment: .bottom)
                .opacity(titleRowOpacity)
                .clipped()
                .accessibilityHidden(titleRowOpacity < 0.1)

            HomeSearchBar { path.append(.search) }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 14)

            HomeTabStrip(
                selected: selectedTab,
                monthLabel: ledgerMonth.shortTitle,
                typeLabel: categoryType.displayName,
                onSelect: { selectedTab = $0 },
                onReselect: { tab in
                    switch tab {
                    case .transactions: monthPicker = .ledger
                    case .categories: showTypePicker = true
                    case .all, .accounts: break
                    }
                }
            )

            if selectedTab == .accounts {
                AccountLedgerSummary(accounts: accounts, transactions: transactions)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
            }
        }
        .background(alignment: .top) {
            // Same atmosphere as the editor heroes (`ColorWashBackground`): a top-down
            // tint fading to the canvas, with a radial bloom anchored top-right. Extends
            // under the status bar so that strip wears it too, instead of staying canvas.
            ColorWashBackground(color: AppTheme.atmosphere, isDark: isDark)
                .ignoresSafeArea(edges: .top)
        }
    }

    private var titleRowHeight: CGFloat { isTitleCollapsed ? 0 : Self.titleHeight }

    private var titleRowOpacity: Double { isTitleCollapsed ? 0 : 1 }

    private static let titleHeight: CGFloat = 56
    /// Hysteresis: the title leaves after this much scroll and only comes back near
    /// the top, so a pane whose viewport grows by the collapse cannot flap.
    private static let collapseThreshold: CGFloat = 16
    private static let expandThreshold: CGFloat = 4

    /// Collapses or restores the title row for the pane's scroll position.
    private func syncTitleRow(offset: CGFloat) {
        let shouldCollapse: Bool
        if isTitleCollapsed {
            shouldCollapse = offset > Self.expandThreshold
        } else {
            shouldCollapse = offset > Self.collapseThreshold
        }
        guard shouldCollapse != isTitleCollapsed else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            isTitleCollapsed = shouldCollapse
        }
    }

    @ViewBuilder
    private var pane: some View {
        switch selectedTab {
        case .all:
            HomeAnalyticsPane(
                transactions: transactions,
                categories: categories,
                month: $homeMonth,
                totalBudget: totalBudget,
                today: today,
                onPickMonth: { monthPicker = .home },
                onEditTotalBudget: { showTotalBudgetSheet = true },
                onAddCategoryBudget: { showAddBudgetSheet = true },
                onOpenCategory: { categoryEdit = CategoryEditRequest(category: $0) },
                onOpenTransaction: { transactionToEdit = $0 },
                onOpenTab: { selectedTab = $0 },
                onAddTransaction: openCreateTransactionSheet,
                onOpenAnalytics: openAnalytics,
                onScroll: syncTitleRow(offset:)
            )
        case .transactions:
            TransactionsPane(
                transactions: transactions,
                month: ledgerMonth,
                today: today,
                onOpenTransaction: { transactionToEdit = $0 },
                onAddTransaction: openCreateTransactionSheet,
                onDelete: delete(transaction:),
                onScroll: syncTitleRow(offset:)
            )
        case .accounts:
            AccountsPane(
                accounts: accounts,
                transactions: transactions,
                onOpenAccount: { accountToEdit = $0 },
                onCreateAccount: { showCreateAccount = true },
                onDelete: delete(account:),
                onScroll: syncTitleRow(offset:)
            )
        case .categories:
            CategoriesPane(
                categories: categories,
                type: categoryType,
                month: MonthRef.of(today).stats(from: transactions, today: today),
                onOpenCategory: { categoryEdit = CategoryEditRequest(category: $0) },
                onCreateCategory: { showCreateCategory = true },
                onDelete: { categoryToDelete = $0 },
                onScroll: syncTitleRow(offset:)
            )
        }
    }

    // MARK: Tray

    private var tray: some View {
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

            ReceiptShareStatusBar(status: showReceiptShareCreated ? .created : .hidden)

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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VoiceInlineRecordingBar(
                    controller: voiceInline,
                    accounts: accounts,
                    categories: categories.sortedByLastUsage()
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HomeBottomTray(
                isMenuOpen: $isTrayOpen,
                voiceDisabled: voiceInline.blocksNewCapture,
                onAddTransaction: openCreateTransactionSheet,
                onSpeak: startVoiceQuickAdd
            )
        }
    }

    @ViewBuilder
    private var trayScrim: some View {
        if isTrayOpen {
            Button {
                isTrayOpen = false
            } label: {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close menu")
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var trayMenu: some View {
        if isTrayOpen {
            CaptureTrayMenu(
                onScanReceipt: {
                    isTrayOpen = false
                    ProAccess.attempt(.receiptScan, paywall: $paywallContext) {
                        showReceiptCamera = true
                    }
                },
                onImportStatement: {
                    isTrayOpen = false
                    ProAccess.attempt(.statementImport, paywall: $paywallContext) {
                        showStatementImport = true
                    }
                },
                onBankSMS: {
                    isTrayOpen = false
                    router.settingsPath = [.bankSMS]
                    showSettings = true
                }
            )
            .padding(.bottom, 96)
            .transition(.scale(scale: 0.5, anchor: .bottomLeading).combined(with: .opacity))
        }
    }

    /// Full analytics for the month Home is showing. A sheet rather than a pane, so
    /// Home keeps its scroll behind it. The category drill lives in here, since a
    /// presenting view cannot raise a second sheet while this one is up.
    private var analyticsSheet: some View {
        NavigationStack {
            TransactionAnalyticsContent(
                periodViewModel: analyticsPeriod,
                drillCategory: $analyticsDrillCategory
            )
            .background {
                // The analytics palette is dark-only, so the sheet pins dark appearance below.
                AnalyticsAtmosphere()
                    .ignoresSafeArea()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { CustomSheetCloseToolbarItem() }
            .sheet(item: $analyticsDrillCategory) { category in
                CategoryTransactionsSheet(
                    category: category,
                    initialDate: analyticsPeriod.selectedDate
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Behaviour

    private func openAnalytics() {
        analyticsPeriod.periodGranularity = .month
        analyticsPeriod.selectedDate = Calendar.current.date(
            from: DateComponents(year: homeMonth.year, month: homeMonth.month, day: 1)
        ) ?? today
        showAnalyticsSheet = true
        AudienceTags.markSeenAnalytics()
    }

    private var earliestYear: Int {
        transactions.last(where: \.isPersisted)?.date.year ?? today.year
    }

    private func openCreateTransactionSheet() {
        isTrayOpen = false
        createTransactionSheet = hasEverCreatedTransaction ? .standard : .quickStartFirst
    }

    /// Starts an in-app voice quick-add and records the entry point.
    private func startVoiceQuickAdd() {
        guard !voiceInline.blocksNewCapture else { return }
        isTrayOpen = false
        ProAccess.attempt(.voice, paywall: $paywallContext) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Analytics.capture(.shortcutUsed, [
                Analytics.Key.kind: "voice",
                Analytics.Key.source: "home_tray"
            ])
            voiceInline.beginCapture()
        }
    }

    private func dismissBanner() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            messageInboxBanner = nil
        }
    }

    private func processReceiptImage(_ image: UIImage) {
        receiptShare.process(
            image: image,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )
    }

    /// A ledger can lose its star to an older build or a restored backup. Hand it to
    /// an account on open so Voice and Shortcuts always have a target.
    private func healPrimaryAccount() {
        guard accounts.normalizePrimary() else { return }
        try? modelContext.save()
    }

    private func delete(transaction: Transaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }

    private func delete(account: Account) {
        guard accounts.count > 1 else {
            showLastAccountAlert = true
            return
        }
        Analytics.capture(.accountDeleted, [Analytics.Key.name: account.name])
        let survivors = accounts.filter { $0.id != account.id }
        modelContext.delete(account)
        // Deleting the primary passes the star to an account that is left.
        survivors.normalizePrimary()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }

    private func delete(_ category: TransactionCategory) {
        guard !category.isDefault else { return }
        Analytics.capture(.categoryDeleted, [
            Analytics.Key.name: category.name,
            Analytics.Key.isDefault: false,
            Analytics.Key.source: CategoryEventSource.manual.rawValue
        ])
        modelContext.delete(category)
        try? modelContext.save()
        categoryToDelete = nil
    }
}

/// Receipt and statement capture presentation, grouped so the shell's body stays readable.
private struct HomeCaptureSheets: ViewModifier {
    @Binding var showStatementImport: Bool
    @Binding var showReceiptCamera: Bool
    @Binding var showReceiptLibrary: Bool
    var receiptShare: ReceiptCaptureController
    @Binding var paywallContext: PaywallContext?
    let onProcessImage: (UIImage) -> Void

    func body(content: Content) -> some View {
        @Bindable var receiptShare = receiptShare

        return content
            .sheet(isPresented: $showStatementImport) {
                StatementImportView()
            }
            .fullScreenCover(isPresented: $showReceiptCamera) {
                ReceiptCameraPicker { image in
                    showReceiptCamera = false
                    if let image { onProcessImage(image) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showReceiptLibrary) {
                PhotoLibraryPicker { image in
                    showReceiptLibrary = false
                    if let image { onProcessImage(image) }
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
    }
}
