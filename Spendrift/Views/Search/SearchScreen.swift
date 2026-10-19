//
//  SearchScreen.swift
//  Spendrift
//
//  Tapping the Home search bar pushes this screen. Home keeps its scroll and its
//  tab underneath, and the active tab never influences the results: search is
//  always global. Back inside the field, nothing else in the bar.
//

import SwiftUI
import SwiftData

/// Where the Home stack can go.
enum HomeRoute: Hashable {
    case search
}

/// A result set opened in full. Carries ids rather than models so it can live in a
/// navigation path and be refetched by the screen that shows it.
struct SearchLedgerRequest: Hashable {
    let title: String
    let subtitle: String
    let transactionIDs: [UUID]
}

struct SearchScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: [
        SortDescriptor(\TransactionCategory.sortOrder),
        SortDescriptor(\TransactionCategory.name)
    ])
    private var categories: [TransactionCategory]
    @Query(sort: \Account.createdOn) private var accounts: [Account]

    /// Seed query, used by the deep links that open search with a term already typed.
    var initialQuery: String = ""

    private enum Scope: String, CaseIterable, Identifiable {
        case all, transactions, categories, accounts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "All"
            case .transactions: "Transactions"
            case .categories: "Categories"
            case .accounts: "Accounts"
            }
        }
    }

    @FocusState private var fieldFocused: Bool
    @State private var text = ""
    @State private var scope: Scope = .all
    @State private var results: SearchResults?
    @State private var expandedGroups: Set<String> = []
    @State private var recents = SearchRecents.shared
    @State private var transactionToEdit: Transaction?
    @State private var categoryToEdit: TransactionCategory?
    @State private var accountToEdit: Account?
    @State private var newCategoryName: String?
    @State private var toast: String?
    /// Set when a result set is opened in full, which pushes the ledger screen.
    @State private var ledgerRequest: SearchLedgerRequest?

    private let today = Date()

    var body: some View {
        VStack(spacing: 0) {
            header
            if let results, !text.trimmingCharacters(in: .whitespaces).isEmpty {
                scopeChips(results)
            }
            body(for: results)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.ink, in: Capsule())
                    .foregroundStyle(AppTheme.canvas)
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: toast)
        .onAppear {
            if text.isEmpty, !initialQuery.isEmpty {
                text = initialQuery
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                fieldFocused = true
            }
        }
        // Results land about 150ms after typing stops, so every keystroke does not
        // rebuild the list.
        .task(id: text) {
            let raw = text
            if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                results = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, raw == text else { return }
            runSearch()
        }
        .navigationDestination(item: $ledgerRequest) { request in
            SearchLedgerScreen(request: request)
        }
        .sheet(item: $transactionToEdit) { transaction in
            UpdateTransactionSheet(transaction: transaction)
        }
        .sheet(
            isPresented: Binding(
                get: { categoryToEdit != nil },
                set: { if !$0 { categoryToEdit = nil } }
            )
        ) {
            if let categoryToEdit {
                UpdateCategorySheet(category: categoryToEdit)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { accountToEdit != nil },
                set: { if !$0 { accountToEdit = nil } }
            )
        ) {
            if let accountToEdit {
                UpdateAccountSheet(account: accountToEdit)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { newCategoryName != nil },
                set: { if !$0 { newCategoryName = nil } }
            )
        ) {
            UpdateCategorySheet(
                category: nil,
                defaultTypeWhenCreating: .expense,
                initialNameWhenCreating: newCategoryName,
                eventSource: .search
            )
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 4) {
            Button {
                fieldFocused = false
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            TextField("", text: $text)
                .font(.system(size: 16))
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        CyclingSearchPlaceholder()
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.inkTertiary)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(CyclingSearchPlaceholder.accessibilityText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($fieldFocused)
                .tint(AppTheme.cursor)
                .onSubmit {
                    runSearch()
                    recents.remember(text)
                    fieldFocused = false
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    results = nil
                    fieldFocused = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(AppTheme.cardAlternate, in: Circle())
                        .foregroundStyle(AppTheme.inkSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .frame(height: 48)
        // The field itself is only one line tall, so the capsule behind it takes
        // every other tap. It sits underneath, so it never competes with the
        // field's own taps or the buttons.
        .background {
            Capsule()
                .fill(AppTheme.card)
                .onTapGesture { fieldFocused = true }
        }
        .overlay(Capsule().strokeBorder(AppTheme.hairline, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private func scopeChips(_ results: SearchResults) -> some View {
        let counts: [Scope: Int?] = [
            .all: nil,
            .transactions: results.all.count,
            .categories: results.entities.filter(\.isCategory).count,
            .accounts: results.entities.filter(\.isAccount).count
        ]
        let visible = Scope.allCases.filter { candidate in
            candidate == .all || (counts[candidate].flatMap { $0 } ?? 0) > 0 || scope == candidate
        }

        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(visible) { candidate in
                    let count = counts[candidate].flatMap { $0 }
                    Button {
                        scope = candidate
                    } label: {
                        HStack(spacing: 6) {
                            Text(candidate.title)
                            if let count {
                                Text("\(count)")
                                    .foregroundStyle(
                                        scope == candidate
                                            ? AppTheme.canvas.opacity(0.6)
                                            : AppTheme.inkTertiary
                                    )
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(scope == candidate ? AppTheme.ink : AppTheme.card, in: Capsule())
                        .foregroundStyle(scope == candidate ? AppTheme.canvas : AppTheme.inkSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(scope == candidate ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Body

    @ViewBuilder
    private func body(for results: SearchResults?) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                if text.trimmingCharacters(in: .whitespaces).isEmpty {
                    suggestions
                } else if let results {
                    resultsContent(results)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: Before typing

    private var suggestions: some View {
        VStack(spacing: 24) {
            if !recents.queries.isEmpty {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Recent")
                            .font(.system(size: 12, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(AppTheme.inkSecondary)
                        Spacer(minLength: 8)
                        Button("Clear") { recents.clear() }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.inkSecondary)
                    }
                    .padding(.horizontal, 4)

                    HomeCard {
                        ForEach(Array(recents.queries.enumerated()), id: \.element) { index, query in
                            if index > 0 {
                                HomeRowDivider()
                            }
                            recentRow(query)
                        }
                    }
                }
            }

            chipSection("Top categories this month", chips: topCategoryChips)
            chipSection("Frequent merchants", chips: frequentMerchantChips)
            chipSection("Shortcuts", chips: shortcutChips)
        }
    }

    private func recentRow(_ query: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.inkTertiary)
            Button {
                text = query
            } label: {
                Text(query)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                recents.remove(query)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .foregroundStyle(AppTheme.inkTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(query)")
        }
        .padding(.vertical, 12)
    }

    private func chipSection(_ title: String, chips: [SearchChip]) -> some View {
        Group {
            if !chips.isEmpty {
                VStack(spacing: 10) {
                    HomeSectionHeader(title: title)
                    FlowChips(chips: chips) { chip in
                        text = chip.query
                    }
                }
            }
        }
    }

    private var topCategoryChips: [SearchChip] {
        MonthRef.of(today)
            .stats(from: transactions, today: today)
            .categorySpend
            .prefix(3)
            .map { slice in
                SearchChip(
                    id: "cat-\(slice.category.id)",
                    title: slice.category.name,
                    query: slice.category.name,
                    symbol: slice.category.icon.systemImageName,
                    color: CategoryEnamel.color(for: slice.category)
                )
            }
    }

    private var frequentMerchantChips: [SearchChip] {
        let window = Calendar.current.date(byAdding: .day, value: -90, to: today) ?? today
        let recentTransactions = transactions.filter { $0.isPersisted && $0.date >= window }
        return LedgerSearch.merchants(in: recentTransactions)
            .prefix(3)
            .map { merchant in
                SearchChip(
                    id: "merchant-\(merchant.name.lowercased())",
                    title: merchant.name,
                    query: merchant.name,
                    symbol: "storefront",
                    color: CategoryEnamel.color(for: merchant.category)
                )
            }
    }

    private var shortcutChips: [SearchChip] {
        [
            SearchChip(id: "this-month", title: "This month", query: "this month", symbol: "calendar", color: nil),
            SearchChip(id: "last-week", title: "Last week", query: "last week", symbol: "calendar", color: nil),
            SearchChip(
                id: "over",
                title: "Over \(1000.0.formatCurrencyRounded)",
                query: "over 1000",
                symbol: "chart.line.uptrend.xyaxis",
                color: nil
            )
        ]
    }

    // MARK: Results

    @ViewBuilder
    private func resultsContent(_ results: SearchResults) -> some View {
        if !results.query.filters.isEmpty {
            filterPills(results.query)
        }

        if results.isEmpty {
            noResults(results.query)
        } else if results.isAmountSearch {
            amountSections(results)
        } else {
            switch scope {
            case .all:
                allScope(results)
            case .transactions:
                if results.all.isEmpty {
                    noResults(results.query)
                } else {
                    SearchTransactionSection(
                        title: "Transactions",
                        transactions: results.all,
                        tokens: results.query.tokens,
                        limit: 20,
                        onOpen: open(transaction:),
                        onSeeAll: { push(title: "Transactions", results.all) }
                    )
                }
            case .categories, .accounts:
                entityScope(results)
            }
        }
    }

    @ViewBuilder
    private func allScope(_ results: SearchResults) -> some View {
        if let top = results.top {
            SearchTopHitCard(
                entity: top,
                filterSummary: results.query.filters.map(\.label).joined(separator: ", "),
                allTransactions: allTransactions(of: top),
                today: today,
                onOpen: { open(entity: top) }
            )

            if !results.folded.isEmpty {
                SearchTransactionSection(
                    title: "In \(top.name)",
                    transactions: results.folded,
                    tokens: results.query.tokens,
                    onOpen: open(transaction:),
                    onSeeAll: { push(title: top.name, results.folded) }
                )
            }
        }

        entityGroup("Categories", results.categories, key: "categories", tokens: results.query.tokens)
        entityGroup("Merchants", results.merchants, key: "merchants", tokens: results.query.tokens)
        entityGroup("Accounts", results.accounts, key: "accounts", tokens: results.query.tokens)

        if !results.rest.isEmpty {
            SearchTransactionSection(
                title: results.top.map { "Also mentions “\($0.name.lowercased())”" } ?? "Transactions",
                transactions: results.rest,
                tokens: results.query.tokens,
                moveTarget: results.top?.moveTarget,
                onOpen: open(transaction:),
                onMove: move(transaction:to:),
                onSeeAll: { push(title: "Transactions", results.rest) }
            )
        }
    }

    @ViewBuilder
    private func entityScope(_ results: SearchResults) -> some View {
        let wanted = results.entities.filter { scope == .categories ? $0.isCategory : $0.isAccount }
        if wanted.isEmpty {
            noResults(results.query)
        } else {
            HomeCard {
                ForEach(Array(wanted.enumerated()), id: \.element.id) { index, entity in
                    if index > 0 {
                        HomeRowDivider()
                    }
                    SearchEntityRow(entity: entity, tokens: results.query.tokens) {
                        open(entity: entity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func amountSections(_ results: SearchResults) -> some View {
        let amount = results.query.amount ?? 0
        if !results.exactAmount.isEmpty {
            SearchTransactionSection(
                title: "Exactly \(amount.formatCurrencyRounded)",
                transactions: results.exactAmount,
                tokens: [],
                onOpen: open(transaction:),
                onSeeAll: { push(title: "Exactly \(amount.formatCurrencyRounded)", results.exactAmount) }
            )
        }
        if !results.closeToAmount.isEmpty {
            SearchTransactionSection(
                title: "Close to \(amount.formatCurrencyRounded)",
                transactions: results.closeToAmount,
                tokens: [],
                onOpen: open(transaction:),
                onSeeAll: { push(title: "Close to \(amount.formatCurrencyRounded)", results.closeToAmount) }
            )
        }
    }

    @ViewBuilder
    private func entityGroup(
        _ title: String,
        _ entities: [SearchEntity],
        key: String,
        tokens: [String]
    ) -> some View {
        if !entities.isEmpty {
            let isExpanded = expandedGroups.contains(key)
            let shown = isExpanded ? entities : Array(entities.prefix(3))

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(AppTheme.inkSecondary)
                    Spacer(minLength: 8)
                    if entities.count > 3 {
                        Button(isExpanded ? "Show less" : "See all \(entities.count)") {
                            if isExpanded {
                                expandedGroups.remove(key)
                            } else {
                                expandedGroups.insert(key)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.inkSecondary)
                    }
                }
                .padding(.horizontal, 4)

                HomeCard {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, entity in
                        if index > 0 {
                            HomeRowDivider()
                        }
                        SearchEntityRow(entity: entity, tokens: tokens) {
                            open(entity: entity)
                        }
                    }
                }
            }
        }
    }

    private func filterPills(_ query: SearchQuery) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(query.filters) { filter in
                Button {
                    remove(filter)
                } label: {
                    HStack(spacing: 6) {
                        Text(filter.label)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.inkSecondary)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .frame(height: 30)
                    .background {
                        ZStack {
                            Capsule().fill(AppTheme.card)
                            Capsule().fill(AppTheme.atmosphere.opacity(0.14))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove filter \(filter.label)")
            }
        }
    }

    private func noResults(_ query: SearchQuery) -> some View {
        VStack(spacing: 10) {
            EnamelBadge(
                systemImage: "magnifyingglass",
                color: CategoryEnamel.uncategorized,
                side: 64,
                showsShadow: true
            )
            Text("No results for “\(query.raw)”")
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 6)
            Text(
                query.filters.contains(where: \.isDate)
                    ? "Nothing in that date range. Try all dates."
                    : "Check the spelling, or try a merchant, amount or month."
            )
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.inkSecondary)
            .multilineTextAlignment(.center)

            if let dateFilter = query.filters.first(where: \.isDate) {
                Button("Search all dates") { remove(dateFilter) }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(AppTheme.actionBackground, in: Capsule())
                    .foregroundStyle(AppTheme.actionForeground)
                    .padding(.top, 10)
            } else if !query.tokens.isEmpty {
                let name = query.tokens.joined(separator: " ").capitalized
                Button("Add “\(name)” as a category") { newCategoryName = name }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(AppTheme.actionBackground, in: Capsule())
                    .foregroundStyle(AppTheme.actionForeground)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.horizontal, 20)
    }

    // MARK: Behaviour

    private func runSearch() {
        let query = LedgerSearch.parse(text, today: today)
        results = LedgerSearch.run(
            query: query,
            transactions: transactions,
            categories: categories,
            accounts: accounts,
            today: today
        )
    }

    private func allTransactions(of entity: SearchEntity) -> [Transaction] {
        transactions.filter { $0.isPersisted && entity.owns($0) }
    }

    private func open(transaction: Transaction) {
        recents.remember(text)
        transactionToEdit = transaction
    }

    private func open(entity: SearchEntity) {
        recents.remember(text)
        switch entity.kind {
        case .category(let category):
            categoryToEdit = category
        case .account(let account):
            accountToEdit = account
        case .merchant(let name, _):
            push(title: name, allTransactions(of: entity))
        }
    }

    private func move(transaction: Transaction, to category: TransactionCategory) {
        transaction.category = category
        transaction.transactionType = TransactionType(categoryType: category.type)
        category.lastUsedAt = Date()
        try? modelContext.save()
        runSearch()
        showToast("Moved to \(category.name)")
    }

    /// Takes the words a pill stands for back out of the field.
    private func remove(_ filter: SearchFilter) {
        let stripped = text.replacingOccurrences(
            of: filter.matchedText,
            with: " ",
            options: [.caseInsensitive]
        )
        text = stripped.trimmingCharacters(in: .whitespaces)
    }

    private func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            toast = nil
        }
    }

    private func push(title: String, _ list: [Transaction]) {
        recents.remember(text)
        ledgerRequest = SearchLedgerRequest(
            title: title,
            subtitle: "\(list.count) transaction\(list.count == 1 ? "" : "s")",
            transactionIDs: list.map(\.id)
        )
    }
}

/// A suggestion chip on the empty search screen.
struct SearchChip: Identifiable {
    let id: String
    let title: String
    let query: String
    let symbol: String
    /// Nil for the plain shortcut chips, which carry no entity colour.
    let color: Color?
}

/// Wrapping row of suggestion chips.
struct FlowChips: View {
    let chips: [SearchChip]
    let onTap: (SearchChip) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(chips) { chip in
                Button {
                    onTap(chip)
                } label: {
                    HStack(spacing: 8) {
                        if let color = chip.color {
                            EnamelBadge(systemImage: chip.symbol, color: color, side: 26)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: chip.symbol)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.inkSecondary)
                        }
                        Text(chip.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(chip.color == nil ? AppTheme.inkSecondary : AppTheme.ink)
                    }
                    .padding(.leading, chip.color == nil ? 14 : 6)
                    .padding(.trailing, 14)
                    .frame(height: 38)
                    .background(AppTheme.card, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Left-aligned wrapping layout for chips and filter pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var total = CGSize(width: 0, height: 0)

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                total.width = max(total.width, rowWidth)
                total.height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth > 0 ? spacing + size.width : size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        total.width = max(total.width, rowWidth)
        total.height += rowHeight
        // Take the whole offered width. Reporting only the widest row lets the
        // centring stacks above centre each block of chips on its own width, so
        // no two blocks lined up with each other or with the headers.
        if let width = proposal.width, width.isFinite {
            total.width = width
        }
        return total
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
