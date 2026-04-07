//
//  TransactionIntentParser.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import Foundation

struct ParsedTransactionIntent {
    let originalText: String
    let normalizedText: String
    let amount: Double?
    let transactionType: TransactionType?
    let notes: String
    let hints: [String]
    let confidence: Double
}

enum TransactionIntentParser {
    private static let expenseSignals: [String] = [
        "paid", "spent", "pay", "purchase", "purchased", "bought", "booked", "debit", "expense"
    ]

    private static let incomeSignals: [String] = [
        "received", "got", "income", "salary", "refund", "credited", "credit", "bonus", "dividend"
    ]

    static func parse(_ text: String) -> ParsedTransactionIntent {
        let normalized = normalize(text)
        let amount = parseAmount(from: normalized)
        let type = parseType(from: normalized)
        let hints = extractHints(from: normalized)

        var confidence = 0.2
        if amount != nil { confidence += 0.35 }
        if type != nil { confidence += 0.3 }
        if !hints.isEmpty { confidence += 0.15 }

        return ParsedTransactionIntent(
            originalText: text,
            normalizedText: normalized,
            amount: amount,
            transactionType: type,
            notes: text.trimmingCharacters(in: .whitespacesAndNewlines),
            hints: hints,
            confidence: min(confidence, 0.95)
        )
    }

    static func normalize(_ text: String) -> String {
        var normalized = text.lowercased()
        let replacements: [(String, String)] = [
            ("₹", " rs "),
            ("rupees", " rs "),
            ("rupee", " rs "),
            ("inr", " rs "),
            ("rupaye", " rs "),
            ("Rupaye", " rs "),
        ]

        for replacement in replacements {
            normalized = normalized.replacingOccurrences(of: replacement.0, with: replacement.1)
        }

        let punctuation = CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "."))
        normalized = normalized.components(separatedBy: punctuation).joined(separator: " ")
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseAmount(from normalized: String) -> Double? {
        let pattern = #"(?:(?:rs)\s*)?(\d+(?:\.\d{1,2})?)(?:\s*rs)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        guard let match = regex.firstMatch(in: normalized, options: [], range: range),
              let amountRange = Range(match.range(at: 1), in: normalized) else {
            return nil
        }

        guard let value = Double(String(normalized[amountRange])), value > 0 else { return nil }
        return value
    }

    static func parseType(from normalized: String) -> TransactionType? {
        let words = Set(normalized.split(separator: " ").map(String.init))

        let expenseScore = expenseSignals.reduce(0) { score, signal in
            score + (words.contains(signal) || normalized.contains(signal) ? 1 : 0)
        }
        let incomeScore = incomeSignals.reduce(0) { score, signal in
            score + (words.contains(signal) || normalized.contains(signal) ? 1 : 0)
        }

        if expenseScore == 0 && incomeScore == 0 {
            if normalized.contains("to ") || normalized.contains("for ") || normalized.contains("in ") {
                return .expense
            }
            return nil
        }

        if expenseScore == incomeScore { return nil }
        return expenseScore > incomeScore ? .expense : .income
    }

    static func extractHints(from normalized: String) -> [String] {
        let stopWords: Set<String> = [
            "record", "of", "the", "a", "an", "i", "to", "for", "in", "on", "at", "my", "rs",
            "paid", "spent", "received", "got", "income", "expense", "was", "is"
        ]
        return normalized
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty && stopWords.contains($0) == false && Double($0) == nil }
    }
}
