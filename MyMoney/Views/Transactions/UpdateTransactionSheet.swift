//
//  UpdateTransactionSheet.swift
//  MyMoney
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
    
    @State private var notes: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var transactionType: TransactionType = .expense
    @State private var selectedAccount: Account?
    @State private var selectedCategory: TransactionCategory?
    @State private var showAccountPicker = false
    @State private var showCategoryPicker = false
    @State private var showCreateCategorySheet = false
    
    private var filteredCategories: [TransactionCategory] {
        categories.filter { $0.type.rawValue == transactionType.rawValue }
    }
    
    private var isValid: Bool {
        !amount.isEmpty && selectedAccount != nil && selectedCategory != nil && Double(amount) != nil && Double(
            amount
        )! > 0
    }
    
    private var categoryText : String {
        if filteredCategories.isEmpty {
            return "Create Category"
        } else {
            if selectedCategory?.name != nil {
                return selectedCategory!.name
            } else {
                return "Select Category"
            }
        }
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
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $transactionType) {
                    ForEach(
                        TransactionType.allCases.filter { $0 != .none
                        },
                        id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                }
                .pickerStyle(.palette)
                
                    
                Button(action: { showAccountPicker = true }) {
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
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
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
                    accounts: accounts
                )
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(
                    selectedCategory: $selectedCategory,
                    categories: filteredCategories
                )
            }
            .sheet(isPresented: $showCreateCategorySheet) {
                UpdateCategorySheet(category: nil) { newCategory in
                    selectedCategory = newCategory
                }
            }
            .onAppear {
                if let transaction = transaction {
                    notes = transaction.notes
                    amount = String(transaction.amount)
                    date = transaction.date
                    transactionType = transaction.transactionType
                    selectedAccount = transaction.account
                    selectedCategory = transaction.category
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        
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
                account: selectedAccount
            )
            modelContext.insert(newTransaction)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAccount: Account?
    let accounts: [Account]
    
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
        }
    }
}

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: TransactionCategory?
    let categories: [TransactionCategory]
    
    @State private var showCreateCategorySheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
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
                UpdateCategorySheet(category: nil) { newCategory in
                    selectedCategory = newCategory
                    dismiss()
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
