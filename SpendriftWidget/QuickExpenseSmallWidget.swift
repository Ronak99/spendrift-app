//
//  QuickExpenseSmallWidget.swift
//  SpendriftWidget
//
//  Created by Cursor on 05/04/26.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline entry

struct SmallWidgetEntry: TimelineEntry {
    let date: Date
    let config: QuickExpenseWidgetConfig
    let primaryBalance: Double?
    let accountName: String?
    let monthlyExpense: Double?
}

// MARK: - Timeline provider

struct SmallWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = QuickExpenseWidgetConfig
    typealias Entry = SmallWidgetEntry

    func placeholder(in context: Context) -> SmallWidgetEntry {
        SmallWidgetEntry(
            date: .now,
            config: QuickExpenseWidgetConfig(),
            primaryBalance: 24_500,
            accountName: "Primary",
            monthlyExpense: 999,
        )
    }

    func snapshot(for config: QuickExpenseWidgetConfig, in context: Context) async -> SmallWidgetEntry {
        let account = try? WidgetDataStore.fetchPrimaryAccount()
        let monthlyExpenses = (try? WidgetDataStore.fetchMonthExpenses()) ?? 0;
        return SmallWidgetEntry(
            date: .now,
            config: config,
            primaryBalance: account?.balance,
            accountName: account?.name,
            monthlyExpense: monthlyExpenses,
        )
    }

    func timeline(
        for config: QuickExpenseWidgetConfig,
        in context: Context
    ) async -> Timeline<SmallWidgetEntry> {
        let account = try? WidgetDataStore.fetchPrimaryAccount()
        let monthlyExpenses = (try? WidgetDataStore.fetchMonthExpenses()) ?? 0;
        let entry = SmallWidgetEntry(
            date: .now,
            config: config,
            primaryBalance: account?.balance,
            accountName: account?.name,
            monthlyExpense: monthlyExpenses,
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

// MARK: - View

struct SmallWidgetView: View {
    let entry: SmallWidgetEntry

    private var voiceExpenseURL: URL {
        URL(string: "spendrift://voiceExpense")!
    }
    
    private var typeExpenseUrl: URL {
        URL(string: "spendrift://createTransaction")!
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                HStack {
                    if let name = entry.accountName {
                        Text(name)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    if let balance = entry.primaryBalance {
                        Text(balance.formatCurrency)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
                
                HStack {
                    Text("Expenses")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let monthlyExpense = entry.monthlyExpense {
                        Text(monthlyExpense.formatCurrency)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
                
                Spacer()

                HStack(spacing: 8) {
                    Link(destination: typeExpenseUrl) {
                        smallActionTile(systemImage: "plus", title: "Type")
                    }

                    Link(destination: voiceExpenseURL) {
                        smallActionTile(systemImage: "mic.fill", title: "Speak")
                    }
                }
            }
            .padding(10)
        }
    }

    private func smallActionTile(systemImage: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: 30)
        .padding(.vertical, 10)
        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Widget definition

struct QuickExpenseSmallWidget: Widget {
    let kind: String = "QuickExpenseSmallWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuickExpenseWidgetConfig.self,
            provider: SmallWidgetProvider()
        ) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(Color.accentColor, for: .widget)
        }
        .configurationDisplayName("Quick Expense")
        .description("Type an amount with the system keyboard or jump into voice capture.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    QuickExpenseSmallWidget()
} timeline: {
    SmallWidgetEntry(
        date: .now,
        config: QuickExpenseWidgetConfig(),
        primaryBalance: 24_500,
        accountName: "Primary",
        monthlyExpense: 12_00,
    )
}
