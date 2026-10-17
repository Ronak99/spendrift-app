//
//  MonthlyBudgetTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

struct MonthlyBudgetTests {
    @Test
    func amountKeepsOnlyDigitsWhateverTheRegionSeparator() {
        #expect(MonthlyBudget.amount(from: "60000") == 60000)
        #expect(MonthlyBudget.amount(from: "60,000") == 60000)
        #expect(MonthlyBudget.amount(from: "60.000") == 60000)
        #expect(MonthlyBudget.amount(from: "60 000") == 60000)
        #expect(MonthlyBudget.amount(from: "₹8,200") == 8200)
    }

    @Test
    func amountOfNothingIsNoBudget() {
        #expect(MonthlyBudget.amount(from: "") == 0)
        #expect(MonthlyBudget.amount(from: "abc") == 0)
    }

    @Test
    func incomeCategoriesNeverCarryACap() {
        let salary = TransactionCategory(name: "Salary", type: .income, icon: .salary)
        salary.monthlyBudget = 5000
        #expect(MonthlyBudget.cap(for: salary) == 0)

        let food = TransactionCategory(name: "Food", type: .expense, icon: .food)
        food.monthlyBudget = 5000
        #expect(MonthlyBudget.cap(for: food) == 5000)
        #expect(MonthlyBudget.cap(for: nil) == 0)
    }

    @Test
    func monthRangeCoversTheWholeMonthAndNothingElse() throws {
        let calendar = Calendar.current
        let range = MonthRef(year: 2026, month: 2).dateRange(calendar: calendar)

        let first = try #require(calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)))
        let lastMinute = try #require(calendar.date(from: DateComponents(year: 2026, month: 2, day: 28, hour: 23, minute: 59)))
        let nextMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        let lastMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 23)))

        #expect(range.contains(first))
        #expect(range.contains(lastMinute))
        #expect(!range.contains(nextMonth))
        #expect(!range.contains(lastMonth))
    }

    @Test
    func decemberRangeEndsAtTheNewYear() throws {
        let calendar = Calendar.current
        let range = MonthRef(year: 2025, month: 12).dateRange(calendar: calendar)
        let newYear = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        #expect(range.upperBound == newYear)
    }
}
