//
//  TransactionType+Resolved.swift
//  Spendrift
//

import Foundation

extension TransactionType {
    /// Maps backend / legacy raw strings to a supported transaction direction.
    static func resolved(from raw: String?, default defaultValue: TransactionType = .expense) -> TransactionType {
        guard let raw else { return defaultValue }
        if raw == "none" { return .expense }
        return TransactionType(rawValue: raw) ?? defaultValue
    }

    init(categoryType: CategoryType) {
        self = categoryType == .income ? .income : .expense
    }
}

extension CategoryType {
    init(transactionType: TransactionType) {
        self = transactionType == .income ? .income : .expense
    }
}
