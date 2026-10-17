//
//  SearchLedgerScreen.swift
//  Spendrift
//
//  A result set opened in full: the total pinned at the top, sort and account
//  chips, then month groups with subtotals. Rows arrive 40 at a time.
//

import SwiftUI
import SwiftData

struct SearchLedgerScreen: View {
    let request: SearchLedgerRequest

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @State private var sort: Sort = .newest
    @State private var accountFilter: Account?
    @State private var shown = pageSize
    @State private var transactionToEdit: Transaction?

    private static let pageSize = 40

    private enum Sort: String, CaseIterable, Identifiable {
        case newest, largest

        var id: String { rawValue }
        var title: String { self == .newest ? "Newest" : "Largest" }
    }

    private var requested: [Transaction] {
        let wanted = Set(request.transactionIDs)
        return allTransactions.filter { $0.isPersisted && wanted.contains($0.id) }
    }

    private var accountsInSet: [Account] {
        var seen = Set<UUID>()
        return requested.compactMap { transaction in
            guard let account = transaction.account, seen.insert(account.id).inserted else { return nil }
            return account
        }
    }

    private var filtered: [Transaction] {
        let base = accountFilter.map { account in
            requested.filter { $0.account?.id == account.id }
        } ?? requested
        return sort == .newest
            ? base.sorted { $0.date > $1.date }
            : base.sorted { $0.amount > $1.amount }
    }

    /// Month groups, newest month first, each with its own subtotal.
    private var groups: [(month: MonthRef, transactions: [Transaction])] {
        let visible = Array(filtered.prefix(shown))
        var order: [MonthRef] = []
        var byMonth: [MonthRef: [Transaction]] = [:]
        for transaction in visible {
            let ref = MonthRef.of(transaction.date)
            if byMonth[ref] == nil {
                order.append(ref)
            }
            byMonth[ref, default: []].append(transaction)
        }
        return order.map { ($0, byMonth[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            total
            chips
            list
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(request.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $transactionToEdit) { transaction in
            UpdateTransactionSheet(transaction: transaction)
        }
        .onChange(of: sort) { _, _ in shown = Self.pageSize }
        .onChange(of: accountFilter?.id) { _, _ in shown = Self.pageSize }
    }

    private var header: some View {
        HStack(spacing: 6) {
            BackChevronButton()
            VStack(alignment: .leading, spacing: 0) {
                Text(request.title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Text(request.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.inkSecondary)
            }
            Spacer(minLength: 8)
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 4)
    }

    private var total: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(LedgerSearch.expenseTotal(filtered).formatCurrencyRounded)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-1)
                .monospacedDigit()
            Text("spent")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.inkSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Sort.allCases) { option in
                    chip(option.title, isOn: sort == option) { sort = option }
                }

                if !accountsInSet.isEmpty {
                    AppTheme.hairline
                        .frame(width: 1, height: 22)
                        .padding(.horizontal, 2)

                    ForEach(accountsInSet) { account in
                        chip(account.name, isOn: accountFilter?.id == account.id) {
                            accountFilter = accountFilter?.id == account.id ? nil : account
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(isOn ? AppTheme.ink : AppTheme.card, in: Capsule())
                .foregroundStyle(isOn ? AppTheme.canvas : AppTheme.inkSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(groups, id: \.month) { group in
                    section(group)
                }

                if shown < filtered.count {
                    Text("Loading…")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.inkTertiary)
                        .onAppear { shown += Self.pageSize }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
    }

    private func section(_ group: (month: MonthRef, transactions: [Transaction])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(group.month.name) \(String(group.month.year))")
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer(minLength: 8)
                Text(LedgerSearch.expenseTotal(group.transactions).formatCurrencyRounded)
                    .monospacedDigit()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.inkSecondary)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            HomeCard {
                ForEach(Array(group.transactions.enumerated()), id: \.element.id) { index, transaction in
                    if index > 0 {
                        HomeRowDivider()
                    }
                    Button {
                        transactionToEdit = transaction
                    } label: {
                        TransactionListItem(transaction: transaction, dateStyle: .relative)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(HomePressStyle(scale: 1))
                }
            }
        }
    }
}

/// Plain back chevron for screens that draw their own header.
struct BackChevronButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}
