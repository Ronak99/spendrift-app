//
//  StatisticsView.swift
//  MyMoney
//
//  Created by Ronak Punase on 03/08/25.
//


import SwiftUI
import PDFKit
import Foundation

struct StatisticsView: View {
    let transactions: [Transaction]
    
    private var totalIncome: Decimal {
        transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }
    
    private var totalExpenses: Decimal {
        transactions.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount }
    }
    
    private var netAmount: Decimal {
        totalIncome + totalExpenses
    }
    
    var body: some View {
        List {
            Section("Summary") {
                StatRow(title: "Total Transactions", value: "\(transactions.count)")
                StatRow(title: "Total Income", value: formatCurrency(totalIncome), color: .green)
                StatRow(title: "Total Expenses", value: formatCurrency(abs(totalExpenses)), color: .red)
                StatRow(title: "Net Amount", value: formatCurrency(netAmount), color: netAmount >= 0 ? .green : .red)
            }
            
            if let firstTransaction = transactions.first,
               let lastTransaction = transactions.last {
                Section("Date Range") {
                    StatRow(title: "From", value: firstTransaction.formattedDate)
                    StatRow(title: "To", value: lastTransaction.formattedDate)
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSNumber) ?? "$0.00"
    }
}
