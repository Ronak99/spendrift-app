//
//  Transaction+Extensions.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

extension Transaction {
    var isExpense: Bool {
        transactionType == .expense
    }
    
    var formattedAmount: String {
        amount.formatCurrency
    }
    
    var keyValues: String {
        "\(date.year)_\(date.month)_\(date.day)_\(amount)_\(transactionType.rawValue)"
    }
}

extension [Transaction] {
    var groupedByDate: [String: [Transaction]] {
        Dictionary(grouping: self) { transaction in
            transaction.date.formatDate
        }
    }

    /// Calendar days in descending order (most recent first); within each day, transactions by date descending.
    var groupedByDateRecentFirst: [(dayStart: Date, title: String, transactions: [Transaction])] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: self) { calendar.startOfDay(for: $0.date) }
        return byDay.keys
            .sorted(by: >)
            .map { dayStart in
                let title = dayStart.formatDate
                let transactions = (byDay[dayStart] ?? []).sorted { $0.date > $1.date }
                return (dayStart, title, transactions)
            }
    }
    
    var totalExpenses: Double {
        filter { $0.transactionType == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    var totalIncome: Double {
        filter { $0.transactionType == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    var savings: Double {
        totalIncome - totalExpenses
    }
}
