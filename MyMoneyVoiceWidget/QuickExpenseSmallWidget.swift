//
//  QuickExpenseSmallWidget.swift
//  MyMoneyVoiceWidget
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
            accountName: "Primary"
        )
    }

    func snapshot(for config: QuickExpenseWidgetConfig, in context: Context) async -> SmallWidgetEntry {
        let account = try? WidgetDataStore.fetchPrimaryAccount()
        return SmallWidgetEntry(
            date: .now,
            config: config,
            primaryBalance: account?.balance,
            accountName: account?.name
        )
    }

    func timeline(
        for config: QuickExpenseWidgetConfig,
        in context: Context
    ) async -> Timeline<SmallWidgetEntry> {
        let account = try? WidgetDataStore.fetchPrimaryAccount()
        let entry = SmallWidgetEntry(
            date: .now,
            config: config,
            primaryBalance: account?.balance,
            accountName: account?.name
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

// MARK: - View

struct SmallWidgetView: View {
    let entry: SmallWidgetEntry

    private var quickAddIntent: QuickAmountExpenseIntent {
        var intent = QuickAmountExpenseIntent()
        intent.amount = entry.config.amount
        intent.category = entry.config.category
        intent.notes = ""
        return intent
    }

    var body: some View {
        Button(intent: quickAddIntent) {
            ZStack {
                Color.accentColor
                    .ignoresSafeArea()

                VStack(spacing: 6) {
                    Image(systemName: "indianrupeesign.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(entry.config.amount.formatCurrency)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(entry.config.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)

                    if let balance = entry.primaryBalance {
                        Divider()
                            .overlay(.white.opacity(0.35))
                            .padding(.horizontal, 16)

                        Text(balance.formatCurrency)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .padding(12)
            }
        }
        .buttonStyle(.plain)
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
        .configurationDisplayName("Quick Add Expense")
        .description("Log an expense with a single tap — no app required.")
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
        accountName: "Primary"
    )
}
