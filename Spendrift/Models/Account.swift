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
    /// The starred account. Voice, Shortcuts, and the widget post to it.
    var primary: Account? {
        first(where: { $0.isPrimary })
    }

    /// Stars `account` and clears every other one, so exactly one account is
    /// primary. Returns `true` when anything actually changed.
    @discardableResult
    func makePrimary(_ account: Account) -> Bool {
        var changed = false
        for existing in self {
            let shouldStar = existing.id == account.id
            guard existing.isPrimary != shouldStar else { continue }
            existing.isPrimary = shouldStar
            changed = true
        }
        return changed
    }

    /// A ledger holding any account holds exactly one primary: the stored star
    /// when there is one, otherwise the first account. Call after deleting,
    /// restoring, or saving accounts. Returns `true` when anything changed.
    @discardableResult
    func normalizePrimary() -> Bool {
        guard let anchor = primary ?? first else { return false }
        return makePrimary(anchor)
    }

    /// Moves the star off `account` onto the first other account in this array.
    /// No-op when `account` is not primary, or it is the only account.
    @discardableResult
    func handPrimary(awayFrom account: Account) -> Bool {
        guard account.isPrimary, count > 1 else { return false }
        guard let successor = first(where: { $0.id != account.id }) else { return false }
        return makePrimary(successor)
    }

    /// The accounts a delete at `offsets` is allowed to drop. Empty when the
    /// request covers every row, because one account must always remain.
    func deletable(at offsets: IndexSet) -> [Account] {
        let targets = offsets.sorted().filter { indices.contains($0) }.map { self[$0] }
        return targets.count < count ? targets : []
    }

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
