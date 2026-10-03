//
//  ProGateTests.swift
//  SpendriftTests
//
//  Covers the free-tier quota arithmetic and the gate decisions that sit in front of
//  every paid backend call.
//

import Foundation
import Testing
@testable import Spendrift

struct ProGateTests {

    /// Each test gets its own throwaway defaults suite so counts never leak between
    /// tests or into the real App Group.
    private final class Sandbox {
        let suiteName = "spendrift.tests.pro.\(UUID().uuidString)"
        let defaults: UserDefaults

        init(isPro: Bool = false) {
            defaults = UserDefaults(suiteName: suiteName)!
            AIQuotaStore.defaultsOverride = defaults
            ProGate.defaultsOverride = defaults
            ProEntitlementCache.defaultsOverride = defaults
            AudienceTags.defaultsOverride = defaults
            ProEntitlementCache.update(isPro: isPro, expiresAt: nil)
        }

        deinit {
            defaults.removePersistentDomain(forName: suiteName)
            AIQuotaStore.defaultsOverride = nil
            ProGate.defaultsOverride = nil
            ProEntitlementCache.defaultsOverride = nil
            AudienceTags.defaultsOverride = nil
        }
    }

    // MARK: - Quota arithmetic

    @Test
    func remainingStartsAtTheMonthlyQuota() {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        for feature in ProFeature.allCases {
            #expect(AIQuotaStore.remaining(feature) == feature.monthlyFreeQuota)
            #expect(AIQuotaStore.hasQuota(feature))
        }
    }

    @Test
    func consumingSpendsCredits() {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        AIQuotaStore.consume(.voice, count: 3)
        #expect(AIQuotaStore.used(.voice) == 3)
        #expect(AIQuotaStore.remaining(.voice) == ProFeature.voice.monthlyFreeQuota - 3)
        // Features are counted independently.
        #expect(AIQuotaStore.used(.receiptScan) == 0)
    }

    @Test
    func consumingClampsAtTheQuota() {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        // An SMS drain can return more rows than there are credits left; the stored
        // count must not run past the quota or Settings would misreport it.
        AIQuotaStore.consume(.messageImport, count: ProFeature.messageImport.monthlyFreeQuota + 25)
        #expect(AIQuotaStore.used(.messageImport) == ProFeature.messageImport.monthlyFreeQuota)
        #expect(AIQuotaStore.remaining(.messageImport) == 0)
    }

    @Test
    func zeroCountIsANoOp() {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        AIQuotaStore.consume(.voice, count: 0)
        #expect(AIQuotaStore.used(.voice) == 0)
    }

    // MARK: - First month

    private static func date(month: Int, day: Int) throws -> Date {
        try #require(DateComponents(calendar: .current, year: 2026, month: month, day: day).date)
    }

    @Test
    func firstTouchHasTheFullFreeQuota() throws {
        let sandbox = Sandbox()
        defer { _ = sandbox }
        let september = try Self.date(month: 9, day: 15)

        for feature in ProFeature.allCases {
            #expect(AIQuotaStore.monthlyAllowance(feature, now: september) == feature.monthlyFreeQuota)
            #expect(AIQuotaStore.hasQuota(feature, now: september))
        }
    }

    @Test
    func usageResetsOnTheNextMonth() throws {
        let sandbox = Sandbox()
        defer { _ = sandbox }
        let september = try Self.date(month: 9, day: 15)
        let october = try Self.date(month: 10, day: 1)

        AIQuotaStore.consume(.voice, count: 3, now: september)
        #expect(AIQuotaStore.remaining(.voice, now: september) == ProFeature.voice.monthlyFreeQuota - 3)
        #expect(AIQuotaStore.remaining(.voice, now: october) == ProFeature.voice.monthlyFreeQuota)
    }

    // MARK: - Gate decisions

    @Test
    func freeUserIsAllowedWhileCreditsRemain() {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        #expect(ProGate.evaluate(.voice) == .allowed(remaining: ProFeature.voice.monthlyFreeQuota))
        #expect(ProGate.isAllowed(.voice))
    }

    @Test
    func freeUserIsBlockedOnceTheQuotaIsSpent() {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        AIQuotaStore.consume(.statementImport, count: ProFeature.statementImport.monthlyFreeQuota)
        #expect(ProGate.evaluate(.statementImport) == .blocked(.statementImport))
        #expect(!ProGate.isAllowed(.statementImport))
    }

    @Test
    func subscriberIsAlwaysUnlimitedAndNeverCounted() {
        let sandbox = Sandbox(isPro: true)
        defer { _ = sandbox }

        #expect(ProGate.evaluate(.voice) == .unlimited)

        // A subscriber's usage must not decrement anything: if it did, a lapsed
        // subscriber would drop straight to a spent quota instead of a fresh one.
        ProGate.recordUsage(.voice, count: 50)
        #expect(AIQuotaStore.used(.voice) == 0)
    }

    @Test
    func expiredCachedEntitlementFallsBackToFree() {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        ProEntitlementCache.update(isPro: true, expiresAt: Date().addingTimeInterval(-60))
        // The subscription lapsed while the app was not running; a stale true flag
        // must not keep granting Pro.
        #expect(!ProEntitlementCache.isPro)
    }

    @Test
    func unexpiredCachedEntitlementGrantsPro() {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        ProEntitlementCache.update(isPro: true, expiresAt: Date().addingTimeInterval(86_400))
        #expect(ProEntitlementCache.isPro)
    }

    // MARK: - Pitch bookkeeping

    @Test
    func celebrationIsPitchedOncePerFeature() {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        #expect(ProGate.shouldPitch(.voice))
        ProGate.announceMomentIfNeeded(.voice)
        #expect(!ProGate.shouldPitch(.voice))

        // A second win for the same feature must stay silent, while other features
        // keep their own one-shot.
        ProGate.announceMomentIfNeeded(.voice)
        #expect(ProGate.shouldPitch(.receiptScan))
    }

    @Test
    func subscriberIsNeverPitched() {
        let sandbox = Sandbox(isPro: true)
        defer { _ = sandbox }

        ProGate.announceMomentIfNeeded(.voice)
        #expect(ProGate.shouldPitch(.voice))
    }

    @Test
    func announcementCarriesTheFeature() async {
        let sandbox = Sandbox()
        defer { _ = sandbox }

        let received: ProFeature? = await withCheckedContinuation { continuation in
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: .proMomentReached,
                object: nil,
                queue: nil
            ) { note in
                if let token { NotificationCenter.default.removeObserver(token) }
                let raw = note.userInfo?[ProGate.featureUserInfoKey] as? String
                continuation.resume(returning: raw.flatMap(ProFeature.init(rawValue:)))
            }
            ProGate.announceMomentIfNeeded(.statementImport)
        }

        #expect(received == .statementImport)
    }
}
