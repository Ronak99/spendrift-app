//
//  CategorySearchTests.swift
//  SpendriftTests
//

import Testing
@testable import Spendrift

struct CategorySearchTests {
    @Test
    func emptyOrBlankQueryKeepsEveryCategory() {
        let categories = TransactionCategory.defaultCategories()
        #expect(CategorySearch.filter(categories, query: "").count == categories.count)
        #expect(CategorySearch.filter(categories, query: "  ").count == categories.count)
    }

    @Test
    func nameMatchIgnoresCaseAndPartialTokens() {
        let food = TransactionCategory(name: "Food", type: .expense, icon: .food)
        #expect(CategorySearch.matches(food, query: "FOOD"))
        #expect(CategorySearch.matches(food, query: "foo"))
        #expect(!CategorySearch.matches(food, query: "rent"))
    }

    @Test
    func iconKeywordsFindTheRelatedCategory() {
        let food = TransactionCategory(name: "Food", type: .expense, icon: .food)
        #expect(CategorySearch.matches(food, query: "lunch"))
        let groceries = TransactionCategory(name: "Groceries", type: .expense, icon: .groceries)
        #expect(CategorySearch.matches(groceries, query: "basket"))
    }

    @Test
    func billsNameMatchDoesNotRequireTheAmpersand() {
        let bills = TransactionCategory(name: "Bills & Utilities", type: .expense, icon: .bills)
        #expect(CategorySearch.matches(bills, query: "util"))
        #expect(CategorySearch.matches(bills, query: "bills"))
    }

    @Test
    func otherTypeHitPointsAtIncomeFromExpense() {
        let categories = TransactionCategory.defaultCategories()
        let hit = CategorySearch.otherTypeHit(in: categories, query: "salary", excluding: .expense)
        #expect(hit?.type == .income)
        #expect(hit?.name == "Salary")
        #expect(hit?.count == 1)
    }

    @Test
    func otherTypeHitIsNilWhenNothingElseMatches() {
        let categories = TransactionCategory.defaultCategories()
        let hit = CategorySearch.otherTypeHit(in: categories, query: "zzzz", excluding: .expense)
        #expect(hit == nil)
    }
}
