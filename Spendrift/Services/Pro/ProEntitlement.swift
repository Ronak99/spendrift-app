//
//  ProEntitlement.swift
//  Spendrift
//
//  StoreKit 2 entitlement for Spendrift Pro, verified client-side.
//
//  Two pieces live here:
//
//  * `ProEntitlementCache` — a Sendable, App Group-backed mirror of the last known
//    entitlement. Readable from any thread and, crucially, from the App Intent and
//    widget processes, which cannot cheaply run a StoreKit query before deciding
//    whether a voice capture is allowed. It is also what keeps a paying subscriber
//    from seeing a paywall flash on a cold or offline launch.
//
//  * `ProEntitlement` — the main-actor source of truth that talks to StoreKit and
//    writes through to the cache.
//

import Foundation
import StoreKit

/// Spendrift has its own SwiftData `Transaction` model, which shadows StoreKit's type
/// inside this module. Aliasing it keeps the StoreKit calls below unambiguous without
/// spelling out the module prefix on every line.
private typealias StoreTransaction = StoreKit.Transaction

// MARK: - Cross-process cache

enum ProEntitlementCache {
    private static let isProKey = "proEntitlementIsPro"
    private static let expiresAtKey = "proEntitlementExpiresAt"

    /// Test seam — see `AIQuotaStore.defaultsOverride`.
    static var defaultsOverride: UserDefaults?

    private static var suite: UserDefaults {
        defaultsOverride ?? UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
    }

    /// Last known entitlement. Treated as authoritative only until StoreKit answers.
    static var isPro: Bool {
        get {
            guard suite.bool(forKey: isProKey) else { return false }
            // A cached expiry in the past means the subscription lapsed while we were
            // not running; fall back to free rather than trusting the stale flag.
            let expiry = suite.double(forKey: expiresAtKey)
            guard expiry > 0 else { return true }
            return Date().timeIntervalSince1970 < expiry
        }
        set { suite.set(newValue, forKey: isProKey) }
    }

    static func update(isPro: Bool, expiresAt: Date?) {
        suite.set(isPro, forKey: isProKey)
        if let expiresAt {
            suite.set(expiresAt.timeIntervalSince1970, forKey: expiresAtKey)
        } else {
            suite.removeObject(forKey: expiresAtKey)
        }
    }
}

// MARK: - Entitlement

@MainActor
@Observable
final class ProEntitlement {
    enum Plan: String, CaseIterable, Identifiable {
        case yearly = "spendrift_pro_yearly"
        case monthly = "spendrift_pro_monthly"

        var id: String { rawValue }
    }

    enum Status: Equatable {
        /// StoreKit has not answered yet; `isPro` falls back to the cached mirror.
        case unknown
        case free
        case trial(endsAt: Date?)
        case subscribed(expiresAt: Date?)
        /// Was subscribed, is not now — the win-back audience.
        case lapsed
    }

    static let shared = ProEntitlement()

    private(set) var status: Status = .unknown
    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var purchaseInFlight = false

    /// True while the App Store will still grant the 7-day introductory offer. False
    /// once the user has already taken a trial anywhere in the subscription group.
    private(set) var isEligibleForTrial = true

    private var updatesTask: Task<Void, Never>?

    private init() {}

    var isPro: Bool {
        switch status {
        case .trial, .subscribed: true
        case .free, .lapsed:      false
        case .unknown:            ProEntitlementCache.isPro
        }
    }

    var isInTrial: Bool {
        if case .trial = status { return true }
        return false
    }

    var trialEndsAt: Date? {
        if case .trial(let endsAt) = status { return endsAt }
        return nil
    }

    func product(for plan: Plan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    // MARK: - Lifecycle

    /// Starts the `Transaction.updates` listener and does a first entitlement read.
    /// Safe to call more than once.
    func start() {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in StoreTransaction.updates {
                    guard let self else { return }
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                    }
                    await self.refreshEntitlement()
                }
            }
        }
        Task {
            await refreshEntitlement()
            await loadProducts()
        }
    }

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: Plan.allCases.map(\.rawValue))
            // Keep the paywall's visual order stable regardless of what StoreKit returns.
            products = Plan.allCases.compactMap { plan in
                loaded.first { $0.id == plan.rawValue }
            }
            await refreshTrialEligibility()
        } catch {
            Diagnostics.log(
                "Pro products failed to load",
                level: .warning,
                tags: [
                    Diagnostics.Tag.feature: Diagnostics.Feature.app.rawValue,
                    Diagnostics.Tag.reason: String(describing: type(of: error))
                ]
            )
        }
    }

    /// Reads `Transaction.currentEntitlements` and collapses it into a `Status`.
    func refreshEntitlement() async {
        var newStatus: Status = .free
        var expiry: Date?

        for await result in StoreTransaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Plan(rawValue: transaction.productID) != nil else { continue }

            expiry = transaction.expirationDate
            let isTrial = transaction.offer?.type == .introductory
            newStatus = isTrial
                ? .trial(endsAt: transaction.expirationDate)
                : .subscribed(expiresAt: transaction.expirationDate)
        }

        // Distinguish "never subscribed" from "subscribed once, now expired" so the
        // paywall can lead with a win-back rather than a first-run pitch.
        if case .free = newStatus, await hasAnyPastTransaction() {
            newStatus = .lapsed
        }

        status = newStatus
        ProEntitlementCache.update(isPro: isPro, expiresAt: expiry)
        await refreshTrialEligibility()
    }

    private func hasAnyPastTransaction() async -> Bool {
        for await result in StoreTransaction.all {
            guard case .verified(let transaction) = result else { continue }
            if Plan(rawValue: transaction.productID) != nil { return true }
        }
        return false
    }

    private func refreshTrialEligibility() async {
        guard let subscription = products.first?.subscription else { return }
        isEligibleForTrial = await subscription.isEligibleForIntroOffer
    }

    // MARK: - Purchase

    enum PurchaseOutcome: Equatable {
        case purchased
        case cancelled
        case pending
        case failed(message: String)
    }

    func purchase(_ plan: Plan) async -> PurchaseOutcome {
        guard let product = product(for: plan) else {
            return .failed(message: Self.productUnavailableMessage)
        }
        guard !purchaseInFlight else { return .cancelled }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlement()
                return .purchased

            case .userCancelled:
                return .cancelled

            case .pending:
                // Ask to Buy, or a payment method awaiting bank approval — common in
                // India where UPI Autopay mandates are confirmed out of band.
                return .pending

            @unknown default:
                return .failed(message: Self.genericFailureMessage)
            }
        } catch {
            return .failed(message: Self.message(for: error))
        }
    }

    func restorePurchases() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlement()
        return isPro
    }

    // MARK: - Failure copy

    private static let productUnavailableMessage =
        "Spendrift Pro isn't available from the App Store right now. Please try again in a moment."

    private static let genericFailureMessage =
        "That didn't go through. Please try again."

    /// India matters here: Apple no longer accepts Indian credit and debit cards for
    /// recurring App Store billing, so a payment failure is usually a missing UPI
    /// Autopay mandate rather than a declined card. Saying so is far more actionable
    /// than "purchase failed".
    private static func message(for error: Error) -> String {
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .networkError:
                return "Couldn't reach the App Store. Check your connection and try again."
            case .userCancelled:
                return genericFailureMessage
            default:
                break
            }
        }
        return """
        The App Store couldn't take the payment. Open Settings → your Apple Account → \
        Payment & Shipping and add a payment method — UPI Autopay works for \
        subscriptions in India — then try again.
        """
    }
}
