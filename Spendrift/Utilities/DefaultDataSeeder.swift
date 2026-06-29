//
//  DefaultDataSeeder.swift
//  Spendrift
//
//  Single source of truth for seeding a brand-new user's starter data.
//

import CoreData
import Foundation
import SwiftData

/// Unifies seeding of the default account and default categories so it happens
/// in exactly one place: the moment the user starts onboarding.
///
/// The flow is deliberately silent and order-sensitive:
/// 1. Wait for CloudKit's initial import so a returning user (reinstall / second
///    device) gets their existing data before we consider seeding anything.
/// 2. If no account exists after sync, seed the starter "Savings" account.
/// 3. If no category exists after sync, seed the curated default categories.
///
/// Because everything is written into the shared `ModelContext`, every
/// `@Query`-backed view (Transactions, Accounts, Categories) updates reactively —
/// the user never has to switch tabs to see the seeded data.
enum DefaultDataSeeder {
    /// Default starter account values.
    private static let defaultAccountName = "Savings"
    private static let defaultAccountBalance: Double = 100

    /// How long to wait for CloudKit's initial import before assuming there is
    /// no remote data (e.g. CloudKit disabled, offline, or a truly fresh account).
    private static let cloudSyncTimeout: TimeInterval = 10

    /// Seeds default account and categories once, after giving CloudKit a chance
    /// to deliver any pre-existing data. Idempotent and safe to call repeatedly.
    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) async {
        // Bring legacy rows up to date regardless of whether we seed (idempotent,
        // guarded by their own UserDefaults flags).
        DefaultCategoryMigration.backfillIsDefaultIfNeeded(modelContext: modelContext)
        DefaultCategoryMigration.backfillSortOrderIfNeeded(modelContext: modelContext)

        let needsAccount = !hasAny(Account.self, in: modelContext)
        let needsCategories = !hasAny(TransactionCategory.self, in: modelContext)

        // Everything already present locally — nothing to seed, skip the wait.
        guard needsAccount || needsCategories else { return }

        // Let CloudKit's initial import settle so freshly seeded rows can't
        // collide with data the sync is still downloading.
        await waitForInitialCloudImport()

        if !hasAny(Account.self, in: modelContext) {
            seedDefaultAccount(in: modelContext)
        }

        if !hasAny(TransactionCategory.self, in: modelContext) {
            seedDefaultCategories(in: modelContext)
        }
    }

    private static func seedDefaultAccount(in modelContext: ModelContext) {
        let account = Account(
            name: defaultAccountName,
            balance: defaultAccountBalance,
            icon: .savings,
            isPrimary: true
        )
        modelContext.insert(account)
        try? modelContext.save()
    }

    private static func seedDefaultCategories(in modelContext: ModelContext) {
        for category in TransactionCategory.defaultCategories() {
            modelContext.insert(category)
        }
        try? modelContext.save()
    }

    private static func hasAny<T: PersistentModel>(_ type: T.Type, in modelContext: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<T>()
        descriptor.fetchLimit = 1
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    /// Resolves once CloudKit reports a finished `import` event, or after a
    /// timeout when no such event arrives (CloudKit disabled/offline/fresh).
    private static func waitForInitialCloudImport() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let center = NotificationCenter.default
            var observer: NSObjectProtocol?
            var didResume = false

            @Sendable func finish() {
                guard !didResume else { return }
                didResume = true
                if let observer { center.removeObserver(observer) }
                continuation.resume()
            }

            observer = center.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: nil,
                queue: .main
            ) { notification in
                guard
                    let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event
                else { return }

                // A finished import means any remote data has been pulled locally.
                if event.type == .import, event.endDate != nil {
                    finish()
                }
            }

            // Fallback so we still seed when no import event ever fires.
            DispatchQueue.main.asyncAfter(deadline: .now() + cloudSyncTimeout) {
                finish()
            }
        }
    }
}
