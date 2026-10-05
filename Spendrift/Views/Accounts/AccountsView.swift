//
//  AccountsView.swift
//  Spendrift
//
//  Ledger of accounts. Empty state and add control match Transactions
//  and Categories so the tabs feel like one box.
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @State private var showCreateSheet = false
    @State private var accountToEdit: Account?
    @State private var showLastAccountAlert = false

    private var totalBalanceAllAccounts: Double {
        accounts.reduce(0) { $0 + $1.currentBalance }
    }

    private var expenseSoFar: Double {
        allTransactions.totalExpenses
    }

    private var incomeSoFar: Double {
        allTransactions.totalIncome
    }

    /// Match Transactions: round summary figures when there are many transactions.
    private var usesRoundedSummary: Bool {
        allTransactions.count > 10
    }

    private var formattedExpenseSoFar: String {
        usesRoundedSummary ? expenseSoFar.formatCurrencyRounded : expenseSoFar.formatCurrency
    }

    private var formattedIncomeSoFar: String {
        usesRoundedSummary ? incomeSoFar.formatCurrencyRounded : incomeSoFar.formatCurrency
    }

    private var formattedTotalBalance: String {
        totalBalanceAllAccounts.formatCurrency
    }

    private var isDark: Bool { colorScheme == .dark }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    private var addBackground: Color {
        isDark ? Color.white.opacity(0.92) : Color(hex: "#111111")
    }

    private var addForeground: Color {
        isDark ? Color(hex: "#111111") : .white
    }

    private var canvas: Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    emptyVault
                } else {
                    List {
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                            Button {
                                accountToEdit = account
                            } label: {
                                AccountListItem(account: account)
                                    .listItemPositioned(index: index, count: accounts.count)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(account.name)
                            .accessibilityLabel(account.name)
                        }
                        .onDelete { indexSet in
                            deleteAccounts(at: indexSet)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .softScrollEdge()
                    .scrollingHeaderBar {
                        AccountLedgerSummary(
                            balance: formattedTotalBalance,
                            income: formattedIncomeSoFar,
                            expenses: formattedExpenseSoFar,
                            balanceValue: totalBalanceAllAccounts
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                    }
                }
            }
            .background { canvas.ignoresSafeArea() }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar { toolbarContent }
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
                .foregroundStyle(heroPrimary)

            Text("Add a bank, card, or wallet to start tracking.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showCreateSheet = true }) {
                Text("Add account")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(addBackground, in: Capsule())
                    .foregroundStyle(addForeground)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("accountsEmptyAddButton")
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
        }
    }

    private var addButton: some View {
        Button(action: { showCreateSheet = true }) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(addForeground)
                .frame(width: 32, height: 32)
                .background(addBackground, in: Circle())
        }
        .accessibilityLabel("Add account")
        .accessibilityIdentifier("accountsAddButton")
    }

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

private struct AccountLedgerSummary: View {
    let balance: String
    let income: String
    let expenses: String
    let balanceValue: Double

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(balance)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(balanceValue < 0 ? .red : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            VStack(alignment: .center, spacing: 4) {
                Text("Income")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(income)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(CategoryEnamel.income)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Expenses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(expenses)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(CategoryEnamel.expense)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
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
