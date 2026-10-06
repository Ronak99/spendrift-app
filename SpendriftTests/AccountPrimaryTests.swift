//
//  AccountPrimaryTests.swift
//  SpendriftTests
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

@MainActor
struct AccountPrimaryTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Accounts in the order `@Query(sort: \Account.createdOn)` hands them over.
    private func insertAccounts(
        _ context: ModelContext,
        _ names: [String],
        primary: String? = nil
    ) -> [Account] {
        names.enumerated().map { index, name in
            let account = Account(
                name: name,
                createdOn: Date(timeIntervalSince1970: 1_790_000_000 + Double(index)),
                isPrimary: name == primary
            )
            context.insert(account)
            return account
        }
    }

    @Test
    func makePrimaryLeavesExactlyOneStar() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings", "Salary", "Cash"], primary: "Savings")

        let changed = accounts.makePrimary(accounts[2])

        #expect(changed)
        #expect(accounts.map(\.isPrimary) == [false, false, true])
        #expect(accounts.primary?.name == "Cash")
    }

    @Test
    func makePrimaryReportsNoChangeWhenTheStarIsAlreadyThere() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings", "Salary"], primary: "Savings")

        #expect(!accounts.makePrimary(accounts[0]))
        #expect(accounts.map(\.isPrimary) == [true, false])
    }

    @Test
    func normalizePrimaryPromotesTheFirstAccountWhenNoneIsStarred() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings", "Salary"])

        #expect(accounts.normalizePrimary())
        #expect(accounts.map(\.isPrimary) == [true, false])
    }

    @Test
    func normalizePrimaryCollapsesDuplicateStars() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings", "Salary", "Cash"])
        accounts[1].isPrimary = true
        accounts[2].isPrimary = true

        #expect(accounts.normalizePrimary())
        #expect(accounts.map(\.isPrimary) == [false, true, false])
    }

    @Test
    func normalizePrimaryLeavesAnAlreadyValidLedgerAlone() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings", "Salary"], primary: "Salary")

        #expect(!accounts.normalizePrimary())
        #expect(accounts.primary?.name == "Salary")
    }

    @Test
    func normalizePrimaryDoesNothingForAnEmptyLedger() {
        #expect(![Account]().normalizePrimary())
        #expect([Account]().primary == nil)
    }

    @Test
    func deletableKeepsTheLastAccount() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings"], primary: "Savings")

        #expect(accounts.deletable(at: IndexSet(integer: 0)).isEmpty)
    }

    @Test
    func deletableRefusesARequestCoveringEveryAccount() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings", "Salary"], primary: "Savings")

        #expect(accounts.deletable(at: IndexSet(0..<2)).isEmpty)
    }

    @Test
    func deletableReturnsTheSelectionWhenOneAccountSurvives() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings", "Salary", "Cash"], primary: "Savings")

        let toDelete = accounts.deletable(at: IndexSet([0, 2]))

        #expect(toDelete.map(\.name) == ["Savings", "Cash"])
    }

    @Test
    func deletingThePrimaryHandsTheStarToAnAccountThatSurvives() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings", "Salary", "Cash"], primary: "Savings")

        let toDelete = accounts.deletable(at: IndexSet(integer: 0))
        let deletedIDs = Set(toDelete.map(\.id))
        let survivors = accounts.filter { !deletedIDs.contains($0.id) }
        for account in toDelete {
            context.delete(account)
        }
        survivors.normalizePrimary()
        try context.save()

        #expect(survivors.map(\.isPrimary) == [true, false])
        #expect(survivors.primary?.name == "Salary")
    }

    @Test
    func deletingANonPrimaryAccountLeavesTheStarWhereItIs() throws {
        let context = try makeContext()
        let accounts = insertAccounts(context, ["Savings", "Salary", "Cash"], primary: "Cash")

        let toDelete = accounts.deletable(at: IndexSet(integer: 1))
        let deletedIDs = Set(toDelete.map(\.id))
        let survivors = accounts.filter { !deletedIDs.contains($0.id) }
        for account in toDelete {
            context.delete(account)
        }
        survivors.normalizePrimary()
        try context.save()

        #expect(survivors.primary?.name == "Cash")
    }
}
