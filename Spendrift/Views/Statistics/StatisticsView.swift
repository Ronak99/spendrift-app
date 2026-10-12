//
//  StatisticsView.swift
//  Spendrift
//
//  Created by Ronak Punase on 03/08/25.
//

import Charts
import SwiftData
import SwiftUI

struct TransactionAnalyticsContent: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    var periodViewModel: TransactionViewModel
    @Binding var drillCategory: TransactionCategory?

    /// Cumulative angle value reported by tapping a pie slice; mapped back to a category.
    @State private var selectedAngle: Double?

    init(periodViewModel: TransactionViewModel, drillCategory: Binding<TransactionCategory?>) {
        self.periodViewModel = periodViewModel
        self._drillCategory = drillCategory
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
        guard totalSpent > 0 else { return [] }

        let grouped = Dictionary(grouping: expenseTransactions) { $0.category?.id }

        let rows = grouped.map { _, transactions -> (category: TransactionCategory?, amount: Double) in
            let amount = transactions.reduce(0) { $0 + $1.amount }
            return (transactions.first?.category, amount)
        }
        .sorted { $0.amount > $1.amount }

        return rows.map { row in
            CategorySpendingData(
                category: row.category,
                name: row.category?.name ?? "Uncategorized",
                iconName: row.category?.icon.systemImageName ?? "questionmark.circle",
                amount: row.amount,
                share: row.amount / totalSpent,
                color: CategoryEnamel.color(for: row.category)
            )
        }
    }

    /// Maps a cumulative angle value (from `chartAngleSelection`) back to the slice it falls in.
    private func categoryData(atAngleValue value: Double) -> CategorySpendingData? {
        var cumulative = 0.0
        for item in categoryBreakdown {
            cumulative += item.amount
            if value <= cumulative { return item }
        }
        return categoryBreakdown.last
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

    private var peakDay: DailySpendingData? {
        guard let peak = dailySpending.max(by: { $0.amount < $1.amount }), peak.amount > 0 else {
            return nil
        }
        return peak
    }

    private var peakWeekdayLabel: String? {
        guard let peak = weekdaySpending.max(by: { $0.amount < $1.amount }), peak.amount > 0 else {
            return nil
        }
        return peak.label
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if periodTransactions.isEmpty {
                    emptyMonthState
                } else if expenseTransactions.isEmpty {
                    summaryGrid

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
                    summaryGrid
                    dailyTrendCard
                    weekdayPatternCard
                }
            }
            .foregroundStyle(AnalyticsTheme.ink)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .softScrollEdge()
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            summaryCard(
                title: "Spent",
                value: totalSpent.formatCurrency,
                caption: "\(expenseTransactions.count) expense transactions",
                dot: AnalyticsTheme.spent
            )
            summaryCard(
                title: "Income",
                value: totalIncome.formatCurrency,
                caption: "\(incomeTransactions.count) income transactions",
                dot: AnalyticsTheme.income
            )
            // Net is the one tile whose value keeps color: it says which way the period went.
            summaryCard(
                title: "Net",
                value: netSavings > 0 ? "+" + netSavings.formatCurrency : netSavings.formatCurrency,
                caption: netSavings >= 0 ? "You saved money" : "You overspent",
                valueColor: netSavings >= 0 ? AnalyticsTheme.income : AnalyticsTheme.spent
            )
            summaryCard(
                title: "Daily Avg",
                value: averageDailySpend.formatCurrency,
                caption: "Average spend per day",
                dot: AnalyticsTheme.accent
            )
        }
        .padding(.horizontal)
    }

    private var spendingBreakdownCard: some View {
        analyticsCard(
            title: "Spending Breakdown",
            subtitle: "Tap a category to see its transactions."
        ) {
            ZStack {
                Chart(categoryBreakdown) { category in
                    SectorMark(
                        angle: .value("Amount", category.amount),
                        innerRadius: .ratio(0.8),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(category.color)
                }
                .frame(height: 220)
                .chartLegend(.hidden)
                .chartAngleSelection(value: $selectedAngle)

                VStack(spacing: 4) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundStyle(AnalyticsTheme.inkSecondary)
                    Text(totalSpent.formatCurrency)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.3)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let largestCategory {
                        Text("\(largestCategory.name) · \(largestCategory.percentageText)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(largestCategory.color)
                    }
                }
                .frame(maxWidth: 140)
                .allowsHitTesting(false)
            }
            .padding(.vertical, 10)
            .onChange(of: selectedAngle) { _, newValue in
                guard let newValue else { return }
                if let target = categoryData(atAngleValue: newValue)?.category {
                    drillCategory = target
                }
                selectedAngle = nil
            }

            VStack(spacing: 0) {
                ForEach(Array(categoryBreakdown.enumerated()), id: \.element.id) { index, category in
                    Group {
                        if let target = category.category {
                            Button {
                                drillCategory = target
                            } label: {
                                categoryLegendRow(category, isDrillable: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            categoryLegendRow(category, isDrillable: false)
                        }
                    }
                    .overlay(alignment: .top) {
                        if index > 0 {
                            Rectangle()
                                .fill(AnalyticsTheme.grid)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func categoryLegendRow(_ category: CategorySpendingData, isDrillable: Bool) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(category.color.opacity(0.14))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: category.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(category.color)
                }

            VStack(spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(category.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(category.amount.formatCurrency)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    shareBar(share: category.share, color: category.color)
                    Text(category.percentageText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(AnalyticsTheme.inkSecondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AnalyticsTheme.inkTertiary)
                .opacity(isDrillable ? 1 : 0)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func shareBar(share: Double, color: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AnalyticsTheme.track)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(share, 0), 1))
            }
        }
        .frame(height: 4)
    }

    private var dailyTrendCard: some View {
        analyticsCard(
            title: "Daily Spending Trend",
            subtitle: "See how your expenses changed."
        ) {
            Chart {
                ForEach(dailySpending) { day in
                    AreaMark(
                        x: .value("Date", day.date),
                        y: .value("Spent", day.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AnalyticsTheme.accent.opacity(0.28), AnalyticsTheme.accent.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", day.date),
                        y: .value("Spent", day.amount)
                    )
                    .foregroundStyle(AnalyticsTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("Average", averageDailySpend))
                    .foregroundStyle(AnalyticsTheme.inkSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text("Avg \(averageDailySpend.formatCurrencyRounded)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AnalyticsTheme.inkSecondary)
                            .padding(.horizontal, 4)
                            .background(AnalyticsTheme.card)
                    }

                if let peakDay {
                    PointMark(
                        x: .value("Date", peakDay.date),
                        y: .value("Spent", peakDay.amount)
                    )
                    .symbolSize(220)
                    .foregroundStyle(AnalyticsTheme.accentGlow)

                    PointMark(
                        x: .value("Date", peakDay.date),
                        y: .value("Spent", peakDay.amount)
                    )
                    .symbolSize(70)
                    .foregroundStyle(AnalyticsTheme.accent)
                    .annotation(
                        position: .top,
                        spacing: 6,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        Text("\(peakDay.date.formatted(.dateTime.month(.abbreviated).day())) · \(peakDay.amount.formatCurrencyRounded)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(AnalyticsTheme.ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AnalyticsTheme.chip)
                                    .strokeBorder(AnalyticsTheme.edge, lineWidth: 1)
                            )
                    }
                }
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(AnalyticsTheme.grid)
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(AnalyticsTheme.inkSecondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(AnalyticsTheme.inkSecondary)
                }
            }
        }
    }

    private var weekdayPatternCard: some View {
        analyticsCard(
            title: "Weekday Pattern",
            subtitle: "On which day you spend the most."
        ) {
            // Only the heaviest day is solid, so the answer to the card's question reads first.
            Chart(weekdaySpending) { weekday in
                let isPeak = weekday.label == peakWeekdayLabel
                BarMark(
                    x: .value("Weekday", weekday.label),
                    y: .value("Spent", weekday.amount)
                )
                .foregroundStyle(isPeak ? AnalyticsTheme.accent : AnalyticsTheme.accentSoft)
                .cornerRadius(8)
                .annotation(position: .top, spacing: 6) {
                    if isPeak {
                        Text(weekday.amount.formatCurrencyRounded)
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(AnalyticsTheme.accent)
                            .fixedSize()
                    }
                }
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(AnalyticsTheme.grid)
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(AnalyticsTheme.inkSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            let isPeak = label == peakWeekdayLabel
                            Text(label)
                                .font(.system(size: 11, weight: isPeak ? .semibold : .regular))
                                .foregroundStyle(isPeak ? AnalyticsTheme.ink : AnalyticsTheme.inkSecondary)
                        }
                    }
                }
            }
        }
    }

    private var emptyMonthState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 42))
                .foregroundStyle(AnalyticsTheme.inkSecondary)

            Text("No transactions in \(periodViewModel.periodDescription)")
                .font(.headline)

            Text("Add some transactions for this period to unlock your analytics dashboard.")
                .font(.subheadline)
                .foregroundStyle(AnalyticsTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(cardSurface(cornerRadius: 24))
        .padding(.horizontal)
        .padding(.top, 48)
    }

    private func summaryCard(
        title: String,
        value: String,
        caption: String,
        dot: Color? = nil,
        valueColor: Color = AnalyticsTheme.ink
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let dot {
                    Circle()
                        .fill(dot)
                        .frame(width: 6, height: 6)
                }
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AnalyticsTheme.inkSecondary)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.3)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(caption)
                .font(.caption)
                .foregroundStyle(AnalyticsTheme.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardSurface(cornerRadius: 20))
    }

    private func cardSurface(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AnalyticsTheme.card)
            .strokeBorder(AnalyticsTheme.edge, lineWidth: 1)
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
                    .foregroundStyle(AnalyticsTheme.inkSecondary)
            }

            content()
        }
        .padding(20)
        .background(cardSurface(cornerRadius: 24))
        .padding(.horizontal)
    }
}

private struct CategorySpendingData: Identifiable {
    /// The underlying category, or `nil` for the synthetic "Uncategorized" bucket
    /// (which has no transactions view to drill into).
    let category: TransactionCategory?
    let name: String
    let iconName: String
    let amount: Double
    let share: Double
    let color: Color

    var id: String {
        category?.id.uuidString ?? "uncategorized"
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
    TransactionAnalyticsContent(
        periodViewModel: TransactionViewModel(),
        drillCategory: .constant(nil)
    )
    .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
