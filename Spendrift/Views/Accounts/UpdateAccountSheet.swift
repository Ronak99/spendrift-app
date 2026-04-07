//
//  UpdateAccountSheet.swift
//  Spendrift
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
    
    @Query(sort: \Account.createdOn) private var allAccounts: [Account]
    @State private var name: String = ""
    @State private var balance: String = ""
    @State private var icon = AccountIcon.bankAccountOne
    @State private var isPrimary = false
    @State private var showPrimaryInfo = false
    
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
                    TextField("0", text: $balance)
                        .keyboardType(.decimalPad)
                }

                Toggle(isOn: $isPrimary) {
                    HStack(spacing: 6) {
                        Text("Set as Primary Account")
                        Button {
                            showPrimaryInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showPrimaryInfo, arrowEdge: .bottom) {
                            Text("Transactions are created under primary account in case of Voice or Shortcuts.")
                                .font(.footnote)
                                .padding(12)
                                .frame(maxWidth: 300)
                                .presentationCompactAdaptation(.popover)
                        }
                        .accessibilityLabel("About Primary Account")
                    }
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
                    balance = account.balance.wholeAmountDisplayString
                    icon = account.icon
                    isPrimary = account.isPrimary
                } else {
                    isPrimary = allAccounts.isEmpty
                }
            }
        }
    }
    
    private func saveAccount() {
        guard let balanceValue = Double(balance) else { return }
        
        if let account = account {
            // Update existing
            if isPrimary {
                clearExistingPrimary(except: account)
            }
            account.name = name
            account.balance = balanceValue
            account.icon = icon
            account.isPrimary = isPrimary
        } else {
            // Create new
            if isPrimary {
                clearExistingPrimary(except: nil)
            }
            let newAccount = Account(
                name: name,
                balance: balanceValue,
                icon: icon,
                isPrimary: isPrimary
            )
            modelContext.insert(newAccount)
            onCreated?(newAccount)
        }
        
        try? modelContext.save()
        dismiss()
    }

    private func clearExistingPrimary(except account: Account?) {
        for existing in allAccounts {
            if let account, existing.id == account.id { continue }
            if existing.isPrimary {
                existing.isPrimary = false
            }
        }
    }
}

#Preview {
    UpdateAccountSheet(account: nil)
        .modelContainer(for: [Account.self], inMemory: true)
}
