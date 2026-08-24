//
//  UpdateTransactionSheet.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

struct UpdateTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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

    @FocusState private var amountFieldFocused: Bool

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
    
    private var categoriesSortedByLastUsed: [TransactionCategory] {
        categories.sortedByLastUsage()
    }

    private var accountsSortedByLastUsed: [Account] {
        accounts.sortedByLastUsage()
    }

    private var filteredCategories: [TransactionCategory] {
        categoriesSortedByLastUsed.filter { $0.type.rawValue == transactionType.rawValue }
    }
    
    private var isValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        guard selectedAccount != nil else { return false }
        guard let category = selectedCategory, category.type == transactionType else { return false }
        return true
    }
    
    private var categoryText: String {
        if filteredCategories.isEmpty {
            return "Create Category"
        }
        if let category = selectedCategory, category.type == transactionType {
            return category.name
        }
        return filteredCategories.first?.name ?? "Select Category"
    }
    
    private var accountText : String {
        if accounts.isEmpty {
            return "Create Account"
        } else {
            if selectedAccount?.name != nil {
                return selectedAccount!.name
            } else {
                return "Select Account"
            }
        }
    }
    
    init(
        transaction: Transaction?,
        draft: VoiceTransactionDraft? = nil,
        voiceReviewHint: String? = nil,
        quickStartFirstTransaction: Bool = false
    ) {
        self.transaction = transaction
        self.draft = draft
        self.voiceReviewHint = voiceReviewHint
        self.quickStartFirstTransaction = quickStartFirstTransaction
    }

    var body: some View {
        NavigationStack {
            Form {
                if let voiceReviewHint, transaction == nil {
                    Section {
                        Text(voiceReviewHint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("Type", selection: $transactionType) {
                    ForEach(
                        TransactionType.allCases.filter { $0 != .none
                        },
                        id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                }
                .pickerStyle(.palette)
                
                    
                Button(action: {
                    if accounts.isEmpty {
                        showCreateAccountSheet = true
                    } else {
                        showAccountPicker = true
                    }
                }) {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(accountText)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                
                Button(action: {
                    if filteredCategories.isEmpty {
                        showCreateCategorySheet = true
                    } else {
                        showCategoryPicker = true
                    }
                }) {
                    HStack {
                        Text("Category")
                        Spacer()
                        Text(categoryText)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                
                DatePicker(
                    "Date",
                    selection: $date,
                    displayedComponents: [.date, .hourAndMinute]
                ).tint(.accentColor)
                
                
                
                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("0", text: $amount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($amountFieldFocused)
                }
                
                
                Section("Notes") {
                    TextField("Add notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(
                transaction == nil ? "New Transaction" : "Edit Transaction"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissToolbarButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .disabled(!isValid)
                }
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
                    defaultTypeForNewCategory: transactionType
                )
            }
            .sheet(isPresented: $showCreateCategorySheet) {
                UpdateCategorySheet(category: nil, defaultTypeWhenCreating: transactionType) { newCategory in
                    selectedCategory = newCategory
                }
            }
            .onAppear {
                if let transaction = transaction {
                    notes = transaction.notes
                    amount = transaction.amount.wholeAmountDisplayString
                    date = transaction.date
                    transactionType = transaction.transactionType
                    selectedAccount = transaction.account
                    var category = transaction.category
                    if category?.type != transactionType {
                        category = categoriesSortedByLastUsed.first { $0.type == transactionType }
                    }
                    selectedCategory = category
                    if let category, category.type == transactionType {
                        categoryTracker[transactionType] = category
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
                        category = categoriesSortedByLastUsed.first { $0.type == transactionType }
                    }
                    if category?.type != transactionType {
                        category = categoriesSortedByLastUsed.first { $0.type == transactionType }
                    }
                    selectedCategory = category
                    if let category, category.type == transactionType {
                        // Pin the tracker so the type-change handler can't override the quick-start pick.
                        categoryTracker[transactionType] = category
                    }
                    if let draft {
                        notes = draft.notes
                        if let amount = draft.amount {
                            self.amount = amount.wholeAmountDisplayString
                        }
                    }
                    if quickStartFirstTransaction {
                        focusAmountFieldSoon()
                    }
                }
                seedCategoryTrackerDefaultsForKnownTypes()
            }
            .onChange(of: selectedCategory) { _, newValue in
                if let newValue, newValue.type == transactionType {
                    categoryTracker[transactionType] = newValue
                }
            }
            .onChange(of: transactionType) { oldType, newType in
                guard newType != .none else { return }
                if let current = selectedCategory, current.type == oldType {
                    categoryTracker[oldType] = current
                }
                applyCategoryForTransactionType(newType)
            }
        }
    }

    /// Focuses the amount field shortly after the sheet appears. The small delay lets the sheet's
    /// presentation animation settle so the keyboard reliably comes up on the amount field.
    private func focusAmountFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            amountFieldFocused = true
        }
    }

    /// Pre-fill tracker with first category per type so the first type switch has sensible defaults.
    private func seedCategoryTrackerDefaultsForKnownTypes() {
        for type in [TransactionType.expense, .income] {
            if categoryTracker[type] == nil,
               let first = categoriesSortedByLastUsed.first(where: { $0.type == type }) {
                categoryTracker[type] = first
            }
        }
    }

    private func applyCategoryForTransactionType(_ type: TransactionType) {
        let list = categoriesSortedByLastUsed.filter { $0.type == type }
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
        guard selectedCategory == nil || selectedCategory?.type == transactionType else { return }

        if let transaction = transaction {
            // Update existing
            transaction.notes = notes
            transaction.amount = amountValue
            transaction.date = date
            transaction.transactionType = transactionType
            transaction.account = selectedAccount
            transaction.category = selectedCategory
        } else {
            // Create new
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

struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAccount: Account?
    let accounts: [Account]
    
    @State private var showCreateAccountSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    Button(action: {
                        selectedAccount = account
                        dismiss()
                    }) {
                        HStack {
                            Text(account.name)
                            Spacer()
                            if selectedAccount?.id == account.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
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
//                    dismiss()
                }
            }
        }
    }
}

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: TransactionCategory?
    let categories: [TransactionCategory]
    let defaultTypeForNewCategory: TransactionType
    
    @State private var showCreateCategorySheet = false
    @State private var searchText = ""
    
    private var filteredCategories: [TransactionCategory] {
        if searchText.isEmpty { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCategories) { category in
                    Button(action: {
                        selectedCategory = category
                        dismiss()
                    }) {
                        HStack {
                            Text(category.name)
                            Spacer()
                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
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
//                    dismiss()
                }
            }
        }
    }
}

#Preview {
    UpdateTransactionSheet(transaction: nil)
        .modelContainer(
            for: [Transaction.self, Account.self, TransactionCategory.self],
            inMemory: true
        )
}
