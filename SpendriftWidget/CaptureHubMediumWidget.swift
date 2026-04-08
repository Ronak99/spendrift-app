//
//  CaptureHubMediumWidget.swift
//  SpendriftWidget
//
//  Created by Cursor on 05/04/26.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline entry

struct MediumWidgetEntry: TimelineEntry {
    let date: Date
    let config: QuickExpenseWidgetConfig
    let primaryBalance: Double?
    let accountName: String?
    let monthExpenses: Double
}

// MARK: - Timeline provider

struct MediumWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = QuickExpenseWidgetConfig
    typealias Entry = MediumWidgetEntry

    func placeholder(in context: Context) -> MediumWidgetEntry {
        MediumWidgetEntry(
            date: .now,
            config: QuickExpenseWidgetConfig(),
            primaryBalance: 24_500,
            accountName: "Primary",
            monthExpenses: 8_200
        )
    }

    func snapshot(for config: QuickExpenseWidgetConfig, in context: Context) async -> MediumWidgetEntry {
        await fetchEntry(config: config)
    }

    func timeline(
        for config: QuickExpenseWidgetConfig,
        in context: Context
    ) async -> Timeline<MediumWidgetEntry> {
        let entry = await fetchEntry(config: config)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func fetchEntry(config: QuickExpenseWidgetConfig) async -> MediumWidgetEntry {
        let account = try? WidgetDataStore.fetchPrimaryAccount()
        let expenses = (try? WidgetDataStore.fetchMonthExpenses()) ?? 0
        return MediumWidgetEntry(
            date: .now,
            config: config,
            primaryBalance: account?.balance,
            accountName: account?.name,
            monthExpenses: expenses
        )
    }
}

// MARK: - View

struct MediumWidgetView: View {
    let entry: MediumWidgetEntry

    private var quickAddIntent: QuickAmountExpenseIntent {
        let intent = QuickAmountExpenseIntent()
        intent.amount = entry.config.amount
        intent.category = entry.config.category
        intent.notes = ""
        return intent
    }

    var body: some View {
        HStack(spacing: 0) {
            balancePanel
            Divider().padding(.vertical, 14).padding(.horizontal)
            actionPanel
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }

    // MARK: Left – balance summary

    private var balancePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let name = entry.accountName {
                Label(name, systemImage: "creditcard")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.bottom, 4)
            }

            if let balance = entry.primaryBalance {
                Text(balance.formatCurrency)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            } else {
                Text("No account")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text("Balance")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("This month")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.monthExpenses.formatCurrency)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .padding(.vertical, 14)
    }

    // MARK: Right – action buttons

    private var actionPanel: some View {
        VStack(spacing: 8) {
            Button(intent: quickAddIntent) {
                actionRow(
                    icon: "plus.circle.fill",
                    label: entry.config.label,
                    color: .accentColor
                )
            }
            .buttonStyle(.plain)

            Link(destination: URL(string: "mymoney://voiceExpense")!) {
                actionRow(icon: "mic.fill", label: "Voice", color: .orange)
            }

            Link(destination: URL(string: "mymoney://createTransaction")!) {
                actionRow(icon: "plus", label: "Type", color: .purple)
            }
        }
        .frame(width: 124)
        .padding(.trailing, 12)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func actionRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Widget definition

struct CaptureHubMediumWidget: Widget {
    let kind: String = "CaptureHubMediumWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuickExpenseWidgetConfig.self,
            provider: MediumWidgetProvider()
        ) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Expense Capture Hub")
        .description("Quick-add, voice record, or type an expense right from your home screen.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    CaptureHubMediumWidget()
} timeline: {
    MediumWidgetEntry(
        date: .now,
        config: QuickExpenseWidgetConfig(),
        primaryBalance: 24_500,
        accountName: "Primary",
        monthExpenses: 8_200
    )
}
