//
//  PeriodAnalyticsCard.swift
//  Spendrift
//
//  Home's period summary: the three ledger totals plus the daily spend curve.
//  Replaces the bare summary strip that used to sit in the pinned header, so the
//  figures scroll away with the ledger instead of holding a band of the screen.
//

import SwiftUI
import Charts

struct PeriodAnalyticsCard: View {
    let transactions: [Transaction]
    let periodStart: Date
    let periodEnd: Date
    let expenses: String
    let income: String
    let savings: String
    let savingsValue: Double
    let onOpenAnalytics: () -> Void

    /// Palette blue, matching the daily trend chart on the analytics screen.
    private let trendColor = Color(hex: CategoryPalette.hex(matching: .blue))

    private var dailySpending: [DailySpendPoint] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: periodStart)
        let endDay = calendar.startOfDay(for: periodEnd)

        let totalsByDay = Dictionary(grouping: transactions.filter { $0.isExpense }) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        .mapValues { day in
            day.reduce(0) { $0 + $1.amount }
        }

        var days: [Date] = []
        var cursor = start
        while cursor <= endDay {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return days.map { DailySpendPoint(date: $0, amount: totalsByDay[$0] ?? 0) }
    }

    /// Headroom above the tallest day so the curve never touches the card's top edge.
    /// A period with no spend still needs a non-empty domain, or the line collapses.
    private var spendDomain: ClosedRange<Double> {
        let peak = dailySpending.map(\.amount).max() ?? 0
        return 0...(peak > 0 ? peak * 1.15 : 1)
    }

    private var averageDailySpend: Double {
        let days = dailySpending
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.amount } / Double(days.count)
    }

    private var accessibilitySummary: String {
        "Expenses \(expenses), income \(income), savings \(savings). Daily spend averages \(averageDailySpend.formatCurrency)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            totals

            VStack(alignment: .leading, spacing: 8) {
                Divider()
                chart
                legend
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenAnalytics)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Period summary")
        .accessibilityValue(accessibilitySummary)
        .accessibilityHint("Opens analytics")
        .accessibilityIdentifier("periodAnalyticsCard")
    }

    private var totals: some View {
        HStack(alignment: .top, spacing: 12) {
            total("Expenses", value: expenses, color: CategoryEnamel.expense, alignment: .leading)

            Spacer(minLength: 0)

            total("Income", value: income, color: CategoryEnamel.income, alignment: .center)

            Spacer(minLength: 0)

            total(
                "Savings",
                value: savings,
                color: savingsValue >= 0 ? CategoryEnamel.income : CategoryEnamel.expense,
                alignment: .trailing
            )
        }
    }

    private func total(
        _ label: String,
        value: String,
        color: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var chart: some View {
        Chart(dailySpending) { day in
            AreaMark(
                x: .value("Date", day.date),
                y: .value("Spent", day.amount)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [trendColor.opacity(0.30), trendColor.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", day.date),
                y: .value("Spent", day.amount)
            )
            .foregroundStyle(trendColor)
            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: spendDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private var legend: some View {
        HStack {
            Text("Daily spend")
            Spacer(minLength: 8)
            Text("\(averageDailySpend.formatCurrency) avg")
                .monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}

private struct DailySpendPoint: Identifiable {
    let date: Date
    let amount: Double

    var id: Date { date }
}

#Preview {
    let food = TransactionCategory(name: "Food", type: .expense, icon: .food, colorHex: "#FF6B6B")
    let account = Account(name: "Fi", balance: 0)
    let calendar = Calendar.current
    let start = calendar.date(byAdding: .day, value: -11, to: Date()) ?? Date()
    let sample = (0..<12).map { offset in
        Transaction(
            notes: "Sample",
            amount: Double(120 + (offset * 37) % 260),
            date: calendar.date(byAdding: .day, value: offset, to: start) ?? Date(),
            transactionType: .expense,
            category: food,
            account: account
        )
    }

    return List {
        Section {
            PeriodAnalyticsCard(
                transactions: sample,
                periodStart: start,
                periodEnd: Date(),
                expenses: "$2,480",
                income: "$4,200",
                savings: "$1,720",
                savingsValue: 1720,
                onOpenAnalytics: {}
            )
            .listRowInsets(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
            .frame(height: 300)
        } header: {
            Text("Analytics")
        }
    }
    .listStyle(.insetGrouped)
}
