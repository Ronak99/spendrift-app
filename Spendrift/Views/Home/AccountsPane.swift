//
//  AccountsPane.swift
//  Spendrift
//
//  One row per account under the pinned Balance / Income / Expenses strip.
//  Creating lives inside the list it adds to: a dashed slot at the top, never
//  another bare plus in the title bar.
//

import SwiftUI

struct AccountsPane: View {
    let accounts: [Account]
    let transactions: [Transaction]
    var onOpenAccount: (Account) -> Void
    var onCreateAccount: () -> Void
    var onDelete: (Account) -> Void
    var onScroll: (CGFloat) -> Void

    var body: some View {
        List {
            Section {
                createSlot
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    row(account, index: index + 1, count: accounts.count + 1)
                }
            } footer: {
                if accounts.isEmpty {
                    Text("Add a bank, card, cash or wallet to start tracking.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .homeTrayClearance()
        .reportingScrollOffset(onScroll)
    }

    private var createSlot: some View {
        Button(action: onCreateAccount) {
            HStack(spacing: 14) {
                CreateSlotEnamel(side: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("New account")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.inkSecondary)
                    Text("Bank, card, cash or wallet")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .listItemPositioned(index: 0, count: accounts.count + 1)
        }
        .buttonStyle(.plain)
        .listRowBackground(AppTheme.card)
        .accessibilityIdentifier("accountsCreateSlot")
        .accessibilityLabel("New account")
    }

    private func row(_ account: Account, index: Int, count: Int) -> some View {
        Button {
            onOpenAccount(account)
        } label: {
            AccountListItem(account: account)
                .listItemPositioned(index: index, count: count)
        }
        .buttonStyle(.plain)
        .listRowBackground(AppTheme.card)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(account)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityIdentifier(account.name)
        .accessibilityLabel(account.name)
    }
}

/// Balance, Income and Expenses across the whole ledger. Pinned with the tab strip,
/// so it stays readable while the rows scroll.
struct AccountLedgerSummary: View {
    let accounts: [Account]
    let transactions: [Transaction]

    private var balance: Double {
        accounts.reduce(0) { $0 + $1.currentBalance }
    }

    /// Match the ledger: round the figures once there are enough rows that
    /// decimals are noise rather than detail.
    private var usesRounded: Bool { transactions.count > 10 }

    private func money(_ value: Double) -> String {
        usesRounded ? value.formatCurrencyRounded : value.formatCurrency
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            column("Balance", money(balance), tint: balance < 0 ? AppTheme.expense : AppTheme.ink, alignment: .leading)
            Spacer(minLength: 8)
            column("Income", money(transactions.totalIncome), tint: AppTheme.income, alignment: .center)
            Spacer(minLength: 8)
            column("Expenses", money(transactions.totalExpenses), tint: AppTheme.expense, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func column(
        _ caption: String,
        _ value: String,
        tint: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.inkSecondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.3)
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
