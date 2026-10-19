//
//  HomeInsights.swift
//  Spendrift
//
//  The "so what" under the Analytics numbers: a persona earned from the leading
//  category, and one-sentence insights that only appear when they are true.
//

import Foundation

/// One insight row: a glyph, a sentence, and an optional second line.
struct SpendInsight: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let detail: String?

    init(id: String, symbol: String, title: String, detail: String? = nil) {
        self.id = id
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }
}

/// A label earned from the category with the largest share of the month.
struct SpendPersona {
    let label: String
    let reason: String
    let category: TransactionCategory
}

enum HomeInsights {
    /// A category needs this much of the month before it names the user.
    private static let personaThreshold = 0.20

    /// Keyword to label. First match on the category name wins, so "Bills & Utilities"
    /// and "Electricity" both read as The Grown-up.
    private static let personaLabels: [(keyword: String, label: String)] = [
        ("food", "The Foodie"),
        ("restaurant", "The Foodie"),
        ("dining", "The Foodie"),
        ("rent", "The Nester"),
        ("home", "The Nester"),
        ("grocer", "The Home Chef"),
        ("transport", "The Commuter"),
        ("fuel", "The Commuter"),
        ("shop", "The Collector"),
        ("bill", "The Grown-up"),
        ("electric", "The Grown-up"),
        ("utilit", "The Grown-up"),
        ("travel", "The Wanderer"),
        ("hotel", "The Wanderer"),
        ("health", "The Self-Carer"),
        ("entertain", "The Regular"),
        ("subscription", "The Regular")
    ]

    static func persona(for month: MonthSpendStats) -> SpendPersona? {
        guard let top = month.categorySpend.first, month.spent > 0 else { return nil }
        let share = month.share(of: top.amount)
        let percent = Int((share * 100).rounded())

        guard share >= personaThreshold else {
            return SpendPersona(
                label: "The Balanced",
                reason: "No category above 20%. \(top.category.name) leads at \(percent)%.",
                category: top.category
            )
        }

        var reason = "\(top.category.name) is \(percent)% of your spend."
        if let merchant = month.topMerchant(in: top.category), merchant.count > 1 {
            reason += " \(merchant.name) alone, \(merchant.count) times."
        }
        return SpendPersona(label: label(for: top.category.name), reason: reason, category: top.category)
    }

    private static func label(for categoryName: String) -> String {
        let needle = categoryName.lowercased()
        if let match = personaLabels.first(where: { needle.contains($0.keyword) }) {
            return match.label
        }
        return "The \(categoryName) Person"
    }

    /// Insight rows for the picked month, in reading order.
    static func rows(
        month: MonthSpendStats,
        previous: MonthSpendStats,
        allTransactions: [Transaction],
        today: Date = Date()
    ) -> [SpendInsight] {
        var rows: [SpendInsight] = []

        if let rhythm = weekdayRhythm(month) { rows.append(rhythm) }
        if let mover = biggestMover(month: month, previous: previous) { rows.append(mover) }
        if let recurring = recurringCharges(month: month, allTransactions: allTransactions) {
            rows.append(recurring)
        }

        return rows
    }

    // MARK: Rows

    private static func weekdayRhythm(_ month: MonthSpendStats) -> SpendInsight? {
        let split = month.weekendVsWeekday
        guard split.weekend > 0 || split.weekday > 0 else { return nil }
        let priciest = month.priciestWeekday
        let title: String
        if split.weekday > 0, split.weekend >= split.weekday {
            title = String(format: "Weekends cost %.1f× weekdays", split.weekend / split.weekday)
        } else if split.weekend > 0 {
            title = String(format: "Weekdays cost %.1f× weekends", split.weekday / split.weekend)
        } else {
            title = "Everything so far landed on a weekday"
        }
        let dayName = Calendar.current.weekdaySymbols[priciest]
        let suffix = month.isCurrent ? " so far" : ""
        return SpendInsight(
            id: "rhythm",
            symbol: "calendar",
            title: title,
            detail: "\(dayName) is your priciest day, \(month.byWeekday[priciest].formatCurrencyRounded)\(suffix)"
        )
    }

    private static func biggestMover(month: MonthSpendStats, previous: MonthSpendStats) -> SpendInsight? {
        struct Mover {
            let category: TransactionCategory
            let current: Double
            let previous: Double
            var difference: Double { current - previous }
        }

        let movers = month.categorySpend
            .map { Mover(category: $0.category, current: $0.amount, previous: previous.spent(in: $0.category)) }
            .filter { $0.previous > 0 }
            .sorted { abs($0.difference) > abs($1.difference) }

        guard let top = movers.first,
              let change = MonthSpendStats.change(from: top.previous, to: top.current),
              change != 0 else { return nil }

        let previousMonthName = monthName(previous.month)
        var detail = ""
        if let merchant = month.topMerchant(in: top.category), merchant.count > 1 {
            detail = "Mostly \(merchant.name). "
        }
        if let second = movers.dropFirst().first,
           let secondChange = MonthSpendStats.change(from: second.previous, to: second.current),
           secondChange != 0 {
            detail += "\(second.category.name) went \(secondChange > 0 ? "up" : "down") \(abs(secondChange))%"
        }

        return SpendInsight(
            id: "mover",
            symbol: "chart.line.uptrend.xyaxis",
            title: "\(top.category.name) is \(change > 0 ? "up" : "down") \(abs(change))% on \(previousMonthName)",
            detail: detail.isEmpty ? nil : detail.trimmingCharacters(in: .whitespaces)
        )
    }

    /// Same note, same amount, 26 to 34 days apart, at least twice: a subscription or a bill.
    private static func recurringCharges(
        month: MonthSpendStats,
        allTransactions: [Transaction]
    ) -> SpendInsight? {
        struct Key: Hashable {
            let note: String
            let amount: Int
        }

        let expenses = allTransactions.filter { $0.isPersisted && $0.transactionType == .expense }
        var byKey: [Key: [Date]] = [:]
        for transaction in expenses {
            let note = transaction.notes.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !note.isEmpty else { continue }
            byKey[Key(note: note, amount: Int(transaction.amount.rounded())), default: []].append(transaction.date)
        }

        var names: [String] = []
        var total = 0.0
        for (key, dates) in byKey {
            let sorted = dates.sorted()
            guard sorted.count >= 2 else { continue }
            let isMonthly = zip(sorted, sorted.dropFirst()).contains { earlier, later in
                let gap = Calendar.current.dateComponents([.day], from: earlier, to: later).day ?? 0
                return (26...34).contains(gap)
            }
            guard isMonthly else { continue }
            let thisMonth = sorted.filter { $0.year == month.year && $0.month == month.month }
            guard !thisMonth.isEmpty else { continue }
            names.append(key.note.capitalized)
            total += Double(key.amount) * Double(thisMonth.count)
        }

        guard !names.isEmpty else { return nil }
        let listed = names.sorted().prefix(3).joined(separator: ", ")
        let suffix = names.count > 3 ? " and \(names.count - 3) more" : ""
        return SpendInsight(
            id: "recurring",
            symbol: "arrow.triangle.2.circlepath",
            title: "\(names.count) recurring charge\(names.count == 1 ? "" : "s"), \(total.formatCurrencyRounded) this month",
            detail: listed + suffix
        )
    }

    static func monthName(_ month: Int) -> String {
        let symbols = Calendar.current.monthSymbols
        guard month >= 1, month <= symbols.count else { return "" }
        return symbols[month - 1]
    }

    static func shortMonthName(_ month: Int) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        guard month >= 1, month <= symbols.count else { return "" }
        return symbols[month - 1]
    }
}
