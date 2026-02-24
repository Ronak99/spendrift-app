import SwiftUI

struct TransactionsView: View {
    let transactions: [Transaction]
    
    var body: some View {
        List {
            if transactions.isEmpty {
                ContentUnavailableView {
                    Label("No Transactions", systemImage: "doc.text")
                } description: {
                    Text("Extract data from a PDF to see transactions here")
                }
            } else {
                ForEach(transactions) { transaction in
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
            }
        }
    }
}