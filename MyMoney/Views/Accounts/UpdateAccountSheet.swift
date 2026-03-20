//
//  UpdateAccountSheet.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

struct UpdateAccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let account: Account?
    var onCreated: ((Account) -> Void)? = nil
    
    @State private var name: String = ""
    @State private var balance: String = ""
//    @State private var icon: AccountIcon = .unknown
    @State var icon = AccountIcon.sbi {
        didSet {
            print("Setting to \(icon)")
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !balance.isEmpty && Double(balance) != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account Name") {
                    TextField("Enter account name", text: $name)
                }
                
                Section("Initial Balance") {
                    TextField("0.00", text: $balance)
                        .keyboardType(.decimalPad)
                }
                
                IconGridPicker(icons: Array(AccountIcon.allCases), selectedIcon: $icon)
            }
            .navigationTitle(account == nil ? "New Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAccount()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let account = account {
                    name = account.name
                    balance = String(account.balance)
                    icon = account.icon
                }
            }
        }
    }
    
    private func saveAccount() {
        guard let balanceValue = Double(balance) else { return }
        
        if let account = account {
            // Update existing
            account.name = name
            account.balance = balanceValue
            account.icon = icon
        } else {
            // Create new
            let newAccount = Account(
                name: name,
                balance: balanceValue,
                icon: icon
            )
            modelContext.insert(newAccount)
            onCreated?(newAccount)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    UpdateAccountSheet(account: nil)
        .modelContainer(for: [Account.self], inMemory: true)
}
