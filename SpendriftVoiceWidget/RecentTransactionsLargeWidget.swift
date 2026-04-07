//
//  RecentTransactionsLargeWidget.swift
//  MyMoneyVoiceWidget
//
//  Created by Cursor on 05/04/26.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline entry

struct LargeWidgetEntry: TimelineEntry {
    let date: Date
    let config: QuickExpenseWidgetConfig
    let primaryBalance: Double?
    let accountName: String?
    let monthExpenses: Double
    let recentTransactions: [WidgetTransactionSnapshot]
}

// MARK: - Timeline provider

struct LargeWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = QuickExpenseWidgetConfig
    typealias Entry = LargeWidgetEntry

    func placeholder(in context: Context) -> LargeWidgetEntry {
        LargeWidgetEntry(
            date: .now,
            config: QuickExpenseWidgetConfig(),
            primaryBalance: 24_500,
            accountName: "Primary",
            monthExpenses: 8_200,
            recentTransactions: [
                WidgetTransactionSnapshot(
                    id: UUID(), categoryName: "Food", categoryIconName: "fork.knife",
                    amount: 450, isExpense: true, accountName: "Primary", date: .now
                ),
                WidgetTransactionSnapshot(
                    id: UUID(), categoryName: "Transport", categoryIconName: "car",
                    amount: 250, isExpense: true, accountName: "Primary",
                    date: .now.addingTimeInterval(-3_600)
                ),
                WidgetTransactionSnapshot(
                    id: UUID(), categoryName: "Salary", categoryIconName: "briefcase",
                    amount: 50_000, isExpense: false, accountName: "Primary",
                    date: .now.addingTimeInterval(-7_200)
                ),
            ]
        )
    }

    func snapshot(for config: QuickExpenseWidgetConfig, in context: Context) async -> LargeWidgetEntry {
        await fetchEntry(config: config)
    }

    func timeline(
        for config: QuickExpenseWidgetConfig,
        in context: Context
    ) async -> Timeline<LargeWidgetEntry> {
        let entry = await fetchEntry(config: config)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func fetchEntry(config: QuickExpenseWidgetConfig) async -> LargeWidgetEntry {
        let account = try? WidgetDataStore.fetchPrimaryAccount()
        let expenses = (try? WidgetDataStore.fetchMonthExpenses()) ?? 0
        let transactions = (try? WidgetDataStore.fetchRecentTransactions(limit: 4)) ?? []
        return LargeWidgetEntry(
            date: .now,
            config: config,
            primaryBalance: account?.balance,
            accountName: account?.name,
            monthExpenses: expenses,
            recentTransactions: transactions
        )
    }
}

// MARK: - View

struct LargeWidgetView: View {
    let entry: LargeWidgetEntry

    private var quickAddIntent: QuickAmountExpenseIntent {
        let intent = QuickAmountExpenseIntent()
        intent.amount = entry.config.amount
        intent.category = entry.config.category
        intent.notes = ""
        return intent
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 14)
            actionRow
            Divider().padding(.horizontal, 14)
            transactionSection
            footerSection
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }

    // MARK: Header – balance + month summary

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let name = entry.accountName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(entry.primaryBalance?.formatCurrency ?? "—")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text("Balance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("This month")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.monthExpenses.formatCurrency)
                    .font(.headline)
                    .foregroundStyle(.red)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Spent")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Action row – Quick Add, Voice, Type

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(intent: quickAddIntent) {
                actionPill(icon: "plus.circle.fill", label: entry.config.label, color: .accentColor)
            }
            .buttonStyle(.plain)

            Link(destination: URL(string: "mymoney://voiceExpense")!) {
                actionPill(icon: "mic.fill", label: "Voice", color: .orange)
            }

            Link(destination: URL(string: "mymoney://createTransaction")!) {
                actionPill(icon: "plus", label: "Type", color: .purple)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func actionPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Transaction list

    @ViewBuilder
    private var transactionSection: some View {
        if entry.recentTransactions.isEmpty {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No transactions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(entry.recentTransactions.enumerated()), id: \.element.id) { index, txn in
                    transactionRow(txn)
                    if index < entry.recentTransactions.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func transactionRow(_ txn: WidgetTransactionSnapshot) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(txn.isExpense ? Color.red.opacity(0.12) : Color.green.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: txn.categoryIconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(txn.isExpense ? .red : .green)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(txn.categoryName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !txn.accountName.isEmpty {
                    Text(txn.accountName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text((txn.isExpense ? "−" : "+") + txn.formattedAmount)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(txn.isExpense ? .red : .green)
                Text(txn.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    // MARK: Footer

    private var footerSection: some View {
        HStack {
            Text("Updated \(entry.date, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Link(destination: URL(string: "mymoney://")!) {
                Text("View all →")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .padding(.top, 4)
    }
}

// MARK: - Widget definition

struct RecentTransactionsLargeWidget: Widget {
    let kind: String = "RecentTransactionsLargeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuickExpenseWidgetConfig.self,
            provider: LargeWidgetProvider()
        ) { entry in
            LargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Transactions")
        .description("Glance at your balance, monthly spend, and last 5 transactions.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    RecentTransactionsLargeWidget()
} timeline: {
    LargeWidgetEntry(
        date: .now,
        config: QuickExpenseWidgetConfig(),
        primaryBalance: 24_500,
        accountName: "HDFC Savings",
        monthExpenses: 8_200,
        recentTransactions: [
            WidgetTransactionSnapshot(
                id: UUID(), categoryName: "Food", categoryIconName: "fork.knife",
                amount: 450, isExpense: true, accountName: "HDFC Savings", date: .now
            ),
            WidgetTransactionSnapshot(
                id: UUID(), categoryName: "Transport", categoryIconName: "car",
                amount: 250, isExpense: true, accountName: "HDFC Savings",
                date: .now.addingTimeInterval(-3_600)
            ),
            WidgetTransactionSnapshot(
                id: UUID(), categoryName: "Salary", categoryIconName: "briefcase",
                amount: 50_000, isExpense: false, accountName: "HDFC Savings",
                date: .now.addingTimeInterval(-7_200)
            ),
            WidgetTransactionSnapshot(
                id: UUID(), categoryName: "Shopping", categoryIconName: "bag",
                amount: 1_200, isExpense: true, accountName: "HDFC Savings",
                date: .now.addingTimeInterval(-18_000)
            ),
        ]
    )
}
