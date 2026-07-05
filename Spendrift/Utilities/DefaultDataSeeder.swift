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
/// The flow optimises for instant display, then reconciles with CloudKit:
/// 1. Seed the starter "Savings" account and curated default categories
///    immediately so every `@Query`-backed view has data right away — no
///    waiting on the network.
/// 2. Wait for CloudKit's initial import so a returning user (reinstall / second
///    device) gets their existing data.
/// 3. Reconcile per type: if the import delivered real account/category rows,
///    delete the placeholders we just seeded (replacing defaults with the
///    synced values); if nothing arrived, keep the defaults intact.
///
/// Because everything is written into the shared `ModelContext`, every
/// `@Query`-backed view (Transactions, Accounts, Categories) updates reactively —
/// the user sees defaults instantly and any restored cloud data swaps in once
/// sync settles.
enum DefaultDataSeeder {
    /// Default starter account values.
    private static let defaultAccountName = "Savings"
    private static let defaultAccountBalance: Double = 100

    /// How long to wait for CloudKit's initial import before assuming there is
    /// no remote data (e.g. CloudKit disabled, offline, or a truly fresh account).
    private static let cloudSyncTimeout: TimeInterval = 10

    /// Seeds default account and categories instantly, then reconciles against
    /// CloudKit's initial import. Idempotent and safe to call repeatedly.
    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) async {
        Diagnostics.breadcrumb(
            category: .feature,
            message: "default_data_seed_started",
            feature: .seeding,
            stage: .bootstrap
        )

        // Bring legacy rows up to date regardless of whether we seed (idempotent,
        // guarded by their own UserDefaults flags).
        DefaultCategoryMigration.backfillIsDefaultIfNeeded(modelContext: modelContext)
        DefaultCategoryMigration.backfillSortOrderIfNeeded(modelContext: modelContext)

        let needsAccount = !hasAny(Account.self, in: modelContext)
        let needsCategories = !hasAny(TransactionCategory.self, in: modelContext)

        // Everything already present locally — nothing to seed, skip the wait.
        guard needsAccount || needsCategories else {
            Diagnostics.breadcrumb(
                category: .feature,
                message: "default_data_seed_skipped",
                feature: .seeding,
                stage: .reconcile
            )
            return
        }

        // 1. Seed instantly so the UI is never empty while sync runs.
        let seededAccountIDs = needsAccount ? seedDefaultAccount(in: modelContext) : []
        let seededCategoryIDs = needsCategories ? seedDefaultCategories(in: modelContext) : []

        // 2. Let CloudKit's initial import settle so we know whether the user
        //    actually has remote data to restore.
        await waitForInitialCloudImport()

        // 3. Replace placeholders with whatever the cloud delivered (per type).
        if !seededAccountIDs.isEmpty {
            reconcileSeededRows(Account.self, seededIDs: seededAccountIDs, in: modelContext)
        }
        if !seededCategoryIDs.isEmpty {
            reconcileSeededRows(TransactionCategory.self, seededIDs: seededCategoryIDs, in: modelContext)
        }

        Diagnostics.breadcrumb(
            category: .feature,
            message: "default_data_seed_completed",
            feature: .seeding,
            stage: .reconcile
        )
    }

    @discardableResult
    private static func seedDefaultAccount(in modelContext: ModelContext) -> [PersistentIdentifier] {
        let account = Account(
            name: defaultAccountName,
            balance: defaultAccountBalance,
            icon: .savings,
            isPrimary: true
        )
        modelContext.insert(account)
        try? modelContext.save()
        // Read the identifier after save so it is the permanent one.
        return [account.persistentModelID]
    }

    @discardableResult
    private static func seedDefaultCategories(in modelContext: ModelContext) -> [PersistentIdentifier] {
        let categories = TransactionCategory.defaultCategories()
        for category in categories {
            modelContext.insert(category)
        }
        try? modelContext.save()
        // Read identifiers after save so they are the permanent ones.
        return categories.map(\.persistentModelID)
    }

    /// After the cloud import, drops the rows we just seeded **only if** the
    /// import delivered other (real) rows of the same type. When nothing else
    /// arrived, the seeded defaults are left untouched.
    private static func reconcileSeededRows<T: PersistentModel>(
        _ type: T.Type,
        seededIDs: [PersistentIdentifier],
        in modelContext: ModelContext
    ) {
        let seededSet = Set(seededIDs)
        let all = (try? modelContext.fetch(FetchDescriptor<T>())) ?? []
        let hasCloudRows = all.contains { !seededSet.contains($0.persistentModelID) }

        // No remote data arrived — keep the defaults we seeded.
        guard hasCloudRows else { return }

        for object in all where seededSet.contains(object.persistentModelID) {
            modelContext.delete(object)
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
