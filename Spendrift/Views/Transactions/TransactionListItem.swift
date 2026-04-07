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
                
                Image(systemName: transaction.category?.icon.systemImageName ?? CategoryIcon.unknown.systemImageName)
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
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.headline)
                    .foregroundColor(transaction.transactionType == .expense ? .red : .green)

                Text(transaction.date, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
