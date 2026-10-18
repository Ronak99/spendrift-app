//
//  AccountsPane.swift
//  Spendrift
//
//  One row per account under a centred total balance.
//  Creating lives inside the list it adds to: a dashed slot at the top, never
//  another bare plus in the title bar.
//

import SwiftUI

struct AccountsPane: View {
    let accounts: [Account]
    let transactions: [Transaction]
    var onOpenAccount: (Account) -> Void
    var onCreateAccount: () -> Void
    /// Whether a swipe deletes the account straight away rather than asking first.
    var deletesImmediately: (Account) -> Bool
    var onDelete: (Account) -> Void

    var body: some View {
        if accounts.isEmpty {
            EmptyStateContainer {
                HomeCard {
                    emptyCreateSlot
                }
            }
            .homeTrayClearance()
        } else {
            accountList
        }
    }

    private var accountList: some View {
        List {
            if accounts.count >= 2 {
                Section {
                    AccountLedgerSummary(accounts: accounts)
                        .listRowInsets(EdgeInsets(top: 32, leading: 16, bottom: 20, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            Section {
                createSlot
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    row(account, index: index + 1, count: accounts.count + 1)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .homeTrayClearance()
    }

    private var createSlot: some View {
        Button(action: onCreateAccount) {
            createSlotLabel
                .padding(.horizontal, 6)
                .listItemPositioned(index: 0, count: accounts.count + 1)
        }
        .buttonStyle(.plain)
        .listRowBackground(AppTheme.card)
        .accessibilityIdentifier("accountsCreateSlot")
        .accessibilityLabel("New account")
    }

    /// The same slot with no list to head, laid out like the Transactions tab's empty month.
    private var emptyCreateSlot: some View {
        Button(action: onCreateAccount) {
            createSlotLabel
                .padding(.vertical, 12)
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityIdentifier("accountsCreateSlot")
        .accessibilityLabel("New account")
    }

    private var createSlotLabel: some View {
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
            // The destructive role makes the list slide the row away at once. That suits
            // an immediate delete, but would hide the row behind a confirmation or the
            // last-account alert, so those keep a plain red button.
            Button(role: deletesImmediately(account) ? .destructive : nil) {
                onDelete(account)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .accessibilityIdentifier(account.name)
        .accessibilityLabel(account.name)
    }
}

/// Sum of every account balance, centred like the All tab's "Total spent" hero.
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
