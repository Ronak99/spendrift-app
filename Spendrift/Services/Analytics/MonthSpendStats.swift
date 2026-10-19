//
//  MonthSpendStats.swift
//  Spendrift
//
//  Everything Home shows about one month, computed once from the ledger: the
//  cumulative curve, the category split, weekday behaviour, repeated merchants
//  and no-spend days. Pure values, no formatting, so the views stay thin.
//

import Foundation

struct MonthSpendStats {
    /// Spend filed under one category in this month.
    struct CategorySpend: Identifiable {
        let category: TransactionCategory
        let amount: Double

        var id: UUID { category.id }
    }

    /// A note that repeats inside one category, which is as close to a merchant
    /// as a hand-written ledger gets.
    struct MerchantCount {
        let name: String
        let count: Int
    }

    let year: Int
    let month: Int
    /// True when this is the month the user is living in, so the curve projects
    /// and the forward-looking tiles apply.
    let isCurrent: Bool
    /// Days in the month.
    let days: Int
    /// Days of the month that have happened: every day for a past month.
    let elapsed: Int
    let transactions: [Transaction]
    let spent: Double
    let income: Double
    /// Expense per calendar day, indexed by day of month. Index 0 is unused.
    let byDay: [Double]
    /// Categories with any expense, largest first.
    let categorySpend: [CategorySpend]
    /// Expense per weekday, indexed 0 = Sunday.
    let byWeekday: [Double]
    /// How many of each weekday have elapsed, indexed 0 = Sunday.
    let weekdayCounts: [Int]
    /// Repeated notes per category id, largest count first.
    let merchantsByCategory: [UUID: [MerchantCount]]
    let noSpendDays: Int
    let bestNoSpendStreak: Int

    init(transactions all: [Transaction], year: Int, month: Int, today: Date = Date()) {
        self.year = year
        self.month = month

        let calendar = Calendar.current
        let isCurrent = today.year == year && today.month == month
        self.isCurrent = isCurrent

        let anchor = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? today
        let days = calendar.range(of: .day, in: .month, for: anchor)?.count ?? 30
        self.days = days
        self.elapsed = isCurrent ? min(days, today.day) : days

        // Two date comparisons per row instead of two calendar lookups: Home builds a
        // dozen of these per render, so this filter is the hot path.
        let range = MonthRef(year: year, month: month).dateRange(calendar: calendar)
        let list = all.filter { transaction in
            transaction.isPersisted && range.contains(transaction.date)
        }
        self.transactions = list.sorted { $0.date > $1.date }

        var spent = 0.0
        var income = 0.0
        var byDay = [Double](repeating: 0, count: days + 1)
        var byWeekday = [Double](repeating: 0, count: 7)
        var amountByCategory: [UUID: Double] = [:]
        var categoryByID: [UUID: TransactionCategory] = [:]
        var merchantCounts: [UUID: [String: Int]] = [:]

        for transaction in list {
            guard transaction.transactionType == .expense else {
                income += transaction.amount
                continue
            }
            spent += transaction.amount
            let day = calendar.component(.day, from: transaction.date)
            if day >= 1, day <= days {
                byDay[day] += transaction.amount
            }
            byWeekday[calendar.component(.weekday, from: transaction.date) - 1] += transaction.amount

            guard let category = transaction.category, !category.isDeleted else { continue }
            categoryByID[category.id] = category
            amountByCategory[category.id, default: 0] += transaction.amount

            let merchant = transaction.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !merchant.isEmpty else { continue }
            merchantCounts[category.id, default: [:]][merchant, default: 0] += 1
        }

        self.spent = spent
        self.income = income
        self.byDay = byDay
        self.byWeekday = byWeekday
        self.categorySpend = amountByCategory
            .compactMap { id, amount in
                guard let category = categoryByID[id] else { return nil }
                return CategorySpend(category: category, amount: amount)
            }
            .sorted { $0.amount > $1.amount }
        self.merchantsByCategory = merchantCounts.mapValues { counts in
            counts
                .map { MerchantCount(name: $0.key, count: $0.value) }
                .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
        }

        var weekdayCounts = [Int](repeating: 0, count: 7)
        var noSpend = 0
        var streak = 0
        var best = 0
        for day in 1...max(1, elapsed) where day <= elapsed {
            if byDay[day] == 0 {
                noSpend += 1
                streak += 1
                best = max(best, streak)
            } else {
                streak = 0
            }
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                weekdayCounts[calendar.component(.weekday, from: date) - 1] += 1
            }
        }
        self.weekdayCounts = weekdayCounts
        self.noSpendDays = noSpend
        self.bestNoSpendStreak = best
    }

    // MARK: Derived

    var saved: Double { income - spent }

    var dailyAverage: Double { elapsed > 0 ? spent / Double(elapsed) : 0 }

    /// What the month ends at if the rest of it spends like the part that has happened.
    var projectedTotal: Double { isCurrent ? dailyAverage * Double(days) : spent }

    var daysLeft: Int { max(0, days - elapsed) }

    var isEmpty: Bool { transactions.isEmpty }

    func spent(in category: TransactionCategory) -> Double {
        categorySpend.first { $0.category.id == category.id }?.amount ?? 0
    }

    func share(of amount: Double) -> Double {
        spent > 0 ? amount / spent : 0
    }

    /// Cumulative expense from the 1st through `day`.
    func cumulative(through day: Int) -> Double {
        guard day >= 1 else { return 0 }
        return byDay[1...min(day, days)].reduce(0, +)
    }

    /// Running total for every elapsed day, starting at day 1.
    var cumulativeByDay: [Double] {
        guard elapsed >= 1 else { return [] }
        var running = 0.0
        return (1...elapsed).map { day in
            running += byDay[day]
            return running
        }
    }

    /// Calendar day with the most spend, and what it cost.
    var biggestDay: (day: Int, amount: Double)? {
        guard elapsed >= 1 else { return nil }
        var best = 1
        for day in 1...elapsed where byDay[day] > byDay[best] { best = day }
        guard byDay[best] > 0 else { return nil }
        return (best, byDay[best])
    }

    /// Average spend on a weekend day, and on a weekday.
    var weekendVsWeekday: (weekend: Double, weekday: Double) {
        let weekendTotal = byWeekday[0] + byWeekday[6]
        let weekendDays = weekdayCounts[0] + weekdayCounts[6]
        let weekdayTotal = (1...5).reduce(0.0) { $0 + byWeekday[$1] }
        let weekdayDays = (1...5).reduce(0) { $0 + weekdayCounts[$1] }
        return (
            weekendDays > 0 ? weekendTotal / Double(weekendDays) : 0,
            weekdayDays > 0 ? weekdayTotal / Double(weekdayDays) : 0
        )
    }

    /// Weekday that costs the most in total, 0 = Sunday.
    var priciestWeekday: Int {
        var best = 0
        for index in 1..<7 where byWeekday[index] > byWeekday[best] { best = index }
        return best
    }

    func topMerchant(in category: TransactionCategory) -> MerchantCount? {
        merchantsByCategory[category.id]?.first
    }

    /// Start of this month, for date comparisons and pickers.
    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    /// Percentage change from `previous` to `current`, rounded. Nil when there is no base.
    static func change(from previous: Double, to current: Double) -> Int? {
        guard previous > 0 else { return nil }
        return Int(((current - previous) / previous * 100).rounded())
    }
}

/// Which month a screen is looking at. Home and the Transactions tab each keep their own.
struct MonthRef: Equatable, Hashable {
    var year: Int
    var month: Int

    static func of(_ date: Date) -> MonthRef {
        MonthRef(year: date.year, month: date.month)
    }

    var previous: MonthRef {
        month == 1 ? MonthRef(year: year - 1, month: 12) : MonthRef(year: year, month: month - 1)
    }

    var name: String { HomeInsights.monthName(month) }

    var shortName: String { HomeInsights.shortMonthName(month) }

    /// "October", or "October 2025" once the year stops being the current one.
    func title(relativeTo today: Date) -> String {
        year == today.year ? name : "\(name) \(year)"
    }

    /// "Oct 2026", the form the Transactions tab label takes.
    var shortTitle: String { "\(shortName) \(year)" }

    func stats(from transactions: [Transaction], today: Date = Date()) -> MonthSpendStats {
        MonthSpendStats(transactions: transactions, year: year, month: month, today: today)
    }

    /// From the first instant of the month up to, not including, the next month's.
    func dateRange(calendar: Calendar = .current) -> Range<Date> {
        let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return start..<end
    }

    func contains(_ date: Date) -> Bool {
        dateRange().contains(date)
    }
}
