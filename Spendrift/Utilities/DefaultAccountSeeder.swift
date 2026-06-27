//
//  DefaultAccountSeeder.swift
//  Spendrift
//
//  Created by Cursor on 27/06/26.
//

import CoreData
import Foundation
import SwiftData

/// Ensures a brand-new user starts with a single "Savings" account so creating
/// their first transaction is frictionless.
///
/// Crucially, the default account is **not** created instantly. We first wait
/// for CloudKit to finish its initial import; if sync brings down any existing
/// account (e.g. on a reinstall or a second device), we skip seeding entirely.
/// Only when sync completes and no account exists anywhere do we create the
/// starter account, which then mirrors back up to CloudKit and SwiftData.
enum DefaultAccountSeeder {
    private static let hasSeededDefaultAccountKey = "hasSeededDefaultAccount"

    /// Default starter account values.
    private static let defaultName = "Savings"
    private static let defaultBalance: Double = 100

    /// How long to wait for CloudKit's initial import before assuming there is
    /// no remote data (e.g. CloudKit disabled, offline, or a truly fresh account).
    private static let cloudSyncTimeout: TimeInterval = 10

    /// Creates the default account once per iCloud account, only after cloud sync
    /// has had a chance to deliver any pre-existing accounts.
    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) async {
        let cloudDefaults = NSUbiquitousKeyValueStore.default

        // Already seeded (or intentionally skipped) once — never seed again.
        guard !cloudDefaults.bool(forKey: hasSeededDefaultAccountKey) else { return }

        // Local store already has an account (legacy installs, or sync already
        // finished by the time we got here) — mark as handled and bail.
        if hasAnyAccount(in: modelContext) {
            markSeeded()
            return
        }

        // Wait for CloudKit's initial import so a freshly created default account
        // can't collide with accounts the sync is still downloading.
        await waitForInitialCloudImport()

        // Re-check after sync: remote accounts may have arrived in the meantime.
        guard !hasAnyAccount(in: modelContext) else {
            markSeeded()
            return
        }

        let account = Account(
            name: defaultName,
            balance: defaultBalance,
            icon: .savings,
            isPrimary: true
        )
        modelContext.insert(account)

        do {
            try modelContext.save()
            markSeeded()
        } catch {
            // Leave the flag unset so we retry on the next launch.
        }
    }

    private static func hasAnyAccount(in modelContext: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Account>()
        descriptor.fetchLimit = 1
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    private static func markSeeded() {
        let cloudDefaults = NSUbiquitousKeyValueStore.default
        cloudDefaults.set(true, forKey: hasSeededDefaultAccountKey)
        cloudDefaults.synchronize()
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

                // A finished import means any remote accounts have been pulled locally.
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
