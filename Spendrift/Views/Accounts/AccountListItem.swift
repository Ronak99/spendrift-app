//
//  AccountListItem.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct AccountListItem: View {
    let account: Account
    
    var body: some View {
        HStack(spacing: 12) {
            // Account icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: account.icon.systemImageName)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
            
            // Account details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if account.isPrimary {
                        Text("Primary")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                Text("Balance: \(account.currentBalance.formatCurrency)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        AccountListItem(account: Account(
            name: "SBI Savings",
            balance: 50000,
            icon: .bankAccountOne
        ))
    }
}
