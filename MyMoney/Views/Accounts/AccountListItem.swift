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
                Text(account.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
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
        case .sbi, .fi, .icici, .hdfc:
            return "building.2"
        case .mastercard, .visa:
            return "creditcard"
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
            icon: .sbi
        ))
    }
}
