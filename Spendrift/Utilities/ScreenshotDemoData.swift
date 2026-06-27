//
//  ScreenshotDemoData.swift
//  Spendrift
//
//  Rich April sample transactions for App Store screenshots. Enable by adding
//  `-ScreenshotDemo` to the scheme’s Arguments Passed On Launch (only seeds when
//  there are zero transactions and not when `-UITesting` is set).
//

import Foundation
import SwiftData

enum ScreenshotDemoData {
    static func seedIfNeeded(modelContext: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-ScreenshotDemo") else { return }
        guard !ProcessInfo.processInfo.arguments.contains("-UITesting") else { return }

        let txnDescriptor = FetchDescriptor<Transaction>()
        guard let existing = try? modelContext.fetch(txnDescriptor), existing.isEmpty else { return }

        ensureDefaultCategories(in: modelContext)
        guard let categories = try? modelContext.fetch(
            FetchDescriptor<TransactionCategory>(sortBy: [SortDescriptor(\.name)])
        ) else { return }

        let categoryByName = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0) })
        let accounts = ensureDemoAccounts(in: modelContext)
        guard !accounts.isEmpty else { return }

        let year = Calendar.current.component(.year, from: Date())

        for spec in transactionSpecs {
            guard let category = categoryByName[spec.categoryName], category.type == spec.type else {
                continue
            }
            let account = accounts[min(max(spec.accountIndex, 0), accounts.count - 1)]
            let date = makeDate(year: year, day: spec.day, hour: spec.hour, minute: spec.minute)
            let transaction = Transaction(
                notes: spec.notes,
                amount: spec.amount,
                date: date,
                transactionType: spec.type,
                category: category,
                account: account
            )
            modelContext.insert(transaction)
        }

        try? modelContext.save()
    }

    private static func ensureDefaultCategories(in context: ModelContext) {
        let descriptor = FetchDescriptor<TransactionCategory>()
        guard let rows = try? context.fetch(descriptor), rows.isEmpty else { return }
        for category in TransactionCategory.defaultCategories() {
            context.insert(category)
        }
        try? context.save()
    }

    private static func ensureDemoAccounts(in context: ModelContext) -> [Account] {
        let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.createdOn)])
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return existing
        }

        let primary = Account(
            name: "HDFC Savings",
            balance: 125_000,
            createdOn: Date(),
            icon: .bankAccountOne,
            isPrimary: true
        )
        let credit = Account(
            name: "Axis Credit Card",
            balance: 0,
            createdOn: Date(),
            icon: .mastercard,
            isPrimary: false
        )
        let cash = Account(
            name: "Cash Wallet",
            balance: 2_000,
            createdOn: Date(),
            icon: .wallet,
            isPrimary: false
        )
        context.insert(primary)
        context.insert(credit)
        context.insert(cash)
        try? context.save()
        return [primary, credit, cash]
    }

    private static func makeDate(year: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 4
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private struct Spec {
        let day: Int
        let hour: Int
        let minute: Int
        let notes: String
        let amount: Double
        let type: TransactionType
        let categoryName: String
        let accountIndex: Int
    }

    /// April-only data mapped onto the curated default category set (RON-82): multiple
    /// income sources, varied expense categories, uneven daily totals, and mixed weekdays.
    private static let transactionSpecs: [Spec] = [
        // Income
        Spec(day: 1, hour: 9, minute: 5, notes: "Salary — ACME Corp", amount: 92_500, type: .income, categoryName: "Salary", accountIndex: 0),
        Spec(day: 1, hour: 10, minute: 40, notes: "Q1 dividend — mutual fund", amount: 2_180, type: .income, categoryName: "Other Income", accountIndex: 0),
        Spec(day: 4, hour: 19, minute: 12, notes: "Friend repaid weekend trip", amount: 4_200, type: .income, categoryName: "Other Income", accountIndex: 2),
        Spec(day: 11, hour: 15, minute: 30, notes: "Flipkart refund — footwear", amount: 1_899, type: .income, categoryName: "Other Income", accountIndex: 1),
        Spec(day: 19, hour: 12, minute: 0, notes: "Sold desk lamp — OLX", amount: 1_800, type: .income, categoryName: "Other Income", accountIndex: 2),
        Spec(day: 22, hour: 8, minute: 45, notes: "Grocery cashback + bank offer", amount: 640, type: .income, categoryName: "Other Income", accountIndex: 0),
        Spec(day: 28, hour: 9, minute: 10, notes: "Performance bonus — April", amount: 18_000, type: .income, categoryName: "Salary", accountIndex: 0),

        // Food — eating out & ordering in
        Spec(day: 2, hour: 8, minute: 15, notes: "Blue Tokai + croissant", amount: 485, type: .expense, categoryName: "Food", accountIndex: 2),
        Spec(day: 3, hour: 13, minute: 40, notes: "Office thali — lunch", amount: 220, type: .expense, categoryName: "Food", accountIndex: 2),
        Spec(day: 5, hour: 21, minute: 18, notes: "Swiggy — dinner for two", amount: 620, type: .expense, categoryName: "Food", accountIndex: 1),
        Spec(day: 7, hour: 11, minute: 50, notes: "Sunday brunch — Smoke House", amount: 2_850, type: .expense, categoryName: "Food", accountIndex: 1),
        Spec(day: 12, hour: 19, minute: 22, notes: "Zomato — weekend craving", amount: 910, type: .expense, categoryName: "Food", accountIndex: 1),
        Spec(day: 15, hour: 12, minute: 35, notes: "Chaayos + sandwich", amount: 340, type: .expense, categoryName: "Food", accountIndex: 2),
        Spec(day: 18, hour: 20, minute: 8, notes: "Dinner — Burma Burma", amount: 1_680, type: .expense, categoryName: "Food", accountIndex: 1),
        Spec(day: 21, hour: 8, minute: 55, notes: "Filter coffee stall", amount: 120, type: .expense, categoryName: "Food", accountIndex: 2),
        Spec(day: 24, hour: 13, minute: 5, notes: "Cafe — work session", amount: 560, type: .expense, categoryName: "Food", accountIndex: 2),
        Spec(day: 29, hour: 21, minute: 15, notes: "Late-night maggi run", amount: 180, type: .expense, categoryName: "Food", accountIndex: 2),

        // Groceries — quick-commerce & weekly stock-up
        Spec(day: 2, hour: 20, minute: 5, notes: "BigBasket — weekly stock-up", amount: 3_240, type: .expense, categoryName: "Groceries", accountIndex: 1),
        Spec(day: 8, hour: 7, minute: 20, notes: "Zepto — milk & eggs", amount: 380, type: .expense, categoryName: "Groceries", accountIndex: 1),
        Spec(day: 26, hour: 19, minute: 40, notes: "Instamart — snacks", amount: 890, type: .expense, categoryName: "Groceries", accountIndex: 1),

        // Transport
        Spec(day: 2, hour: 17, minute: 30, notes: "Metro smart-card top-up", amount: 500, type: .expense, categoryName: "Transport", accountIndex: 2),
        Spec(day: 4, hour: 9, minute: 12, notes: "Uber — airport drop", amount: 890, type: .expense, categoryName: "Transport", accountIndex: 1),
        Spec(day: 9, hour: 18, minute: 45, notes: "Rapido — commute home", amount: 165, type: .expense, categoryName: "Transport", accountIndex: 2),
        Spec(day: 14, hour: 7, minute: 50, notes: "Uber Intercity — return leg", amount: 2_400, type: .expense, categoryName: "Transport", accountIndex: 1),
        Spec(day: 19, hour: 16, minute: 20, notes: "Shell — fuel fill", amount: 3_450, type: .expense, categoryName: "Transport", accountIndex: 1),
        Spec(day: 27, hour: 8, minute: 5, notes: "Metro + autos — rainy week", amount: 720, type: .expense, categoryName: "Transport", accountIndex: 2),

        // Rent
        Spec(day: 1, hour: 8, minute: 0, notes: "Apartment rent — April", amount: 28_000, type: .expense, categoryName: "Rent", accountIndex: 0),

        // Bills & Utilities
        Spec(day: 3, hour: 10, minute: 0, notes: "Electricity — BESCOM", amount: 3_280, type: .expense, categoryName: "Bills & Utilities", accountIndex: 0),
        Spec(day: 6, hour: 11, minute: 15, notes: "JioFiber — broadband", amount: 899, type: .expense, categoryName: "Bills & Utilities", accountIndex: 1),
        Spec(day: 16, hour: 9, minute: 30, notes: "Society maintenance", amount: 4_500, type: .expense, categoryName: "Bills & Utilities", accountIndex: 0),
        Spec(day: 9, hour: 8, minute: 20, notes: "LIC premium — April", amount: 4_266, type: .expense, categoryName: "Bills & Utilities", accountIndex: 0),

        // Shopping & lifestyle
        Spec(day: 5, hour: 16, minute: 10, notes: "Amazon — desk organizer", amount: 1_150, type: .expense, categoryName: "Shopping", accountIndex: 1),
        Spec(day: 10, hour: 14, minute: 55, notes: "Nykaa — skincare restock", amount: 2_640, type: .expense, categoryName: "Shopping", accountIndex: 1),
        Spec(day: 13, hour: 17, minute: 25, notes: "H&M — summer shirt", amount: 1_999, type: .expense, categoryName: "Shopping", accountIndex: 1),
        Spec(day: 20, hour: 12, minute: 40, notes: "Croma — USB-C hub", amount: 2_799, type: .expense, categoryName: "Shopping", accountIndex: 1),
        Spec(day: 11, hour: 16, minute: 40, notes: "IKEA — storage boxes", amount: 2_190, type: .expense, categoryName: "Shopping", accountIndex: 1),
        Spec(day: 23, hour: 11, minute: 10, notes: "FirstCry — baby supplies", amount: 2_150, type: .expense, categoryName: "Shopping", accountIndex: 1),

        // Health & wellness
        Spec(day: 7, hour: 10, minute: 20, notes: "Pharmacy — vitamins", amount: 980, type: .expense, categoryName: "Health", accountIndex: 2),
        Spec(day: 17, hour: 15, minute: 0, notes: "Annual dental cleaning", amount: 3_200, type: .expense, categoryName: "Health", accountIndex: 1),
        Spec(day: 25, hour: 7, minute: 15, notes: "Cult.fit — monthly pass", amount: 1_499, type: .expense, categoryName: "Health", accountIndex: 1),
        Spec(day: 30, hour: 18, minute: 45, notes: "Padel court booking", amount: 900, type: .expense, categoryName: "Health", accountIndex: 2),

        // Miscellaneous — everything else
        Spec(day: 5, hour: 20, minute: 30, notes: "PVR — IMAX tickets", amount: 1_120, type: .expense, categoryName: "Miscellaneous", accountIndex: 1),
        Spec(day: 14, hour: 19, minute: 0, notes: "BookMyShow — comedy night", amount: 1_800, type: .expense, categoryName: "Miscellaneous", accountIndex: 1),
        Spec(day: 8, hour: 22, minute: 5, notes: "Udemy — SwiftUI course", amount: 799, type: .expense, categoryName: "Miscellaneous", accountIndex: 1),
        Spec(day: 29, hour: 10, minute: 30, notes: "Urban Company — deep clean", amount: 1_650, type: .expense, categoryName: "Miscellaneous", accountIndex: 0),
        Spec(day: 7, hour: 6, minute: 0, notes: "Mutual fund SIP — HDFC", amount: 15_000, type: .expense, categoryName: "Miscellaneous", accountIndex: 0),
        Spec(day: 20, hour: 14, minute: 0, notes: "CA — ITR prep + filing", amount: 6_500, type: .expense, categoryName: "Miscellaneous", accountIndex: 0)
    ]
}
