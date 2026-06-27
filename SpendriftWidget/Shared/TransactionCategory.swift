//
//  TransactionCategory.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftData
 
@Model
final class TransactionCategory {
    var id: UUID = UUID()
    var name: String = ""
    var type: TransactionType = TransactionType.expense
    var createdOn: Date = Date()
    var icon: CategoryIcon = CategoryIcon.unknown
    /// Updated whenever a transaction is saved with this category (manual or shortcut).
    var lastUsedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]?
    
    init(id: UUID = UUID(), name: String, type: TransactionType, createdOn: Date = Date(), icon: CategoryIcon = .unknown) {
        self.id = id
        self.name = name
        self.type = type
        self.createdOn = createdOn
        self.icon = icon
        self.transactions = []
    }
}

extension Array where Element == TransactionCategory {
    /// Most recently used first; never-used at the end, preserving alphabetical order from `@Query(sort: \.name)`.
    func sortedByLastUsage() -> [TransactionCategory] {
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
