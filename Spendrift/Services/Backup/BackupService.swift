//
//  BackupService.swift
//  Spendrift
//
//  Backs up the ledger to the backend and restores it, keyed by the device id.
//  A backup is a full snapshot. A restore is a full replace: every local
//  transaction, account, and category is deleted and the snapshot written in
//  its place, in one save so a failure leaves the store untouched.
//

import Foundation
import SwiftData
import WidgetKit

enum BackupError: LocalizedError, Equatable {
    /// The backup was written by a newer build in a format this one cannot read.
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion:
            return "This backup was made with a newer version of Spendrift. Update the app to restore it."
        }
    }
}

enum BackupService {
    /// How many backups the server keeps per device. Storing one more removes
    /// the oldest. Matches the backend's `MAX_BACKUPS_PER_DEVICE` default; the
    /// app only uses it to tell the user what will happen.
    static let retainedBackupCount = 5

    // MARK: - Backend

    /// Uploads a snapshot of the current store and returns the stored backup.
    @MainActor
    static func createBackup(modelContext: ModelContext) async throws -> BackupSummary {
        do {
            let snapshot = try makeSnapshot(from: modelContext)
            let client = try SpendriftBackendClient()
            let summary = try await client.createBackup(
                deviceID: DeviceIdentity.current,
                appVersion: AppInfo.appVersionLabel(),
                snapshot: snapshot
            )
            Analytics.capture(.backupCreated, [Analytics.Key.count: summary.transactionCount])
            return summary
        } catch {
            report(error, stage: .upload)
            throw error
        }
    }

    /// Backups stored for this device, newest first.
    static func listBackups() async throws -> [BackupSummary] {
        let client = try SpendriftBackendClient()
        return try await client.fetchBackups(deviceID: DeviceIdentity.current)
    }

    /// Downloads the backup and replaces the local store with it. Nothing local
    /// is touched until the whole backup has been downloaded and decoded.
    @MainActor
    static func restore(_ backup: BackupSummary, modelContext: ModelContext) async throws {
        do {
            try checkCanRestore(backup)
            let client = try SpendriftBackendClient()
            let detail = try await client.fetchBackup(
                id: backup.id,
                deviceID: DeviceIdentity.current
            )
            try apply(detail.snapshot, to: modelContext)
            WidgetCenter.shared.reloadAllTimelines()
            Analytics.capture(.backupRestored, [Analytics.Key.count: detail.transactions.count])
        } catch {
            report(error, stage: .persist)
            throw error
        }
    }

    /// Removes the backup from the server. Nothing on this device changes.
    static func deleteBackup(_ backup: BackupSummary) async throws {
        do {
            let client = try SpendriftBackendClient()
            try await client.deleteBackup(id: backup.id, deviceID: DeviceIdentity.current)
            Analytics.capture(.backupDeleted, [Analytics.Key.count: backup.transactionCount])
        } catch {
            report(error, stage: .delete)
            throw error
        }
    }

    /// Refuses a backup in a newer format before anything is downloaded or deleted.
    static func checkCanRestore(_ backup: BackupSummary) throws {
        guard backup.schemaVersion <= BackupSnapshot.schemaVersion else {
            throw BackupError.unsupportedSchemaVersion(backup.schemaVersion)
        }
    }

    // MARK: - Local store

    /// Copies every account, category, and transaction out of the store.
    @MainActor
    static func makeSnapshot(from modelContext: ModelContext) throws -> BackupSnapshot {
        // Row ids are not unique at the store level, so a duplicate is possible
        // in theory. The backend rejects duplicates; the first row wins here.
        var accountIDs = Set<UUID>()
        let accounts = try modelContext
            .fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.createdOn)]))
            .filter { accountIDs.insert($0.id).inserted }
            .map { account in
                BackupAccountRecord(
                    id: account.id,
                    name: storable(account.name),
                    balance: account.balance,
                    icon: account.icon.rawValue,
                    isPrimary: account.isPrimary,
                    createdOn: account.createdOn,
                    lastUsedAt: account.lastUsedAt
                )
            }

        var categoryIDs = Set<UUID>()
        let categories = try modelContext
            .fetch(FetchDescriptor<TransactionCategory>(sortBy: [SortDescriptor(\.createdOn)]))
            .filter { categoryIDs.insert($0.id).inserted }
            .map { category in
                BackupCategoryRecord(
                    id: category.id,
                    name: storable(category.name),
                    type: category.type,
                    icon: category.icon.rawValue,
                    isDefault: category.isDefault,
                    sortOrder: category.sortOrder,
                    colorHex: category.colorHex,
                    monthlyBudget: category.monthlyBudget > 0 ? category.monthlyBudget : nil,
                    createdOn: category.createdOn,
                    lastUsedAt: category.lastUsedAt
                )
            }

        var transactionIDs = Set<UUID>()
        let transactions = try modelContext
            .fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)]))
            .filter { transactionIDs.insert($0.id).inserted }
            .map { transaction in
                BackupTransactionRecord(
                    id: transaction.id,
                    notes: storable(transaction.notes),
                    amount: transaction.amount,
                    date: transaction.date,
                    transactionType: transaction.transactionType,
                    source: storable(transaction.source),
                    accountID: transaction.account.map(\.id),
                    categoryID: transaction.category.map(\.id)
                )
            }

        return BackupSnapshot(accounts: accounts, categories: categories, transactions: transactions)
    }

    /// Postgres cannot store a NUL character in JSON text and would reject the
    /// whole backup over one, so it is dropped from free text (imported notes
    /// are the only realistic source).
    private static func storable(_ text: String) -> String {
        text.contains("\0") ? text.replacingOccurrences(of: "\0", with: "") : text
    }

    /// Deletes every transaction, account, and category, then writes the
    /// snapshot. Both halves commit in a single save; on failure the context is
    /// rolled back and the store keeps what it had.
    @MainActor
    static func apply(_ snapshot: BackupSnapshot, to modelContext: ModelContext) throws {
        // Flush unrelated pending edits first so the rollback below can only
        // ever undo the restore itself.
        if modelContext.hasChanges {
            try modelContext.save()
        }

        do {
            for transaction in try modelContext.fetch(FetchDescriptor<Transaction>()) {
                modelContext.delete(transaction)
            }
            for account in try modelContext.fetch(FetchDescriptor<Account>()) {
                modelContext.delete(account)
            }
            for category in try modelContext.fetch(FetchDescriptor<TransactionCategory>()) {
                modelContext.delete(category)
            }

            var accountsByID: [UUID: Account] = [:]
            var restoredAccounts: [Account] = []
            for record in snapshot.accounts {
                let account = Account(
                    id: record.id,
                    name: record.name,
                    balance: record.balance,
                    createdOn: record.createdOn,
                    icon: AccountIcon(rawValue: record.icon) ?? .unknown,
                    isPrimary: record.isPrimary
                )
                account.lastUsedAt = record.lastUsedAt
                modelContext.insert(account)
                accountsByID[record.id] = account
                restoredAccounts.append(account)
            }

            // A snapshot taken before the star was guaranteed can carry none, or
            // more than one. The restored ledger still ends up with exactly one.
            restoredAccounts
                .sorted { $0.createdOn < $1.createdOn }
                .normalizePrimary()

            var categoriesByID: [UUID: TransactionCategory] = [:]
            for record in snapshot.categories {
                let category = TransactionCategory(
                    id: record.id,
                    name: record.name,
                    type: record.type,
                    createdOn: record.createdOn,
                    icon: CategoryIcon(rawValue: record.icon) ?? .unknown,
                    isDefault: record.isDefault,
                    sortOrder: record.sortOrder,
                    colorHex: record.colorHex
                )
                category.monthlyBudget = record.monthlyBudget ?? 0
                category.lastUsedAt = record.lastUsedAt
                modelContext.insert(category)
                categoriesByID[record.id] = category
            }

            for record in snapshot.transactions {
                let transaction = Transaction(
                    id: record.id,
                    notes: record.notes,
                    amount: record.amount,
                    date: record.date,
                    transactionType: record.transactionType,
                    source: record.source
                )
                modelContext.insert(transaction)
                transaction.account = record.accountID.flatMap { accountsByID[$0] }
                transaction.category = record.categoryID.flatMap { categoriesByID[$0] }
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    // MARK: - Diagnostics

    private static func report(_ error: Error, stage: Diagnostics.Stage) {
        Diagnostics.capture(
            error,
            tags: [
                Diagnostics.Tag.feature: Diagnostics.Feature.backup.rawValue,
                Diagnostics.Tag.stage: stage.rawValue,
            ]
        )
    }
}
