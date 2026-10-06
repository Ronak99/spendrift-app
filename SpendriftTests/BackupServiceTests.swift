//
//  BackupServiceTests.swift
//  SpendriftTests
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

@MainActor
struct BackupServiceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// One account, one category, one linked transaction and one unlinked one.
    private func seed(_ context: ModelContext) throws {
        let account = Account(name: "Savings", balance: 250, icon: .savings, isPrimary: true)
        account.lastUsedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let category = TransactionCategory(
            name: "Food",
            type: .expense,
            icon: .food,
            isDefault: true,
            sortOrder: 3,
            colorHex: "#FF8800"
        )
        context.insert(account)
        context.insert(category)

        let linked = Transaction(
            notes: "Lunch",
            amount: 12.4,
            date: Date(timeIntervalSince1970: 1_790_000_500),
            transactionType: .expense,
            source: TransactionSource.voice.rawValue
        )
        let unlinked = Transaction(notes: "Loose", amount: 5, transactionType: .income)
        context.insert(linked)
        context.insert(unlinked)
        linked.account = account
        linked.category = category
        try context.save()
    }

    @Test
    func snapshotCopiesEveryRowAndItsLinks() throws {
        let context = try makeContext()
        try seed(context)

        let snapshot = try BackupService.makeSnapshot(from: context)

        #expect(snapshot.accounts.count == 1)
        #expect(snapshot.categories.count == 1)
        #expect(snapshot.transactions.count == 2)

        let account = try #require(snapshot.accounts.first)
        #expect(account.name == "Savings")
        #expect(account.balance == 250)
        #expect(account.icon == AccountIcon.savings.rawValue)
        #expect(account.isPrimary)
        #expect(account.lastUsedAt == Date(timeIntervalSince1970: 1_790_000_000))

        let category = try #require(snapshot.categories.first)
        #expect(category.type == .expense)
        #expect(category.sortOrder == 3)
        #expect(category.colorHex == "#FF8800")

        let linked = try #require(snapshot.transactions.first { $0.notes == "Lunch" })
        #expect(linked.accountID == account.id)
        #expect(linked.categoryID == category.id)
        #expect(linked.source == TransactionSource.voice.rawValue)

        let unlinked = try #require(snapshot.transactions.first { $0.notes == "Loose" })
        #expect(unlinked.accountID == nil)
        #expect(unlinked.categoryID == nil)
    }

    @Test
    func applyReplacesTheStoreWithTheSnapshot() throws {
        let source = try makeContext()
        try seed(source)
        let snapshot = try BackupService.makeSnapshot(from: source)

        // A different ledger that the restore must wipe completely.
        let target = try makeContext()
        let staleAccount = Account(name: "Stale", balance: 1)
        let staleCategory = TransactionCategory(name: "Stale", type: .income)
        target.insert(staleAccount)
        target.insert(staleCategory)
        target.insert(
            Transaction(
                notes: "Stale",
                amount: 99,
                transactionType: .income,
                category: staleCategory,
                account: staleAccount
            )
        )
        try target.save()

        try BackupService.apply(snapshot, to: target)

        let accounts = try target.fetch(FetchDescriptor<Account>())
        let categories = try target.fetch(FetchDescriptor<TransactionCategory>())
        let transactions = try target.fetch(FetchDescriptor<Transaction>())
        #expect(accounts.map(\.name) == ["Savings"])
        #expect(categories.map(\.name) == ["Food"])
        #expect(Set(transactions.map(\.notes)) == ["Lunch", "Loose"])

        let lunch = try #require(transactions.first { $0.notes == "Lunch" })
        #expect(lunch.account?.id == snapshot.accounts.first?.id)
        #expect(lunch.category?.id == snapshot.categories.first?.id)
        #expect(lunch.amount == 12.4)
        #expect(lunch.date == Date(timeIntervalSince1970: 1_790_000_500))
        #expect(accounts.first?.transactions?.count == 1)

        // Restoring is a faithful copy: a second snapshot matches the first.
        #expect(try BackupService.makeSnapshot(from: target) == snapshot)
    }

    @Test
    func applyFallsBackToUnknownForIconsThisBuildDoesNotKnow() throws {
        let context = try makeContext()
        let snapshot = BackupSnapshot(
            accounts: [
                BackupAccountRecord(
                    id: UUID(),
                    name: "Future",
                    balance: 0,
                    icon: "iconFromANewerBuild",
                    isPrimary: false,
                    createdOn: Date(),
                    lastUsedAt: nil
                ),
            ],
            categories: [],
            transactions: []
        )

        try BackupService.apply(snapshot, to: context)

        let account = try #require(try context.fetch(FetchDescriptor<Account>()).first)
        #expect(account.icon == .unknown)
    }

    @Test
    func applyingAnEmptySnapshotClearsTheStore() throws {
        let context = try makeContext()
        try seed(context)

        try BackupService.apply(
            BackupSnapshot(accounts: [], categories: [], transactions: []),
            to: context
        )

        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TransactionCategory>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    }

    @Test
    func applyStarsAnAccountWhenTheSnapshotCarriesNoPrimary() throws {
        let context = try makeContext()
        func record(_ name: String, createdOn: TimeInterval) -> BackupAccountRecord {
            BackupAccountRecord(
                id: UUID(),
                name: name,
                balance: 0,
                icon: AccountIcon.cash.rawValue,
                isPrimary: false,
                createdOn: Date(timeIntervalSince1970: createdOn),
                lastUsedAt: nil
            )
        }
        let snapshot = BackupSnapshot(
            accounts: [
                record("Salary", createdOn: 1_790_000_100),
                record("Savings", createdOn: 1_790_000_000),
            ],
            categories: [],
            transactions: []
        )

        try BackupService.apply(snapshot, to: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.filter(\.isPrimary).map(\.name) == ["Savings"])
    }

    @Test
    func snapshotDropsNulCharactersTheServerCannotStore() throws {
        let context = try makeContext()
        context.insert(Transaction(notes: "Lun\0ch", amount: 1, transactionType: .expense))
        try context.save()

        let snapshot = try BackupService.makeSnapshot(from: context)

        #expect(snapshot.transactions.first?.notes == "Lunch")
    }

    @Test
    func refusesToRestoreABackupInANewerFormat() throws {
        func summary(schemaVersion: Int) -> BackupSummary {
            BackupSummary(
                id: UUID(),
                appVersion: "9.0.0 (1)",
                schemaVersion: schemaVersion,
                accountCount: 0,
                categoryCount: 0,
                transactionCount: 0,
                createdAt: Date()
            )
        }

        try BackupService.checkCanRestore(summary(schemaVersion: BackupSnapshot.schemaVersion))
        #expect(throws: BackupError.unsupportedSchemaVersion(BackupSnapshot.schemaVersion + 1)) {
            try BackupService.checkCanRestore(summary(schemaVersion: BackupSnapshot.schemaVersion + 1))
        }
    }

    @Test
    func createRequestUsesTheBackendFieldNames() throws {
        let accountID = UUID()
        let request = BackupCreateRequest(
            deviceID: "550E8400-E29B-41D4-A716-446655440000",
            appVersion: "1.5.0 (42)",
            schemaVersion: BackupSnapshot.schemaVersion,
            accounts: [],
            categories: [],
            transactions: [
                BackupTransactionRecord(
                    id: UUID(),
                    notes: "Lunch",
                    amount: 12.4,
                    date: Date(timeIntervalSince1970: 1_790_000_500.25),
                    transactionType: .expense,
                    source: "manual",
                    accountID: accountID,
                    categoryID: nil
                ),
            ]
        )

        let data = try BackupCoding.makeEncoder().encode(request)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["device_id"] as? String == "550E8400-E29B-41D4-A716-446655440000")
        #expect(json["app_version"] as? String == "1.5.0 (42)")
        #expect(json["schema_version"] as? Int == 1)

        let transactions = try #require(json["transactions"] as? [[String: Any]])
        let transaction = try #require(transactions.first)
        #expect(transaction["transaction_type"] as? String == "expense")
        #expect(transaction["account_id"] as? String == accountID.uuidString)
        #expect(transaction["transaction_date"] as? String == "2026-09-21T14:21:40.250Z")
    }

    @Test
    func decodesTheBackupDetailResponse() throws {
        let json = """
        {
          "backup": {
            "id": "7f0c5d0e-2f0a-4b6e-9a51-0d6c7f3b2a10",
            "app_version": "1.5.0 (42)",
            "schema_version": 1,
            "account_count": 1,
            "category_count": 1,
            "transaction_count": 1,
            "created_at": "2026-10-04T09:30:00.000Z"
          },
          "accounts": [{
            "id": "11111111-1111-4111-8111-111111111111",
            "name": "Savings", "balance": 100.5, "icon": "savings", "is_primary": true,
            "created_on": "2026-10-01T08:00:00.000Z", "last_used_at": null
          }],
          "categories": [{
            "id": "22222222-2222-4222-8222-222222222222",
            "name": "Food", "type": "expense", "icon": "food", "is_default": true,
            "sort_order": 2, "color_hex": null,
            "created_on": "2026-10-01T08:00:00.000Z", "last_used_at": "2026-10-03T12:30:00.000Z"
          }],
          "transactions": [{
            "id": "33333333-3333-4333-8333-333333333333",
            "notes": "Lunch", "amount": 12.4,
            "transaction_date": "2026-10-03T12:30:00.000Z",
            "transaction_type": "expense", "source": "manual",
            "account_id": "11111111-1111-4111-8111-111111111111",
            "category_id": "22222222-2222-4222-8222-222222222222",
            "field_from_a_newer_build": "ignored"
          }]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let detail = try BackupCoding.makeDecoder().decode(BackupDetailResponse.self, from: data)

        #expect(detail.backup.transactionCount == 1)
        #expect(detail.accounts.first?.lastUsedAt == nil)
        #expect(detail.categories.first?.lastUsedAt != nil)
        let transaction = try #require(detail.transactions.first)
        #expect(transaction.accountID == detail.accounts.first?.id)
        #expect(transaction.categoryID == detail.categories.first?.id)
    }
}
