//
//  UpdateTransactionSheet.swift
//  Spendrift
//
//  Color-wash editor for creating and updating transactions. Amount lives in
//  the hero so the entry is the header; category, account, time, and note sit
//  below it the way the category editor places colour and icon.
//

import SwiftUI
import SwiftData

struct UpdateTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    let transaction: Transaction?
    let draft: VoiceTransactionDraft?
    /// When opening from voice flow, explain why manual entry is needed (avoid competing `.alert`).
    let voiceReviewHint: String?
    /// When true (genuine first transaction from the empty-state CTA), the sheet pre-selects the
    /// Salary income category, the first available account, and auto-focuses the amount field so the
    /// user can type an amount and save immediately.
    let quickStartFirstTransaction: Bool
    /// Called when the user chooses voice capture from the new-transaction sheet.
    var onVoiceCreate: (() -> Void)? = nil
    var voiceCaptureDisabled: Bool = false

    /// Amounts must stay strictly below this ceiling. At or above it, Save is blocked and the
    /// stress-test alert is shown instead of writing the transaction.
    private let maxTransactionAmount: Double = 10_000_000

    @FocusState private var amountFieldFocused: Bool
    @FocusState private var notesFieldFocused: Bool

    @State private var showAmountLimitAlert = false

    @State private var notes: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var transactionType: TransactionType = .expense
    @State private var selectedAccount: Account?
    @State private var selectedCategory: TransactionCategory?

    /// Last explicitly valid category per type so switching type away and back restores the prior pick.
    @State private var categoryTracker: [TransactionType: TransactionCategory] = [:]
    @State private var showAccountPicker = false
    @State private var showCreateAccountSheet = false
    @State private var showCategoryPicker = false
    @State private var showCreateCategorySheet = false
    /// True only while `onAppear` is seeding state for an existing transaction. Setting
    /// `transactionType` there fires the type-change handler on the next update, which would
    /// otherwise substitute a default category and clobber a deliberately empty selection.
    @State private var isLoadingExistingTransaction = false

    private var categoriesSortedByLastUsed: [TransactionCategory] {
        categories.sortedByLastUsage()
    }

    private var accountsSortedByLastUsed: [Account] {
        accounts.sortedByLastUsage()
    }

    private var selectedCategoryType: CategoryType {
        CategoryType(transactionType: transactionType)
    }

    private var filteredCategories: [TransactionCategory] {
        categoriesSortedByLastUsed.filter { $0.type == selectedCategoryType }
    }

    private var isValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        guard selectedAccount != nil else { return false }
        guard let category = selectedCategory, category.type == selectedCategoryType else { return false }
        return true
    }

    private var categoryText: String {
        if filteredCategories.isEmpty {
            return "Create Category"
        }
        if let category = selectedCategory, category.type == selectedCategoryType {
            return category.name
        }
        return "Select Category"
    }

    private var accountText: String {
        if accounts.isEmpty {
            return "Create Account"
        }
        if let name = selectedAccount?.name {
            return name
        }
        return "Select Account"
    }

    private var isDark: Bool { colorScheme == .dark }

    private var accentColor: Color {
        ColoredCategories.color(for: selectedCategory)
            ?? Color(hex: CategoryPalette.defaultHex(for: selectedCategoryType))
    }

    private var heroIcon: CategoryIcon {
        if let category = selectedCategory, category.type == selectedCategoryType {
            return category.icon
        }
        return CategoryPalette.defaultIcon(for: selectedCategoryType)
    }

    private var currencySymbol: String {
        Locale.autoupdatingCurrent.currencySymbol ?? "$"
    }

    init(
        transaction: Transaction?,
        draft: VoiceTransactionDraft? = nil,
        voiceReviewHint: String? = nil,
        quickStartFirstTransaction: Bool = false,
        onVoiceCreate: (() -> Void)? = nil,
        voiceCaptureDisabled: Bool = false
    ) {
        self.transaction = transaction
        self.draft = draft
        self.voiceReviewHint = voiceReviewHint
        self.quickStartFirstTransaction = quickStartFirstTransaction
        self.onVoiceCreate = onVoiceCreate
        self.voiceCaptureDisabled = voiceCaptureDisabled
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                hero
                detailsScroll
            }
            .background(canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                }
            }
            .alert(
                "Thank you for stress testing this app, please report if anything has bugged you so far.",
                isPresented: $showAmountLimitAlert
            ) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $showAccountPicker) {
                AccountPickerSheet(
                    selectedAccount: $selectedAccount,
                    accounts: accountsSortedByLastUsed
                )
            }
            .sheet(isPresented: $showCreateAccountSheet) {
                UpdateAccountSheet(account: nil) { newAccount in
                    selectedAccount = newAccount
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(
                    selectedCategory: $selectedCategory,
                    categories: filteredCategories,
                    defaultTypeForNewCategory: selectedCategoryType,
                    accent: accentColor
                )
            }
            .sheet(isPresented: $showCreateCategorySheet) {
                UpdateCategorySheet(category: nil, defaultTypeWhenCreating: selectedCategoryType) { newCategory in
                    selectedCategory = newCategory
                }
            }
            .onAppear(perform: hydrateFromInputWithoutAnimation)
            .onChange(of: selectedCategory) { _, newValue in
                if let newValue, newValue.type == selectedCategoryType {
                    categoryTracker[transactionType] = newValue
                }
            }
            .onChange(of: transactionType) { oldType, newType in
                guard !isLoadingExistingTransaction else { return }
                if let current = selectedCategory, current.type == CategoryType(transactionType: oldType) {
                    categoryTracker[oldType] = current
                }
                applyCategoryForTransactionType(newType)
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                iconTile

                VStack(alignment: .leading, spacing: 2) {
                    amountLine
                    metaLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 8)

            typePicker
                .padding(.top, 26)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
        .background(alignment: .top) {
            ZStack(alignment: .topTrailing) {
                ColorWashBackground(color: accentColor, isDark: isDark)
                Image(systemName: heroIcon.systemImageName)
                    .font(.system(size: 160, weight: .ultraLight))
                    .foregroundStyle(heroPrimary.opacity(0.08))
                    .offset(x: 36, y: 8)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(.top, -120)
        }
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(accentColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .clear],
                                startPoint: .topLeading,
                                endPoint: UnitPoint(x: 0.55, y: 0.7)
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
                }
                .shadow(color: accentColor.opacity(0.38), radius: 16, y: 10)

            Image(systemName: heroIcon.systemImageName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(hex: "#0A0A0B"))
        }
        .frame(width: 70, height: 70)
        .accessibilityHidden(true)
        .transaction { $0.disablesAnimations = true }
    }

    private var amountLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(currencySymbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(heroPrimary.opacity(0.42))
                .accessibilityHidden(true)

            TextField("0", text: $amount)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.8)
                .monospacedDigit()
                .foregroundStyle(heroPrimary)
                .tint(heroPrimary)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .focused($amountFieldFocused)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .accessibilityIdentifier("0")
                .accessibilityLabel("Enter amount")
        }
    }

    private var metaLine: some View {
        Text(metaLineText)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(heroPrimary.opacity(0.6))
            .lineLimit(1)
    }

    private var metaLineText: String {
        if let category = selectedCategory, category.type == selectedCategoryType {
            return category.name
        }
        return transactionType.rawValue.capitalized
    }

    private var typePicker: some View {
        HStack(spacing: 3) {
            ForEach([TransactionType.income, .expense], id: \.self) { option in
                let isOn = transactionType == option
                Button {
                    transactionType = option
                    amountFieldFocused = false
                    notesFieldFocused = false
                } label: {
                    Text(option.rawValue.capitalized)
                        .font(.system(size: 13.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isOn ? typeSelectedFill : Color.clear)
                        )
                        .foregroundStyle(isOn ? typeSelectedForeground : heroPrimary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(option.rawValue.capitalized)
                .accessibilityLabel(option.rawValue.capitalized)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.black.opacity(isDark ? 0.3 : 0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Type")
    }

    // MARK: Details

    private var detailsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let voiceReviewHint, transaction == nil {
                    Text(voiceReviewHint)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 18)
                }

                VStack(spacing: 0) {
                    categoryRow
                    accountRow
                    whenRow
                    notesRow
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 44)
            .opacity(amountFieldFocused ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.2), value: amountFieldFocused)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private var categoryRow: some View {
        Button(action: openCategoryPicker) {
            TransactionMetaRow(title: "Category", showsBottomDivider: true) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)
                    Text(categoryText)
                        .foregroundStyle(heroPrimary)
                    chevron
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Category")
        .accessibilityLabel("Category")
        .accessibilityValue(categoryText)
    }

    private var accountRow: some View {
        Button(action: openAccountPicker) {
            TransactionMetaRow(title: "Account", showsBottomDivider: true) {
                HStack(spacing: 6) {
                    Text(accountText)
                        .foregroundStyle(heroPrimary)
                    chevron
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Account")
        .accessibilityLabel("Account")
        .accessibilityValue(accountText)
    }

    private var whenRow: some View {
        TransactionMetaRow(title: "When", showsBottomDivider: true) {
            HStack(spacing: 6) {
                DatePicker(
                    "Date",
                    selection: $date,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(accentColor)
                .accessibilityLabel("Date")

                DatePicker(
                    "Time",
                    selection: $date,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(accentColor)
                .accessibilityLabel("Time")
            }
        }
        .onTapGesture {
            amountFieldFocused = false
        }
    }

    private var notesRow: some View {
        TransactionMetaRow(title: "Note", showsBottomDivider: false) {
            TextField("Add notes", text: $notes, axis: .vertical)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(heroPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .focused($notesFieldFocused)
                .accessibilityIdentifier("Add notes")
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(heroPrimary.opacity(0.28))
    }

    // MARK: Chrome

    private var canvas: Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    private var saveButton: some View {
        Button(action: attemptSave) {
            Text("Save")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(saveBackground, in: Capsule())
                .foregroundStyle(saveForeground)
        }
        .buttonStyle(.plain)
    }

    private var typeSelectedFill: Color {
        isDark ? Color.white.opacity(0.9) : Color(hex: "#111111")
    }

    private var typeSelectedForeground: Color {
        isDark ? Color(hex: "#111111") : .white
    }

    private var saveBackground: Color {
        isDark ? Color.white.opacity(0.92) : Color(hex: "#111111")
    }

    private var saveForeground: Color {
        isDark ? Color(hex: "#111111") : .white
    }

    // MARK: Behaviour

    private func openCategoryPicker() {
        amountFieldFocused = false
        notesFieldFocused = false
        if filteredCategories.isEmpty {
            showCreateCategorySheet = true
        } else {
            showCategoryPicker = true
        }
    }

    private func openAccountPicker() {
        amountFieldFocused = false
        notesFieldFocused = false
        if accounts.isEmpty {
            showCreateAccountSheet = true
        } else {
            showAccountPicker = true
        }
    }

    private func attemptSave() {
        if let amountValue = Double(amount), amountValue >= maxTransactionAmount {
            showAmountLimitAlert = true
            return
        }
        saveTransaction()
    }

    private func hydrateFromInputWithoutAnimation() {
        var animationTransaction = SwiftUI.Transaction()
        animationTransaction.disablesAnimations = true
        withTransaction(animationTransaction) {
            hydrateFromInput()
        }
    }

    /// Focuses the amount field shortly after the sheet appears. The small delay lets the sheet's
    /// presentation animation settle so the keyboard reliably comes up on the amount field.
    private func focusAmountFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            amountFieldFocused = true
        }
    }

    private func hydrateFromInput() {
        isLoadingExistingTransaction = true
        if let transaction = transaction {
            notes = transaction.notes
            amount = transaction.amount.wholeAmountDisplayString
            date = transaction.date
            transactionType = transaction.transactionType
            selectedAccount = transaction.account
            // Only substitute a default category when the transaction already has one
            // whose type is inconsistent with its transaction type. An uncategorized
            // transaction stays unselected so the Category row reads "Select Category"
            // instead of implying that the last-used category is already chosen for it.
            if let existingCategory = transaction.category {
                if existingCategory.type == selectedCategoryType {
                    selectedCategory = existingCategory
                    categoryTracker[transactionType] = existingCategory
                } else {
                    let fallback = categoriesSortedByLastUsed.first { $0.type == selectedCategoryType }
                    selectedCategory = fallback
                    if let fallback {
                        categoryTracker[transactionType] = fallback
                    }
                }
            } else {
                selectedCategory = nil
            }
        } else {
            selectedAccount = draft?.account ?? accountsSortedByLastUsed.first ?? accounts.first

            if let draftType = draft?.transactionType {
                transactionType = draftType
            } else if quickStartFirstTransaction {
                // First-ever transaction defaults to logging income via the Salary category.
                transactionType = .income
            } else {
                transactionType = .expense
            }

            var category = draft?.category
            if category == nil, quickStartFirstTransaction {
                category = categoriesSortedByLastUsed.first { $0.type == .income && $0.name == "Salary" }
            }
            if category == nil {
                category = categoriesSortedByLastUsed.first { $0.type == selectedCategoryType }
            }
            if category?.type != selectedCategoryType {
                category = categoriesSortedByLastUsed.first { $0.type == selectedCategoryType }
            }
            selectedCategory = category
            if let category, category.type == selectedCategoryType {
                // Pin the tracker so the type-change handler can't override the quick-start pick.
                categoryTracker[transactionType] = category
            }
            if let draft {
                notes = draft.notes
                if let amount = draft.amount {
                    self.amount = amount.wholeAmountDisplayString
                }
            }
            if draft == nil {
                focusAmountFieldSoon()
            }
        }
        seedCategoryTrackerDefaultsForKnownTypes()
        // The transactionType assignment above triggers the type-change handler on the
        // next runloop turn; defer clearing the flag so that handler is skipped for the
        // initial load and can't overwrite the category we set here.
        DispatchQueue.main.async {
            isLoadingExistingTransaction = false
        }
    }

    /// Pre-fill tracker with first category per type so the first type switch has sensible defaults.
    private func seedCategoryTrackerDefaultsForKnownTypes() {
        for type in TransactionType.allCases {
            let categoryType = CategoryType(transactionType: type)
            if categoryTracker[type] == nil,
               let first = categoriesSortedByLastUsed.first(where: { $0.type == categoryType }) {
                categoryTracker[type] = first
            }
        }
    }

    private func applyCategoryForTransactionType(_ type: TransactionType) {
        let categoryType = CategoryType(transactionType: type)
        let list = categoriesSortedByLastUsed.filter { $0.type == categoryType }
        if let remembered = categoryTracker[type], list.contains(where: { $0.id == remembered.id }) {
            selectedCategory = remembered
        } else {
            selectedCategory = list.first
            if let first = list.first {
                categoryTracker[type] = first
            }
        }
    }

    private func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        guard selectedCategory == nil || selectedCategory?.type == selectedCategoryType else { return }

        if let transaction = transaction {
            transaction.notes = notes
            transaction.amount = amountValue
            transaction.date = date
            transaction.transactionType = transactionType
            transaction.account = selectedAccount
            transaction.category = selectedCategory
        } else {
            let newTransaction = Transaction(
                notes: notes,
                amount: amountValue,
                date: date,
                transactionType: transactionType,
                category: selectedCategory,
                account: selectedAccount,
                source: TransactionSource.manual.rawValue
            )
            modelContext.insert(newTransaction)
            Analytics.captureTransactionCreated(method: "manual", type: transactionType.rawValue)
        }

        selectedAccount?.lastUsedAt = Date()
        selectedCategory?.lastUsedAt = Date()

        try? modelContext.save()
        dismiss()
    }
}

private struct TransactionMetaRow<Trailing: View>: View {
    let title: String
    var showsBottomDivider: Bool = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            trailing()
                .font(.system(size: 14, weight: .regular))
        }
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) {
            if showsBottomDivider {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedAccount: Account?
    let accounts: [Account]

    @State private var showCreateAccountSheet = false

    private var isDark: Bool { colorScheme == .dark }

    private var canvas: Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    Button {
                        selectedAccount = account
                        dismiss()
                    } label: {
                        TransactionPickerRow(
                            title: account.name,
                            systemImage: account.icon.systemImageName,
                            tint: Color.accentColor,
                            isSelected: selectedAccount?.id == account.id
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier(account.name)
                    .accessibilityLabel(account.name)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(canvas.ignoresSafeArea())
            .navigationTitle("Select Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showCreateAccountSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateAccountSheet) {
                UpdateAccountSheet(account: nil) { newAccount in
                    selectedAccount = newAccount
                }
            }
        }
    }
}

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedCategory: TransactionCategory?
    let categories: [TransactionCategory]
    let defaultTypeForNewCategory: CategoryType
    var accent: Color = .accentColor

    @State private var showCreateCategorySheet = false
    @State private var searchText = ""

    private var isDark: Bool { colorScheme == .dark }

    private var canvas: Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    private var filteredCategories: [TransactionCategory] {
        if searchText.isEmpty { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCategories) { category in
                    let tint = ColoredCategories.color(for: category) ?? accent
                    Button {
                        selectedCategory = category
                        dismiss()
                    } label: {
                        TransactionPickerRow(
                            title: category.name,
                            systemImage: category.icon.systemImageName,
                            tint: tint,
                            isSelected: selectedCategory?.id == category.id,
                            selectedTint: tint
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        selectedCategory?.id == category.id
                            ? tint.opacity(isDark ? 0.16 : 0.10)
                            : Color.clear
                    )
                    .accessibilityIdentifier(category.name)
                    .accessibilityLabel(category.name)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(canvas.ignoresSafeArea())
            .overlay {
                if !searchText.isEmpty && filteredCategories.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search categories")
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showCreateCategorySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateCategorySheet) {
                UpdateCategorySheet(category: nil, defaultTypeWhenCreating: defaultTypeForNewCategory) { newCategory in
                    selectedCategory = newCategory
                }
            }
        }
    }
}

private struct TransactionPickerRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isSelected: Bool = false
    var selectedTint: Color = .accentColor

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 34, height: 34)

                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedTint)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview("New") {
    UpdateTransactionSheet(transaction: nil)
        .modelContainer(
            for: [Transaction.self, Account.self, TransactionCategory.self],
            inMemory: true
        )
}

#Preview("Edit") {
    UpdateTransactionSheet(
        transaction: Transaction(
            notes: "Lunch",
            amount: 420,
            transactionType: .expense
        )
    )
    .modelContainer(
        for: [Transaction.self, Account.self, TransactionCategory.self],
        inMemory: true
    )
}
