//
//  CategoryMatcher.swift
//  Spendrift
//
//  Created by Cursor on 23/03/26.
//

import Foundation

struct CategoryMatchResult {
    let category: TransactionCategory?
    let confidence: Double
    let reason: String
}

enum CategoryMatcher {
    // Keys align with the curated default category names (RON-82).
    private static let keywordMap: [String: [String]] = [
        "Transport": ["metro", "cab", "uber", "ola", "bus", "train", "rickshaw", "auto", "taxi", "fuel", "petrol", "diesel"],
        "Groceries": ["grocery", "groceries", "supermarket", "market", "bigbasket", "zepto", "blinkit", "instamart", "dmart", "vegetables"],
        "Shopping": ["shopping", "mall", "store", "amazon", "flipkart", "myntra", "clothes", "clothing"],
        "Food": ["food", "snack", "dinner", "lunch", "breakfast", "restaurant", "zomato", "swiggy", "cafe", "coffee"],
        "Bills & Utilities": ["bill", "bills", "electricity", "water", "internet", "recharge", "broadband", "gas", "dth", "insurance", "premium"],
        "Rent": ["rent", "landlord"],
        "Health": ["doctor", "medicine", "medical", "hospital", "pharmacy", "gym", "fitness"],
        "Salary": ["salary", "paycheck", "pay day", "bonus"],
        "Other Income": ["refund", "cashback", "dividend", "interest", "reimbursement"]
    ]

    static func match(
        intent: ParsedTransactionIntent,
        categories: [TransactionCategory]
    ) -> CategoryMatchResult {
        guard let type = intent.transactionType else {
            return CategoryMatchResult(category: nil, confidence: 0.2, reason: "Transaction type not detected")
        }

        let targetType: CategoryType = type == .expense ? .expense : .income
        let filtered = categories.filter { $0.type == targetType }
        guard !filtered.isEmpty else {
            return CategoryMatchResult(category: nil, confidence: 0, reason: "No categories for detected type")
        }

        let text = intent.normalizedText

        for category in filtered {
            if let keywords = keywordMap[category.name],
               keywords.contains(where: { text.contains($0) || intent.hints.contains($0) }) {
                return CategoryMatchResult(category: category, confidence: 0.92, reason: "Keyword matched \(category.name)")
            }
        }

        // Fuzzy token overlap fallback
        let tokens = Set(intent.hints + intent.normalizedText.split(separator: " ").map(String.init))
        var best: (TransactionCategory, Double)?
        for category in filtered {
            let categoryTokens = Set(category.name.lowercased().split(separator: " ").map(String.init))
            let common = tokens.intersection(categoryTokens).count
            let score = categoryTokens.isEmpty ? 0 : Double(common) / Double(categoryTokens.count)
            if let currentBest = best {
                if score > currentBest.1 {
                    best = (category, score)
                }
            } else {
                best = (category, score)
            }
        }

        if let best, best.1 >= 0.4 {
            return CategoryMatchResult(category: best.0, confidence: min(0.55 + best.1, 0.84), reason: "Fuzzy category match")
        }

        return CategoryMatchResult(category: nil, confidence: 0.25, reason: "No reliable category match")
    }
}
