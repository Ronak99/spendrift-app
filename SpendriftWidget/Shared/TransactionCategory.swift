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
    var isDefault: Bool = false
    var sortOrder: Int = 0
    /// Updated whenever a transaction is saved with this category (manual or shortcut).
    var lastUsedAt: Date?
    /// User-picked display colour as `#RRGGBB`. Nil means fall back to the name-based map.
    var colorHex: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]?

    init(
        id: UUID = UUID(),
        name: String,
        type: TransactionType,
        createdOn: Date = Date(),
        icon: CategoryIcon = .unknown,
        isDefault: Bool = false,
        sortOrder: Int = 0,
        colorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.createdOn = createdOn
        self.icon = icon
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.colorHex = colorHex
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
