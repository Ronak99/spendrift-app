//
//  AccountsView.swift
//  Spendrift
//
//  Ledger of accounts under a centred total balance. Empty state and add control
//  match Transactions and Categories so the tabs feel like one box.
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @State private var showCreateSheet = false
    @State private var accountToEdit: Account?
    @State private var showLastAccountAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    emptyVault
                } else {
                    accountList
                }
            }
            .ledgerSearchHeader()
            .background(AppTheme.canvas.ignoresSafeArea())
            .ledgerNavigationTitle(HomeTab.accounts.title)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                LedgerToolbar(
                    addAccessibilityLabel: "Add account",
                    addAccessibilityIdentifier: "accountsAddButton",
                    onAdd: { showCreateSheet = true }
                )
            }
            .onAppear { healPrimaryAccount() }
            .alert("Keep at least one account", isPresented: $showLastAccountAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Spendrift records transactions against an account. Add another one before deleting this.")
            }
            .sheet(isPresented: $showCreateSheet) {
                UpdateAccountSheet(account: nil)
            }
            .sheet(
                isPresented: Binding(
                    get: { accountToEdit != nil },
                    set: { if !$0 { accountToEdit = nil } }
                )
            ) {
                if let accountToEdit {
                    UpdateAccountSheet(account: accountToEdit)
                }
            }
        }
    }

    // MARK: List

    private var accountList: some View {
        List {
            // One account's total is its row. The sum only says something from two up.
            if accounts.count >= 2 {
                Section {
                    AccountLedgerSummary(accounts: accounts)
                        .listRowInsets(EdgeInsets(top: 32, leading: 16, bottom: 20, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            Section {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    Button {
                        accountToEdit = account
                    } label: {
                        AccountListItem(account: account)
                            .listItemPositioned(index: index, count: accounts.count)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(AppTheme.card)
                    .accessibilityIdentifier(account.name)
                    .accessibilityLabel(account.name)
                }
                .onDelete { indexSet in
                    deleteAccounts(at: indexSet)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .softScrollEdge()
    }

    // MARK: Empty

    private var emptyVault: some View {
        VStack(spacing: 16) {
            CategoryEnamelTile(
                systemImage: "building.columns",
                color: AccountEnamel.fallback
            )
            .frame(width: 88, height: 88)
            .padding(.top, 28)

            Text("No accounts")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(AppTheme.ink)

            Text("Add a bank, card, or wallet to start tracking.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showCreateSheet = true }) {
                Text("Add account")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.actionBackground, in: Capsule())
                    .foregroundStyle(AppTheme.actionForeground)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("accountsEmptyAddButton")
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: Behaviour

    /// A ledger can lose its star to an older build or a restored backup. Hand
    /// it to an account on open so Voice and Shortcuts always have a target.
    private func healPrimaryAccount() {
        guard accounts.normalizePrimary() else { return }
        try? modelContext.save()
    }

    private func deleteAccounts(at offsets: IndexSet) {
        let toDelete = accounts.deletable(at: offsets)
        guard !toDelete.isEmpty else {
            showLastAccountAlert = true
            return
        }

        let deletedIDs = Set(toDelete.map(\.id))
        let survivors = accounts.filter { !deletedIDs.contains($0.id) }

        for account in toDelete {
            Analytics.capture(.accountDeleted, [Analytics.Key.name: account.name])
            modelContext.delete(account)
        }

        // Deleting the primary passes the star to an account that is left.
        survivors.normalizePrimary()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))

            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
            }
        }
    }
}

/// Sum of every account balance, centred like the Analytics tab's "Total spent" hero.
/// Lives in the accounts list so it scrolls away with the rows.
struct AccountLedgerSummary: View {
    let accounts: [Account]

    private var balance: Double {
        accounts.reduce(0) { $0 + $1.currentBalance }
    }

    /// Two, three, and four are spelled out. Five and up use the number.
    private var subline: String {
        let count = accounts.count
        let word: String
        switch count {
        case 2: word = "two"
        case 3: word = "three"
        case 4: word = "four"
        default: word = "\(count)"
        }
        return "Across \(word) accounts"
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("Total balance")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.inkSecondary)

            Text(balance.formatCurrencyRounded)
                .font(.system(size: 48, weight: .semibold))
                .tracking(-1.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(balance < 0 ? AppTheme.expense : AppTheme.ink)

            Text(subline)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Transaction.self, Account.self, TransactionCategory.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let sampleAccounts = [
        Account(name: "SBI Savings", balance: 85420.50, icon: .bankAccountOne, isPrimary: true),
        Account(name: "HDFC Salary", balance: 142_300, icon: .bankAccountFour),
        Account(name: "ICICI Credit Card", balance: -12_450.75, icon: .mastercard),
        Account(name: "Cash", balance: 3_200, icon: .cash),
        Account(name: "PhonePe Wallet", balance: 850, icon: .wallet),
        Account(name: "Fixed Deposit", balance: 250_000, icon: .savings),
    ]
    for account in sampleAccounts {
        context.insert(account)
    }

    return AccountsView()
        .modelContainer(container)
}
