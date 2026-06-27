//
//  CategoryResolverTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

struct CategoryResolverTests {
    private let categories: [TransactionCategory] = [
        TransactionCategory(name: "Transport", type: .expense, icon: .transportation),
        TransactionCategory(name: "Other Income", type: .income, icon: .sale),
        TransactionCategory(name: "Groceries", type: .expense, icon: .groceries)
    ]

    @Test
    func resolvesExactNameMatch() {
        let match = CategoryResolver.resolve(
            categoryName: "Groceries",
            notes: "Weekly shop",
            type: .expense,
            categories: categories
        )
        #expect(match?.name == "Groceries")
    }

    @Test
    func resolvesLegacyAliasName() {
        let match = CategoryResolver.resolve(
            categoryName: "Transportation",
            notes: "Metro",
            type: .expense,
            categories: categories
        )
        #expect(match?.name == "Transport")
    }

    @Test
    func resolvesFromNotesWhenCategoryMissing() {
        let match = CategoryResolver.resolve(
            categoryName: nil,
            notes: "BigBasket grocery delivery",
            type: .expense,
            categories: categories
        )
        #expect(match?.name == "Groceries")
    }
}
