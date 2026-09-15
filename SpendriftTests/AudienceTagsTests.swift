//
//  AudienceTagsTests.swift
//  SpendriftTests
//
//  Snapshot mapping for OneSignal Data Tags. No SDK calls.
//

import Foundation
import Testing
@testable import Spendrift

struct AudienceTagsTests {

    private let now = Date(timeIntervalSince1970: 1_779_033_600) // 2026-05-05 00:00 UTC

    // MARK: - Buckets

    @Test(arguments: [
        (0, "0"),
        (1, "1"),
        (2, "2_5"),
        (5, "2_5"),
        (6, "6_20"),
        (20, "6_20"),
        (21, "21_plus"),
        (100, "21_plus"),
    ])
    func bucketsAtTheEdges(count: Int, expected: String) {
        #expect(AudienceTags.txCountBucket(count) == expected)
        let tags = AudienceTags.snapshot(input(ledgerCount: count))
        #expect(tags[AudienceTags.Tag.txCountBucket] == expected)
        #expect(tags[AudienceTags.Tag.hasTransaction] == AudienceTags.boolString(count > 0))
    }

    // MARK: - Plan

    @Test
    func unknownEntitlementOmitsPlanAndTrialDate() {
        let tags = AudienceTags.snapshot(
            input(plan: nil, trialEndsAt: now, isPro: true)
        )
        #expect(tags[AudienceTags.Tag.plan] == nil)
        #expect(tags[AudienceTags.Tag.trialEndsOn] == nil)
    }

    @Test
    func trialWritesPlanAndDate() {
        let tags = AudienceTags.snapshot(
            input(plan: "trial", trialEndsAt: now, isPro: true)
        )
        #expect(tags[AudienceTags.Tag.plan] == "trial")
        #expect(tags[AudienceTags.Tag.trialEndsOn] == AudienceTags.dayString(now))
    }

    @Test
    func subscribedMapsToProAndDropsTrialDate() {
        let tags = AudienceTags.snapshot(
            input(plan: "pro", trialEndsAt: now, isPro: true)
        )
        #expect(tags[AudienceTags.Tag.plan] == "pro")
        #expect(tags[AudienceTags.Tag.trialEndsOn] == nil)
    }

    @Test
    func lapsedMapsWithoutTrialDate() {
        let tags = AudienceTags.snapshot(input(plan: "lapsed", isPro: false))
        #expect(tags[AudienceTags.Tag.plan] == "lapsed")
        #expect(tags[AudienceTags.Tag.trialEndsOn] == nil)
    }

    @Test
    func freeMapsWithoutTrialDate() {
        let tags = AudienceTags.snapshot(input(plan: "free", isPro: false))
        #expect(tags[AudienceTags.Tag.plan] == "free")
        #expect(tags[AudienceTags.Tag.trialEndsOn] == nil)
    }

    // MARK: - Quota exhausted

    @Test
    func proNeverLooksExhaustedEvenWhenCountersAreZero() {
        let tags = AudienceTags.snapshot(
            input(
                plan: "pro",
                isPro: true,
                quotaVoice: 0,
                quotaSMS: 0,
                quotaReceipt: 0,
                quotaPDF: 0
            )
        )
        #expect(tags[AudienceTags.Tag.quotaExhaustedAny] == "false")
        #expect(tags[AudienceTags.Tag.quotaVoice] == "0")
    }

    @Test
    func freeUserIsExhaustedWhenAnyFeatureIsZero() {
        let tags = AudienceTags.snapshot(
            input(plan: "free", isPro: false, quotaVoice: 0, quotaSMS: 30)
        )
        #expect(tags[AudienceTags.Tag.quotaExhaustedAny] == "true")
    }

    @Test
    func freeUserWithCreditsLeftIsNotExhausted() {
        let tags = AudienceTags.snapshot(
            input(
                plan: "free",
                isPro: false,
                quotaVoice: 10,
                quotaSMS: 30,
                quotaReceipt: 5,
                quotaPDF: 1
            )
        )
        #expect(tags[AudienceTags.Tag.quotaExhaustedAny] == "false")
    }

    // MARK: - Quota hits

    @Test
    func thirtyDayHitsPruneOlderThanTheWindow() {
        let recent = now
        let stale = now.addingTimeInterval(-31 * 24 * 60 * 60)
        let pruned = AudienceTags.pruneQuotaHits([stale, recent], now: now)
        #expect(pruned == [recent])
        let tags = AudienceTags.snapshot(
            input(quotaHitTimestamps: [stale, recent])
        )
        #expect(tags[AudienceTags.Tag.quotaHits30d] == "1")
    }

    @Test
    func thirtyDayHitsCapAt99() {
        let hits = (0..<120).map { now.addingTimeInterval(TimeInterval($0)) }
        #expect(AudienceTags.quotaHitCount(timestamps: hits, now: now) == 99)
        let tags = AudienceTags.snapshot(input(quotaHitTimestamps: hits))
        #expect(tags[AudienceTags.Tag.quotaHits30d] == "99")
    }

    @Test
    func voiceStickyClearsWhenThePeriodChanges() {
        #expect(
            AudienceTags.isHitQuotaVoiceSticky(
                storedPeriod: "2026-05",
                currentPeriod: "2026-05"
            )
        )
        #expect(
            !AudienceTags.isHitQuotaVoiceSticky(
                storedPeriod: "2026-04",
                currentPeriod: "2026-05"
            )
        )
        #expect(
            !AudienceTags.isHitQuotaVoiceSticky(
                storedPeriod: nil,
                currentPeriod: "2026-05"
            )
        )
    }

    // MARK: - String formats

    @Test
    func boolsAreLowercaseTrueFalse() {
        #expect(AudienceTags.boolString(true) == "true")
        #expect(AudienceTags.boolString(false) == "false")
        let tags = AudienceTags.snapshot(input(onboardingDone: true, seenExplore: false))
        #expect(tags[AudienceTags.Tag.onboardingDone] == "true")
        #expect(tags[AudienceTags.Tag.seenExplore] == "false")
    }

    @Test
    func intsAreUnpadded() {
        let tags = AudienceTags.snapshot(
            input(quotaVoice: 7, daysSinceInstall: 3)
        )
        #expect(tags[AudienceTags.Tag.daysSinceInstall] == "3")
        #expect(tags[AudienceTags.Tag.quotaVoice] == "7")
        #expect(tags[AudienceTags.Tag.quotaHits30d] == "0")
    }

    @Test
    func datesAreYearMonthDay() {
        let formatted = AudienceTags.dayString(now)
        #expect(formatted.count == 10)
        #expect(formatted.contains("-"))
        let tags = AudienceTags.snapshot(input(plan: "trial", trialEndsAt: now, isPro: true))
        #expect(tags[AudienceTags.Tag.lastActiveOn] == formatted)
        #expect(tags[AudienceTags.Tag.trialEndsOn] == formatted)
    }

    @Test
    func captureMethodFlagsAndCensusPassThrough() {
        let ledger = AudienceTags.LedgerSnapshot(
            transactionCount: 4,
            usedManual: true,
            usedVoice: true,
            usedSMS: false,
            usedPDF: false,
            usedReceipt: true,
            usedTypedShortcut: true
        )
        let tags = AudienceTags.snapshot(
            input(
                ledger: ledger,
                exploreShortcutAdded: true,
                seenAnalytics: true,
                notifStatus: "authorized",
                appVersion: "1.4.1",
                iosVersion: "18.5",
                locale: "en_IN"
            )
        )
        #expect(tags[AudienceTags.Tag.usedManual] == "true")
        #expect(tags[AudienceTags.Tag.usedVoice] == "true")
        #expect(tags[AudienceTags.Tag.usedSMS] == "false")
        #expect(tags[AudienceTags.Tag.usedPDF] == "false")
        #expect(tags[AudienceTags.Tag.usedReceipt] == "true")
        #expect(tags[AudienceTags.Tag.usedTypedShortcut] == "true")
        #expect(tags[AudienceTags.Tag.exploreShortcutAdded] == "true")
        #expect(tags[AudienceTags.Tag.seenAnalytics] == "true")
        #expect(tags[AudienceTags.Tag.notifStatus] == "authorized")
        #expect(tags[AudienceTags.Tag.appVersion] == "1.4.1")
        #expect(tags[AudienceTags.Tag.iosVersion] == "18.5")
        #expect(tags[AudienceTags.Tag.locale] == "en_IN")
        #expect(tags[AudienceTags.Tag.txCountBucket] == "2_5")
    }

    // MARK: - Diff

    @Test
    func diffAddsChangedKeysAndRemovesDroppedTrialDate() {
        let last: [String: String] = [
            AudienceTags.Tag.plan: "trial",
            AudienceTags.Tag.trialEndsOn: "2026-05-10",
            AudienceTags.Tag.quotaVoice: "2",
        ]
        let current: [String: String] = [
            AudienceTags.Tag.plan: "lapsed",
            AudienceTags.Tag.quotaVoice: "2",
        ]
        let change = AudienceTags.diff(current: current, last: last)
        #expect(change.add[AudienceTags.Tag.plan] == "lapsed")
        #expect(change.add[AudienceTags.Tag.quotaVoice] == nil)
        #expect(change.remove == [AudienceTags.Tag.trialEndsOn])
    }

    @Test
    func diffIsEmptyWhenNothingChanged() {
        let tags = ["sd_plan": "free"]
        let change = AudienceTags.diff(current: tags, last: tags)
        #expect(change.add.isEmpty)
        #expect(change.remove.isEmpty)
    }

    // MARK: - Fixture

    private func input(
        onboardingDone: Bool = false,
        ledgerCount: Int? = nil,
        ledger: AudienceTags.LedgerSnapshot? = nil,
        seenExplore: Bool = false,
        exploreShortcutAdded: Bool = false,
        seenAnalytics: Bool = false,
        plan: String? = "free",
        trialEndsAt: Date? = nil,
        isPro: Bool = false,
        quotaVoice: Int = 10,
        quotaSMS: Int = 30,
        quotaReceipt: Int = 5,
        quotaPDF: Int = 1,
        hitQuotaVoice: Bool = false,
        quotaHitTimestamps: [Date] = [],
        notifStatus: String = "not_determined",
        daysSinceInstall: Int = 0,
        appVersion: String = "1.4.1",
        iosVersion: String = "18.5",
        locale: String = "en_IN"
    ) -> AudienceTags.SnapshotInput {
        let resolvedLedger: AudienceTags.LedgerSnapshot
        if let ledger {
            resolvedLedger = ledger
        } else {
            resolvedLedger = AudienceTags.LedgerSnapshot(transactionCount: ledgerCount ?? 0)
        }
        return AudienceTags.SnapshotInput(
            onboardingDone: onboardingDone,
            ledger: resolvedLedger,
            seenExplore: seenExplore,
            exploreShortcutAdded: exploreShortcutAdded,
            seenAnalytics: seenAnalytics,
            plan: plan,
            trialEndsAt: trialEndsAt,
            isPro: isPro,
            quotaVoice: quotaVoice,
            quotaSMS: quotaSMS,
            quotaReceipt: quotaReceipt,
            quotaPDF: quotaPDF,
            hitQuotaVoice: hitQuotaVoice,
            quotaHitTimestamps: quotaHitTimestamps,
            notifStatus: notifStatus,
            now: now,
            daysSinceInstall: daysSinceInstall,
            appVersion: appVersion,
            iosVersion: iosVersion,
            locale: locale
        )
    }
}
