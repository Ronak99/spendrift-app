//
//  LedgerSearch.swift
//  Spendrift
//
//  One search over the whole ledger: category, account and merchant names,
//  transaction notes, amounts ("500", ">1000", "over 1000") and dates ("october",
//  "last month"). Prefix and one-letter typos match, so "electrcity" still finds
//  Electricity. The active tab never changes the results.
//

import Foundation
import SwiftUI

// MARK: Query

/// A raw query split into the parts that filter and the words that match.
struct SearchQuery {
    let raw: String
    /// Words left after the filters were lifted out.
    let tokens: [String]
    let filters: [SearchFilter]
    /// Set when the whole query is one number, which searches amounts instead of text.
    let amount: Double?

    var isEmpty: Bool { tokens.isEmpty && filters.isEmpty && amount == nil }
}

/// A constraint parsed out of the query, shown as a removable pill.
struct SearchFilter: Identifiable, Equatable {
    enum Kind: Equatable {
        case minimum(Double)
        case maximum(Double)
        case dates(from: Date, to: Date)
    }

    let id = UUID()
    let kind: Kind
    let label: String
    /// The words this filter consumed, so removing the pill can edit them out of the query.
    let matchedText: String

    var isDate: Bool {
        if case .dates = kind { return true }
        return false
    }

    static func == (lhs: SearchFilter, rhs: SearchFilter) -> Bool {
        lhs.id == rhs.id
    }

    func accepts(_ transaction: Transaction) -> Bool {
        switch kind {
        case .minimum(let value): return transaction.amount >= value
        case .maximum(let value): return transaction.amount <= value
        case .dates(let from, let to): return transaction.date >= from && transaction.date <= to
        }
    }
}

// MARK: Entities

/// A category, account or merchant the query names. The best one leads the results.
struct SearchEntity: Identifiable {
    enum Kind {
        case category(TransactionCategory)
        case account(Account)
        case merchant(name: String, category: TransactionCategory?)
    }

    let kind: Kind
    let score: Int
    /// Transactions filed under this entity that pass the query's filters.
    var transactions: [Transaction]

    var id: String {
        switch kind {
        case .category(let category): "category-\(category.id)"
        case .account(let account): "account-\(account.id)"
        case .merchant(let name, _): "merchant-\(name.lowercased())"
        }
    }

    var name: String {
        switch kind {
        case .category(let category): category.name
        case .account(let account): account.name
        case .merchant(let name, _): name
        }
    }

    var color: Color {
        switch kind {
        case .category(let category): CategoryEnamel.color(for: category)
        case .account(let account): AccountEnamel.color(for: account.icon)
        case .merchant(_, let category): CategoryEnamel.color(for: category)
        }
    }

    var symbol: String {
        switch kind {
        case .category(let category): category.icon.systemImageName
        case .account(let account): account.icon.systemImageName
        case .merchant: "storefront"
        }
    }

    /// Caption over the name in the top-hit card.
    var kindLabel: String {
        switch kind {
        case .category(let category):
            return category.type == .income ? "Category · Income" : "Category"
        case .account:
            return "Account"
        case .merchant(_, let category):
            guard let category else { return "Merchant" }
            return "Merchant · \(category.name)"
        }
    }

    var isCategory: Bool {
        if case .category = kind { return true }
        return false
    }

    var isAccount: Bool {
        if case .account = kind { return true }
        return false
    }

    var isMerchant: Bool {
        if case .merchant = kind { return true }
        return false
    }

    /// The expense category a "Move to" offer would file a row under, when the
    /// top hit is an expense category.
    var moveTarget: TransactionCategory? {
        if case .category(let category) = kind, category.type == .expense { return category }
        return nil
    }

    func owns(_ transaction: Transaction) -> Bool {
        switch kind {
        case .category(let category): transaction.category?.id == category.id
        case .account(let account): transaction.account?.id == account.id
        case .merchant(let name, _):
            transaction.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(name) == .orderedSame
        }
    }
}

// MARK: Results

struct SearchResults {
    let query: SearchQuery
    var entities: [SearchEntity] = []
    var top: SearchEntity?
    /// Entities other than the top hit, split by kind.
    var categories: [SearchEntity] = []
    var accounts: [SearchEntity] = []
    var merchants: [SearchEntity] = []
    /// Transactions that belong to the top hit, shown inside its card instead of flooding the list.
    var folded: [Transaction] = []
    /// Everything else that matched.
    var rest: [Transaction] = []
    /// Every matching transaction, which is what the scope counts report.
    var all: [Transaction] = []
    /// Set when the query was a bare amount.
    var exactAmount: [Transaction] = []
    var closeToAmount: [Transaction] = []

    var isAmountSearch: Bool { query.amount != nil }

    var isEmpty: Bool {
        top == nil && all.isEmpty && exactAmount.isEmpty && closeToAmount.isEmpty
    }
}

// MARK: Engine

enum LedgerSearch {
    /// Amount matches within this band of the number typed are offered as "Close to".
    private static let closeBand = 0.05

    // MARK: Parsing

    static func parse(_ raw: String, today: Date = Date()) -> SearchQuery {
        var working = " " + raw.lowercased() + " "
        var filters: [SearchFilter] = []

        func take(_ pattern: String, _ build: ([String]) -> SearchFilter?) {
            guard let match = firstMatch(pattern, in: working) else { return }
            if let filter = build(match.groups) {
                filters.append(filter)
            }
            working = working.replacingOccurrences(of: match.text, with: " ")
        }

        take(#"\s(over|above|more than|>)\s*[^\d]?\s*([\d,]+)\s"#) { groups in
            guard groups.count > 2, let value = number(groups[2]) else { return nil }
            return SearchFilter(
                kind: .minimum(value),
                label: "Over \(value.formatCurrencyRounded)",
                matchedText: groups[0]
            )
        }
        take(#"\s(under|below|less than|<)\s*[^\d]?\s*([\d,]+)\s"#) { groups in
            guard groups.count > 2, let value = number(groups[2]) else { return nil }
            return SearchFilter(
                kind: .maximum(value),
                label: "Under \(value.formatCurrencyRounded)",
                matchedText: groups[0]
            )
        }
        take(#"\s(this month|last month|last week|this week|today|yesterday)\s"#) { groups in
            guard groups.count > 1 else { return nil }
            return relativeRange(groups[1], today: today)
        }
        take(
            #"\s(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\s+(20\d\d))?\s"#
        ) { groups in
            guard groups.count > 1 else { return nil }
            return monthRange(groups[1], year: groups.count > 2 ? groups[2] : "", today: today)
        }

        let trimmed = working.trimmingCharacters(in: .whitespaces)
        var amount: Double?
        if let bare = firstMatch(#"^[^\d]?\s*([\d,]+(?:\.\d+)?)$"#, in: trimmed),
           bare.groups.count > 1,
           let value = number(bare.groups[1]) {
            amount = value
            working = " "
        }

        return SearchQuery(
            raw: raw.trimmingCharacters(in: .whitespaces),
            tokens: tokenize(working),
            filters: filters,
            amount: amount
        )
    }

    static func tokenize(_ text: String) -> [String] {
        normalize(text)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let cleaned = folded.map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(cleaned)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    // MARK: Matching

    /// A token matches a word by prefix, or by one edit once it is long enough for
    /// that to be safe rather than noisy.
    static func matches(token: String, word: String) -> Bool {
        if word.hasPrefix(token) { return true }
        guard token.count >= 5 else { return false }
        if editDistance(token, word) <= 1 { return true }
        if word.count > token.count {
            let head = String(word.prefix(token.count))
            return editDistance(token, head) <= 1
        }
        return false
    }

    static func textMatches(_ text: String, tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return false }
        let words = normalize(text).split(separator: " ").map(String.init)
        return tokens.allSatisfy { token in
            words.contains { matches(token: token, word: $0) }
        }
    }

    /// Levenshtein distance, stopped early when the lengths rule a one-edit match out.
    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        if abs(lhs.count - rhs.count) > 1 { return 2 }
        let a = Array(lhs)
        let b = Array(rhs)
        var previous = Array(0...b.count)
        for i in 1...max(1, a.count) where i <= a.count {
            var current = [i]
            for j in 1...max(1, b.count) where j <= b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current.append(min(previous[j] + 1, current[j - 1] + 1, substitution))
            }
            previous = current
        }
        return previous[b.count]
    }

    // MARK: Running

    static func run(
        query: SearchQuery,
        transactions: [Transaction],
        categories: [TransactionCategory],
        accounts: [Account],
        today: Date = Date()
    ) -> SearchResults {
        var results = SearchResults(query: query)
        let ledger = transactions.filter(\.isPersisted)

        if let amount = query.amount {
            let pool = ledger.filter { passes(filters: query.filters, $0) }
            results.exactAmount = pool.filter { $0.amount.rounded() == amount.rounded() }
            results.closeToAmount = pool.filter {
                $0.amount.rounded() != amount.rounded() && abs($0.amount - amount) <= amount * closeBand
            }
            results.all = results.exactAmount + results.closeToAmount
            return results
        }

        var entities: [SearchEntity] = []
        if !query.tokens.isEmpty {
            for category in categories {
                let score = entityScore(name: category.name, tokens: query.tokens)
                guard score > 0 else { continue }
                entities.append(SearchEntity(kind: .category(category), score: score, transactions: []))
            }
            for account in accounts {
                let score = entityScore(name: account.name, tokens: query.tokens)
                guard score > 0 else { continue }
                entities.append(SearchEntity(kind: .account(account), score: score, transactions: []))
            }
            for merchant in merchants(in: ledger) {
                let score = entityScore(name: merchant.name, tokens: query.tokens)
                guard score > 0 else { continue }
                entities.append(
                    SearchEntity(
                        kind: .merchant(name: merchant.name, category: merchant.category),
                        score: score,
                        transactions: []
                    )
                )
            }
        }

        entities = entities.map { entity in
            var filled = entity
            filled.transactions = ledger.filter { entity.owns($0) && passes(filters: query.filters, $0) }
            return filled
        }
        entities.sort { lhs, rhs in
            lhs.score != rhs.score
                ? lhs.score > rhs.score
                : lhs.transactions.count > rhs.transactions.count
        }

        results.entities = entities
        results.top = entities.first
        let topID = entities.first?.id
        results.categories = entities.filter { $0.isCategory && $0.id != topID }
        results.accounts = entities.filter { $0.isAccount && $0.id != topID }
        results.merchants = entities.filter { $0.isMerchant && $0.id != topID }

        let matched = ledger.filter { transaction in
            guard passes(filters: query.filters, transaction) else { return false }
            if query.tokens.isEmpty { return !query.filters.isEmpty }
            return textMatches(searchText(transaction), tokens: query.tokens)
        }
        results.all = matched

        if let top = results.top {
            let foldedIDs = Set(top.transactions.map(\.id))
            results.folded = top.transactions
            results.rest = matched.filter { !foldedIDs.contains($0.id) }
        } else {
            results.rest = matched
        }
        return results
    }

    /// Expense totals for the last 12 months, oldest first. The strip under a top hit.
    static func monthlySeries(
        for transactions: [Transaction],
        today: Date = Date()
    ) -> [(month: MonthRef, amount: Double)] {
        let calendar = Calendar.current
        return (0..<12).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: today) else { return nil }
            let ref = MonthRef.of(date)
            let range = ref.dateRange(calendar: calendar)
            let total = transactions
                .filter { $0.transactionType == .expense && range.contains($0.date) }
                .reduce(0) { $0 + $1.amount }
            return (ref, total)
        }
    }

    static func expenseTotal(_ transactions: [Transaction]) -> Double {
        transactions.filter { $0.transactionType == .expense }.reduce(0) { $0 + $1.amount }
    }

    // MARK: Helpers

    private static func passes(filters: [SearchFilter], _ transaction: Transaction) -> Bool {
        filters.allSatisfy { $0.accepts(transaction) }
    }

    private static func searchText(_ transaction: Transaction) -> String {
        [
            transaction.notes,
            transaction.category?.name ?? "",
            transaction.account?.name ?? ""
        ].joined(separator: " ")
    }

    private static func entityScore(name: String, tokens: [String]) -> Int {
        let normalized = normalize(name)
        let full = tokens.joined(separator: " ")
        guard !full.isEmpty else { return 0 }
        if normalized == full { return 100 }
        if normalized.hasPrefix(full) { return 85 }
        if textMatches(name, tokens: tokens) { return 70 }
        return 0
    }

    /// Repeated expense notes, which is what a hand-written ledger has instead of merchants.
    static func merchants(in transactions: [Transaction]) -> [(name: String, category: TransactionCategory?, count: Int)] {
        var byKey: [String: (name: String, category: TransactionCategory?, count: Int)] = [:]
        for transaction in transactions where transaction.transactionType == .expense {
            let name = transaction.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            if var existing = byKey[key] {
                existing.count += 1
                byKey[key] = existing
            } else {
                byKey[key] = (name, transaction.category, 1)
            }
        }
        return byKey.values.sorted { $0.count > $1.count }
    }

    private static func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ""))
    }

    private static func relativeRange(_ phrase: String, today: Date) -> SearchFilter? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfToday) ?? today

        var from = startOfToday
        var to = endOfToday
        switch phrase {
        case "this month":
            from = today.startOfMonth
        case "last month":
            let previous = today.previousMonth
            from = previous.startOfMonth
            to = previous.endOfMonth
        case "last week":
            from = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        case "this week":
            from = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? startOfToday
        case "today":
            break
        case "yesterday":
            from = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
            to = calendar.date(byAdding: .second, value: -1, to: startOfToday) ?? startOfToday
        default:
            return nil
        }
        return SearchFilter(
            kind: .dates(from: from, to: to),
            label: phrase.prefix(1).uppercased() + phrase.dropFirst(),
            matchedText: phrase
        )
    }

    private static func monthRange(_ name: String, year: String, today: Date) -> SearchFilter? {
        let prefix = String(name.prefix(3))
        guard let index = Calendar.current.shortMonthSymbols.firstIndex(where: {
            $0.lowercased().hasPrefix(prefix)
        }) else { return nil }
        let month = index + 1
        // A month with no year means the most recent one that has already happened.
        let resolvedYear = Int(year) ?? (month <= today.month ? today.year : today.year - 1)
        let calendar = Calendar.current
        guard let from = calendar.date(from: DateComponents(year: resolvedYear, month: month, day: 1)),
              let to = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: from) else { return nil }
        return SearchFilter(
            kind: .dates(from: from, to: to),
            label: "\(HomeInsights.monthName(month)) \(resolvedYear)",
            matchedText: year.isEmpty ? name : "\(name) \(year)"
        )
    }

    private static func firstMatch(
        _ pattern: String,
        in text: String
    ) -> (text: String, groups: [String])? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        var groups: [String] = []
        for index in 0..<match.numberOfRanges {
            guard let groupRange = Range(match.range(at: index), in: text) else {
                groups.append("")
                continue
            }
            groups.append(String(text[groupRange]).trimmingCharacters(in: .whitespaces))
        }
        return (String(text[Range(match.range, in: text)!]), groups)
    }
}
