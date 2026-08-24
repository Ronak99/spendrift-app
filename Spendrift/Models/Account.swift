//
//  Account.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var balance: Double = 0
    var createdOn: Date = Date()
    var icon: AccountIcon = AccountIcon.unknown
    var isPrimary: Bool = false
    /// Updated whenever a transaction is saved with this account (manual, shortcut, voice, or import).
    var lastUsedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]?
    
    var currentBalance: Double {
        let txns = (transactions ?? []).filter(\.isPersisted)
        let income = txns
            .filter { $0.transactionType == .income }
            .reduce(0) { $0 + $1.amount }
        let expense = txns
            .filter { $0.transactionType == .expense }
            .reduce(0) { $0 + $1.amount }
        return balance + income - expense
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        balance: Double = 0,
        createdOn: Date = Date(),
        icon: AccountIcon = .unknown,
        isPrimary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.createdOn = createdOn
        self.icon = icon
        self.isPrimary = isPrimary
        self.transactions = []
    }
}

extension Array where Element == Account {
    /// Most recently used first; never-used at the end, preserving order from `@Query(sort: \.name)`.
    func sortedByLastUsage() -> [Account] {
        sorted { a, b in
            switch (a.lastUsedAt, b.lastUsedAt) {
            case let (aDate?, bDate?): return aDate > bDate
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return false
            }
        }
    }
}
