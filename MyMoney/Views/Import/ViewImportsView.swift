//
//  ViewImportsView.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

struct ViewImportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var importedTransactions: [ImportedTransaction]
    let onSave: () -> Void
    
    @State private var selectedDate: Date = Date()
    @State private var selectedTransaction: ImportedTransaction?
    
    private var filteredTransactions: [ImportedTransaction] {
        let startOfMonth = selectedDate.startOfMonth
        let endOfMonth = selectedDate.endOfMonth
        return importedTransactions.filter { $0.date >= startOfMonth && $0.date <= endOfMonth }
    }
    
    private var groupedTransactions: [String: [ImportedTransaction]] {
        Dictionary(grouping: filteredTransactions) { $0.date.formatDate }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date selector
                CapsuleDateSelector(
                    date: selectedDate,
                    onPrevious: { selectedDate = selectedDate.previousMonth },
                    onNext: { selectedDate = selectedDate.nextMonth }
                )
                .padding()
                
                // Transaction list
                if filteredTransactions.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "No Transactions",
                        description: "No imported transactions for \(selectedDate.monthYear)"
                    )
                } else {
                    List {
                        ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { dateKey in
                            Section {
                                ForEach(groupedTransactions[dateKey] ?? [], id: \.id) { transaction in
                                    ImportedTransactionItem(
                                        transaction: transaction,
                                        onTap: {
                                            selectedTransaction = transaction
                                        },
                                        onDoubleTap: {
                                            toggleTransactionType(for: transaction)
                                        }
                                    )
                                }
                            } header: {
                                Text(dateKey)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("View Imports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(importedTransactions.isEmpty)
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                EditImportedTransactionSheet(transaction: transaction, importedTransactions: $importedTransactions)
            }
        }
    }
    
    private func toggleTransactionType(for transaction: ImportedTransaction) {
        if let index = importedTransactions.firstIndex(where: { $0.id == transaction.id }) {
            importedTransactions[index].transactionType = transaction.transactionType == .expense ? .income : .expense
        }
    }
}

struct ImportedTransactionItem: View {
    let transaction: ImportedTransaction
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    
    @State private var tapTask: Task<Void, Never>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(transaction.notes)
                    .font(.headline)
                Spacer()
                Text(transaction.amount.formatCurrency)
                    .font(.headline)
                    .foregroundColor(transaction.transactionType == .expense ? .red : .green)
            }
            
            HStack {
                Label(transaction.account?.name ?? "Select Account", systemImage: "creditcard")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(transaction.category?.name ?? "Select Category", systemImage: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            tapTask?.cancel()
            onDoubleTap()
        }
        .onTapGesture {
            tapTask?.cancel()
            tapTask = Task {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                if !Task.isCancelled {
                    onTap()
                }
            }
        }
    }
}

struct EditImportedTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    
    let transaction: ImportedTransaction
    @Binding var importedTransactions: [ImportedTransaction]
    
    @State private var selectedAccount: Account?
    @State private var selectedCategory: TransactionCategory?
    @State private var notes: String = ""
    @State private var transactionType: TransactionType = .expense
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction Type") {
                    Picker("Type", selection: $transactionType) {
                        ForEach([TransactionType.expense, TransactionType.income], id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Account") {
                    Picker("Account", selection: $selectedAccount) {
                        Text("None").tag(nil as Account?)
                        ForEach(accounts) { account in
                            Text(account.name).tag(account as Account?)
                        }
                    }
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(nil as TransactionCategory?)
                        ForEach(categories.filter { $0.type.rawValue == transactionType.rawValue }) { category in
                            Text(category.name).tag(category as TransactionCategory?)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .onAppear {
                selectedAccount = transaction.account
                selectedCategory = transaction.category
                notes = transaction.notes
                transactionType = transaction.transactionType
            }
        }
    }
    
    private func saveChanges() {
        if let index = importedTransactions.firstIndex(where: { $0.id == transaction.id }) {
            importedTransactions[index].account = selectedAccount
            importedTransactions[index].category = selectedCategory
            importedTransactions[index].notes = notes
            importedTransactions[index].transactionType = transactionType
        }
        dismiss()
    }
}

#Preview {
    ViewImportsView(
        importedTransactions: .constant([]),
        onSave: {}
    )
}
