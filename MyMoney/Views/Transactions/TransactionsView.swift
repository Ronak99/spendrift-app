//
//  TransactionsView.swift
//  MyMoney
//
//  Created by Ronak Punase on 03/08/25.
//


import SwiftUI

struct TransactionsView: View {
    let transactions: [Transaction] // Your transactions array

       var groupedByDate: [String: [Transaction]] {
           Dictionary(grouping: transactions, by: { $0.rawDate })
       }

    var body: some View {
        List {
            ForEach(groupedByDate.keys.sorted(),
                    id: \.self) {
                date in Section {
                    ForEach(groupedByDate[date] ?? [],
                            id: \.self) {
                        transaction in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(transaction.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(transaction.formattedAmount)
                                    .font(.headline)
                                    .foregroundColor(transaction.amount < 0 ? .red : .green)
                            }
                            Text(transaction.transactionDetails)
                                .font(.body)
                            Text("Balance: \(transaction.formattedBalance)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(date)
                }
            }
        }
    }
}

#Preview {
    TransactionsView(transactions: [
        Transaction(date: .now, rawDate: "01 Jul", receiverUPI: "receiver", transactionDetails: "123", amount: 12.0, balance: 1300.0, transactionType: .nft),
        Transaction(date: .now, rawDate: "01 Jul", receiverUPI: "receiver", transactionDetails: "123", amount: 12.0, balance: 1300.0, transactionType: .nft),
        Transaction(date: .now, rawDate: "02 Jul", receiverUPI: "receiver", transactionDetails: "123", amount: 12.0, balance: 1300.0, transactionType: .nft)
    ])
}
