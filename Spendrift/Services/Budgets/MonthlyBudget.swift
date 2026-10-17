//
//  MonthlyBudget.swift
//  Spendrift
//
//  Two kinds of cap: one for the whole month, and one per expense category.
//  They are independent - category caps need not add up to the total. Income has
//  no cap. Caps repeat every month until changed, and apply to past months too
//  when the user looks back.
//

import Foundation

enum MonthlyBudget {
    /// `@AppStorage` key for the whole-month cap. Zero means no budget is set.
    static let totalKey = "spendrift.budget.total"

    static var total: Double {
        get { UserDefaults.standard.double(forKey: totalKey) }
        set { UserDefaults.standard.set(max(0, newValue.rounded()), forKey: totalKey) }
    }

    static func clearTotal() {
        UserDefaults.standard.set(0.0, forKey: totalKey)
    }

    /// Cap for a category, or zero when it is uncapped. Income never carries one.
    static func cap(for category: TransactionCategory?) -> Double {
        guard let category, category.type == .expense, category.monthlyBudget > 0 else { return 0 }
        return category.monthlyBudget
    }

    /// Every capped expense category, worst first, measured against one month.
    static func capped(
        in categories: [TransactionCategory],
        month: MonthSpendStats
    ) -> [CappedCategory] {
        categories
            .filter { cap(for: $0) > 0 }
            .map { category in
                CappedCategory(
                    category: category,
                    spent: month.spent(in: category),
                    cap: cap(for: category)
                )
            }
            .sorted { $0.used > $1.used }
    }

    /// Average spend of the last three completed months, rounded to the nearest 500.
    /// What the "use my average" chip on the total budget sheet offers.
    static func suggestedTotal(transactions: [Transaction], today: Date = Date()) -> Double {
        let months = completedMonthsBefore(today, count: 3)
            .map { MonthSpendStats(transactions: transactions, year: $0.year, month: $0.month, today: today).spent }
            .filter { $0 > 0 }
        guard !months.isEmpty else { return 0 }
        return ((months.reduce(0, +) / Double(months.count)) / 500).rounded() * 500
    }

    /// Average spend in one category over the last three completed months, to the nearest 100.
    static func suggestedCap(
        for category: TransactionCategory,
        transactions: [Transaction],
        today: Date = Date()
    ) -> Double {
        let months = completedMonthsBefore(today, count: 3)
            .map { MonthSpendStats(transactions: transactions, year: $0.year, month: $0.month, today: today).spent(in: category) }
            .filter { $0 > 0 }
        guard !months.isEmpty else { return 0 }
        return ((months.reduce(0, +) / Double(months.count)) / 100).rounded() * 100
    }

    /// Consecutive completed months, counting back from last month, where the category
    /// stayed under its current cap. Stops at the first month with no data.
    static func underBudgetStreak(
        for category: TransactionCategory,
        transactions: [Transaction],
        today: Date = Date()
    ) -> Int {
        let cap = cap(for: category)
        guard cap > 0 else { return 0 }
        var streak = 0
        for month in completedMonthsBefore(today, count: 12) {
            let stats = MonthSpendStats(transactions: transactions, year: month.year, month: month.month, today: today)
            if stats.transactions.isEmpty { break }
            guard stats.spent(in: category) <= cap else { break }
            streak += 1
        }
        return streak
    }

    private static func completedMonthsBefore(_ today: Date, count: Int) -> [(year: Int, month: Int)] {
        let calendar = Calendar.current
        return (1...count).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: today) else { return nil }
            return (date.year, date.month)
        }
    }
}

/// One capped category measured against a month.
struct CappedCategory: Identifiable {
    let category: TransactionCategory
    let spent: Double
    let cap: Double

    var id: UUID { category.id }
    /// Share of the cap used. Above 1 when over budget.
    var used: Double { cap > 0 ? spent / cap : 0 }
    var remaining: Double { cap - spent }
    var isOver: Bool { spent > cap }
}
