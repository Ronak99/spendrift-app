//
//  WidgetDataStore.swift
//  SpendriftVoiceWidget
//
//  Created by Cursor on 05/04/26.
//

import Foundation
import SwiftData

// MARK: - Lightweight snapshots (value types safe to hold in TimelineEntry)

struct WidgetTransactionSnapshot: Identifiable {
    let id: UUID
    let categoryName: String
    let categoryIconName: String
    let amount: Double
    let isExpense: Bool
    let accountName: String
    let date: Date

    var formattedAmount: String { amount.formatCurrency }
}

struct WidgetAccountSnapshot {
    let name: String
    let balance: Double
    let iconSystemName: String
}

// MARK: - Read-only data access for timeline providers

enum WidgetDataStore {
    /// Returns the primary account's current balance snapshot, or `nil` if none is configured.
    static func fetchPrimaryAccount() throws -> WidgetAccountSnapshot? {
        let container = try IntentSwiftData.makeModelContainer()
        let context = ModelContext(container)
        let accounts = try context.fetch(FetchDescriptor<Account>())
        guard let primary = accounts.first(where: { $0.isPrimary }) else { return nil }
        return WidgetAccountSnapshot(
            name: primary.name,
            balance: primary.currentBalance,
            iconSystemName: primary.icon.systemImageName
        )
    }

    /// Returns up to `limit` most recent transactions, sorted by date descending.
    static func fetchRecentTransactions(limit: Int = 5) throws -> [WidgetTransactionSnapshot] {
        let container = try IntentSwiftData.makeModelContainer()
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let transactions = try context.fetch(descriptor)
        return transactions.map { txn in
            WidgetTransactionSnapshot(
                id: txn.id,
                categoryName: txn.category?.name ?? "Uncategorized",
                categoryIconName: txn.category?.icon.systemImageName ?? CategoryIcon.unknown.systemImageName,
                amount: txn.amount,
                isExpense: txn.transactionType == .expense,
                accountName: txn.account?.name ?? "",
                date: txn.date
            )
        }
    }

    /// Returns the total expense amount for the current calendar month.
    static func fetchMonthExpenses() throws -> Double {
        let container = try IntentSwiftData.makeModelContainer()
        let context = ModelContext(container)
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? now

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= start && $0.date <= end }
        )
        let transactions = try context.fetch(descriptor)
        return transactions
            .filter { $0.transactionType == .expense }
            .reduce(0.0) { $0 + $1.amount }
    }
}
