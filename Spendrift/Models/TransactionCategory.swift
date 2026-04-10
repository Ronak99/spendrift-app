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
    @Attribute(.unique) var id: UUID
    var name: String
    var type: TransactionType
    var createdOn: Date
    var icon: CategoryIcon
    
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

extension TransactionCategory {
    static func defaultCategories() -> [TransactionCategory] {
        [
            // Income
            TransactionCategory(
                name: "Dividend",
                type: .income,
                createdOn: Date(),
                icon: .dividend
            ),
            TransactionCategory(
                name: "Friends",
                type: .income,
                createdOn: Date(),
                icon: .friends
            ),
            TransactionCategory(
                name: "Salary",
                type: .income,
                createdOn: Date(),
                icon: .salary
            ),
            TransactionCategory(
                name: "Coupons",
                type: .income,
                createdOn: Date(),
                icon: .coupons
            ),
            TransactionCategory(
                name: "Refunds",
                type: .income,
                createdOn: Date(),
                icon: .refunds
            ),
            TransactionCategory(
                name: "Sale",
                type: .income,
                createdOn: Date(),
                icon: .sale
            ),
            // Expense
            TransactionCategory(
                name: "Bills",
                type: .expense,
                createdOn: Date(),
                icon: .bills
            ),
            TransactionCategory(
                name: "Education",
                type: .expense,
                createdOn: Date(),
                icon: .education
            ),
            TransactionCategory(
                name: "Entertainment",
                type: .expense,
                createdOn: Date(),
                icon: .entertainment
            ),
            TransactionCategory(
                name: "Food",
                type: .expense,
                createdOn: Date(),
                icon: .food
            ),
            TransactionCategory(
                name: "Health",
                type: .expense,
                createdOn: Date(),
                icon: .health
            ),
            TransactionCategory(
                name: "Home Hygiene",
                type: .expense,
                createdOn: Date(),
                icon: .home
            ),
            TransactionCategory(
                name: "Investments",
                type: .expense,
                createdOn: Date(),
                icon: .investments
            ),
            TransactionCategory(
                name: "Shopping",
                type: .expense,
                createdOn: Date(),
                icon: .shopping
            ),
            TransactionCategory(
                name: "Sport",
                type: .expense,
                createdOn: Date(),
                icon: .sport
            ),
            TransactionCategory(
                name: "Transportation",
                type: .expense,
                createdOn: Date(),
                icon: .transportation
            ),
            TransactionCategory(
                name: "Baby",
                type: .expense,
                createdOn: Date(),
                icon: .baby
            ),
            TransactionCategory(
                name: "Beauty",
                type: .expense,
                createdOn: Date(),
                icon: .beauty
            ),
            TransactionCategory(
                name: "Clothing",
                type: .expense,
                createdOn: Date(),
                icon: .clothing
            ),
            TransactionCategory(
                name: "Electronics",
                type: .expense,
                createdOn: Date(),
                icon: .electronics
            ),
            TransactionCategory(
                name: "Insurance",
                type: .expense,
                createdOn: Date(),
                icon: .insurance
            ),
            TransactionCategory(
                name: "Tax",
                type: .expense,
                createdOn: Date(),
                icon: .tax
            ),
            TransactionCategory(
                name: "Miscellaneous",
                type: .expense,
                createdOn: Date(),
                icon: .miscellaneous
            )
        ]
    }
}
