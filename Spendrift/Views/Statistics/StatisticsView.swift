//
//  StatisticsView.swift
//  Spendrift
//
//  Created by Ronak Punase on 03/08/25.
//

import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    var periodViewModel: TransactionViewModel

    private let categoryPalette: [Color] = [
        .blue, .purple, .pink, .orange, .teal, .green, .indigo, .cyan, .mint, .yellow, .brown
    ]

    init(periodViewModel: TransactionViewModel) {
        self.periodViewModel = periodViewModel
        _allTransactions = Query(sort: \Transaction.date, order: .reverse)
    }

    private var periodTransactions: [Transaction] {
        allTransactions.filter { transaction in
            transaction.isPersisted &&
            transaction.date >= periodViewModel.periodStart &&
            transaction.date <= periodViewModel.periodEnd
        }
    }

    private var expenseTransactions: [Transaction] {
        periodTransactions.filter { $0.transactionType == .expense }
    }

    private var incomeTransactions: [Transaction] {
        periodTransactions.filter { $0.transactionType == .income }
    }

    private var totalSpent: Double {
        expenseTransactions.reduce(0) { $0 + $1.amount }
    }

    private var totalIncome: Double {
        incomeTransactions.reduce(0) { $0 + $1.amount }
    }

    private var netSavings: Double {
        totalIncome - totalSpent
    }

    private var averageDailySpend: Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: periodViewModel.periodStart)
        let end = calendar.startOfDay(for: periodViewModel.periodEnd)
        guard let dayComponent = calendar.dateComponents([.day], from: start, to: end).day else {
            return 0
        }
        let dayCount = dayComponent + 1
        guard dayCount > 0 else { return 0 }
        return totalSpent / Double(dayCount)
    }

    private var largestCategory: CategorySpendingData? {
        categoryBreakdown.first
    }

    private var categoryBreakdown: [CategorySpendingData] {
        let grouped = Dictionary(grouping: expenseTransactions) { transaction in
            let name = transaction.category?.name ?? "Uncategorized"
            let iconName = transaction.category?.icon.systemImageName ?? "questionmark.circle"
            return "\(name)||\(iconName)"
        }

        let rows = grouped.map { key, transactions in
            let components = key.components(separatedBy: "||")
            let name = components.first ?? "Uncategorized"
            let iconName = components.count > 1 ? components[1] : "questionmark.circle"
            let amount = transactions.reduce(0) { $0 + $1.amount }
            return (name: name, iconName: iconName, amount: amount)
        }
        .sorted { $0.amount > $1.amount }

        guard totalSpent > 0 else { return [] }

        return rows.enumerated().map { index, row in
            CategorySpendingData(
                name: row.name,
                iconName: row.iconName,
                amount: row.amount,
                share: row.amount / totalSpent,
                color: categoryPalette[index % categoryPalette.count]
            )
        }
    }

    private var dailySpending: [DailySpendingData] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: periodViewModel.periodStart)
        let endDay = calendar.startOfDay(for: periodViewModel.periodEnd)

        let grouped = Dictionary(grouping: expenseTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        let totalsByDay = grouped.mapValues { transactions in
            transactions.reduce(0) { $0 + $1.amount }
        }

        var days: [Date] = []
        var d = start
        while d <= endDay {
            days.append(d)
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }

        return days.map { date in
            DailySpendingData(
                date: date,
                amount: totalsByDay[date] ?? 0
            )
        }
    }

    private var weekdaySpending: [WeekdaySpendingData] {
        let calendar = Calendar.current
        let totalsByWeekday = Dictionary(grouping: expenseTransactions) { transaction in
            calendar.component(.weekday, from: transaction.date)
        }
        .mapValues { transactions in
            transactions.reduce(0) { $0 + $1.amount }
        }

        let weekdayOrder = Array(calendar.firstWeekday ... 7) + Array(1 ..< calendar.firstWeekday)

        return weekdayOrder.enumerated().map { position, weekday in
            let symbolIndex = weekday - 1
            let symbols = calendar.shortWeekdaySymbols
            let label = symbols.indices.contains(symbolIndex) ? symbols[symbolIndex] : "Day \(position + 1)"
            return WeekdaySpendingData(
                label: label,
                amount: totalsByWeekday[weekday] ?? 0
            )
        }
    }

    var body: some View {
        @Bindable var periodViewModel = periodViewModel
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CapsuleDateSelector(
                        period: periodViewModel.periodGranularity,
                        title: periodViewModel.capsuleTitle,
                        date: periodViewModel.selectedDate,
                        isCurrentPeriod: periodViewModel.isCurrentPeriod,
                        onPrevious: { periodViewModel.decrementPeriod() },
                        onNext: { periodViewModel.incrementPeriod() },
                        onToday: { periodViewModel.goToCurrentPeriod() },
                        onJumpToDate: { periodViewModel.goToDate($0) }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if periodTransactions.isEmpty {
                        emptyMonthState
                    } else {
                        summaryGrid

                        if expenseTransactions.isEmpty {
                            analyticsCard(
                                title: "No Spending Yet",
                                subtitle: "This period has transactions, but none of them are expenses."
                            ) {
                                ContentUnavailableView(
                                    "No expense data for \(periodViewModel.periodDescription)",
                                    systemImage: "chart.pie",
                                    description: Text("Add an expense transaction to unlock category and trend charts.")
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        } else {
                            spendingBreakdownCard
                            dailyTrendCard
                            weekdayPatternCard
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics")
            .toolbar {
                if !periodTransactions.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        TransactionPeriodToolbarMenu(period: $periodViewModel.periodGranularity)
                    }
                }
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(
                title: "Spent",
                value: totalSpent.formatCurrency,
                caption: "\(expenseTransactions.count) expense transactions",
                color: .red
            )
            summaryCard(
                title: "Income",
                value: totalIncome.formatCurrency,
                caption: "\(incomeTransactions.count) income transactions",
                color: .green
            )
            summaryCard(
                title: "Net",
                value: netSavings.formatCurrency,
                caption: netSavings >= 0 ? "You saved money" : "You overspent",
                color: netSavings >= 0 ? .green : .orange
            )
            summaryCard(
                title: "Daily Avg",
                value: averageDailySpend.formatCurrency,
                caption: "Average spend per day",
                color: .blue
            )
        }
        .padding(.horizontal)
    }

    private var spendingBreakdownCard: some View {
        analyticsCard(
            title: "Spending Breakdown",
            subtitle: "Category share for \(periodViewModel.periodDescription)"
        ) {
            ZStack {
                Chart(categoryBreakdown) { category in
                    SectorMark(
                        angle: .value("Amount", category.amount),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .cornerRadius(6)
                    .foregroundStyle(category.color)
                }
                .frame(height: 260)
                .chartLegend(.hidden)

                VStack(spacing: 6) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalSpent.formatCurrency)
                        .font(.title3.weight(.bold))
                    if let largestCategory {
                        Text("\(largestCategory.name) \(largestCategory.percentageText)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(spacing: 12) {
                ForEach(categoryBreakdown) { category in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 10, height: 10)

                        Image(systemName: category.iconName)
                            .foregroundStyle(category.color)
                            .frame(width: 18)

                        Text(category.name)
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        Text(category.percentageText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(category.amount.formatCurrency)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
    }

    private var dailyTrendCard: some View {
        analyticsCard(
            title: "Daily Spending Trend",
            subtitle: "See how your expenses changed over \(periodViewModel.periodDescription)"
        ) {
            Chart(dailySpending) { day in
                AreaMark(
                    x: .value("Date", day.date),
                    y: .value("Spent", day.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.35), Color.blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", day.date),
                    y: .value("Spent", day.amount)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6))
            }
        }
    }

    private var weekdayPatternCard: some View {
        analyticsCard(
            title: "Weekday Pattern",
            subtitle: "Which days of the week absorb most of your spend"
        ) {
            Chart(weekdaySpending) { weekday in
                BarMark(
                    x: .value("Weekday", weekday.label),
                    y: .value("Spent", weekday.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(8)
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }

    private var emptyMonthState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("No transactions in \(periodViewModel.periodDescription)")
                .font(.headline)

            Text("Add some transactions for this period to unlock your analytics dashboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
        .padding(.top, 48)
    }

    private func summaryCard(title: String, value: String, caption: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func analyticsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }
}

private struct CategorySpendingData: Identifiable {
    let name: String
    let iconName: String
    let amount: Double
    let share: Double
    let color: Color

    var id: String {
        name
    }

    var percentageText: String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }
}

private struct DailySpendingData: Identifiable {
    let date: Date
    let amount: Double

    var id: Date {
        date
    }
}

private struct WeekdaySpendingData: Identifiable {
    let label: String
    let amount: Double

    var id: String {
        label
    }
}

#Preview {
    StatisticsView(periodViewModel: TransactionViewModel())
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
