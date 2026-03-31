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
                
                Image(systemName: accountIconName)
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
    
    private var accountIconName: String {
        switch account.icon {
        case .bankAccountOne:
            return "building.2"
        case .bankAccountTwo:
            return "bolt.circle"
        case .bankAccountThree:
            return "indianrupeesign.circle"
        case .bankAccountFour:
            return "building.columns"
        case .mastercard:
            return "creditcard"
        case .visa:
            return "creditcard.fill"
        case .cash:
            return "banknote"
        case .wallet:
            return "wallet.pass"
        case .savings:
            return "lock.circle"
        case .unknown:
            return "questionmark.circle"
        }
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
