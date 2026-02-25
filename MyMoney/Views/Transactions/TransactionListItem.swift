//
//  TransactionListItem.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct TransactionListItem: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(transaction.category?.icon.rawValue == "unknown" ? Color.gray.opacity(0.2) : Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: categoryIconName)
                    .font(.system(size: 20))
                    .foregroundColor(transaction.category?.icon.rawValue == "unknown" ? .gray : .accentColor)
            }
            
            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category?.name ?? "Uncategorized")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let accountName = transaction.account?.name {
                    Text(accountName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            Text(transaction.formattedAmount)
                .font(.headline)
                .foregroundColor(transaction.transactionType == .expense ? .red : .green)
        }
        .padding(.vertical, 4)
    }
    
    private var categoryIconName: String {
        guard let icon = transaction.category?.icon else {
            return "circle"
        }
        return iconName(for: icon.rawValue)
    }
    
    private func iconName(for rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "dividend": return "chart.line.uptrend.xyaxis"
        case "friends": return "person.2"
        case "salary": return "briefcase"
        case "coupons": return "tag"
        case "refunds": return "arrow.uturn.backward"
        case "sale": return "cart"
        case "bills": return "doc.text"
        case "education": return "book"
        case "entertainment": return "tv"
        case "food": return "fork.knife"
        case "health": return "cross.case"
        case "home": return "house"
        case "investments": return "chart.pie"
        case "shopping": return "bag"
        case "sport": return "figure.run"
        case "transportation": return "car"
        case "baby": return "figure.child"
        case "beauty": return "sparkles"
        case "clothing": return "tshirt"
        case "tax": return "doc.text.magnifyingglass"
        case "electronics": return "iphone"
        case "insurance": return "shield"
        default: return "circle"
        }
    }
}

#Preview {
    List {
        TransactionListItem(transaction: Transaction(
            notes: "Test transaction",
            amount: 1000,
            transactionType: .expense
        ))
    }
}
