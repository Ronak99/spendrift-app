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

/// What the add-budget sheet asked for, carried out once it has dismissed.
private enum PendingBudgetAction {
    case edit(TransactionCategory)
    case create
}

extension CategoryType: Identifiable {
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

    @State private var createTransactionSheet: CreateTransactionSheetMode?
    @State private var transactionToEdit: Transaction?
    @State private var showCreateAccount = false
    @State private var accountToEdit: Account?
    /// Type of the category being created, or nil when the create sheet is closed.
    @State private var newCategoryType: CategoryType?
    @State private var categoryEdit: CategoryEditRequest?
    @State private var monthPicker: MonthPickerTarget?
    @State private var showTypePicker = false
    @State private var showTotalBudgetSheet = false
    @State private var showAddBudgetSheet = false
    /// What the add-budget sheet asked for: edit a category's cap, or create one. The
    /// editor opens only once that sheet has fully dismissed, since presenting a
    /// second sheet while the first is still leaving can strand the presentation.
    @State private var pendingBudgetAction: PendingBudgetAction?
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
    /// Screen top to the bottom of the tab strip. The wash is this tall on every tab.
    @State private var atmosphereHeight: CGFloat = 0

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
        .sheet(item: $newCategoryType) { type in
            UpdateCategorySheet(category: nil, defaultTypeWhenCreating: type)
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
        .sheet(isPresented: $showAddBudgetSheet, onDismiss: openPendingBudgetEditor) {
            AddCategoryBudgetSheet(
                onPick: { pendingBudgetAction = .edit($0) },
                onCreate: { pendingBudgetAction = .create }
            )
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
        pane
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .softScrollEdge()
            .scrollingHeaderBar { header }
            .background(alignment: .top) {
                // Height is the tab strip's bottom edge. Same on every tab.
                // A flexible wash was filling the screen and showing through Accounts'
                // clear ledger row. Home and Transactions hid it behind opaque rows.
                ColorWashBackground(color: AppTheme.atmosphere, isDark: isDark)
                    .frame(height: atmosphereHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
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

    /// Title, search and tab strip. The header has no fill of its own: it rides as a
    /// bar over the pane, so at rest it shows the wash behind it, and the pane scrolls
    /// beneath it under the soft scroll-edge blur that keeps it readable.
    private var header: some View {
        VStack(spacing: 0) {
            HomeTitleBar(title: selectedTab.title) { showSettings = true }

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
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.frame(in: .global).maxY }) { bottom in
            guard bottom > 0, bottom != atmosphereHeight else { return }
            atmosphereHeight = bottom
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
                onEditCategoryBudget: { categoryEdit = CategoryEditRequest(category: $0, focusBudget: true) },
                onOpenTransaction: { transactionToEdit = $0 },
                onOpenTab: { selectedTab = $0 },
                onAddTransaction: openCreateTransactionSheet,
                onOpenAnalytics: openAnalytics
            )
        case .transactions:
            TransactionsPane(
                transactions: transactions,
                month: ledgerMonth,
                today: today,
                onOpenTransaction: { transactionToEdit = $0 },
                onAddTransaction: openCreateTransactionSheet,
                onDelete: delete(transaction:)
            )
        case .accounts:
            AccountsPane(
                accounts: accounts,
                transactions: transactions,
                onOpenAccount: { accountToEdit = $0 },
                onCreateAccount: { showCreateAccount = true },
                onDelete: delete(account:)
            )
        case .categories:
            CategoriesPane(
                categories: categories,
                type: categoryType,
                month: MonthRef.of(today).stats(from: transactions, today: today),
                onOpenCategory: { categoryEdit = CategoryEditRequest(category: $0) },
                onCreateCategory: { newCategoryType = categoryType },
                onDelete: { categoryToDelete = $0 }
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

    /// Runs from the add-budget sheet's `onDismiss`, after its transition has finished.
    private func openPendingBudgetEditor() {
        guard let action = pendingBudgetAction else { return }
        pendingBudgetAction = nil
        switch action {
        case .edit(let category):
            categoryEdit = CategoryEditRequest(category: category, focusBudget: true)
        case .create:
            // Budgets only cap spending, so the new category starts as an expense.
            newCategoryType = .expense
        }
    }

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

