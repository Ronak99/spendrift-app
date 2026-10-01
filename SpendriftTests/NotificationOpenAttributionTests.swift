//
//  NotificationOpenAttributionTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

@Suite(.serialized)
struct NotificationOpenAttributionTests {
    init() {
        NotificationOpenAttribution.clear()
    }

    @Test
    func noRecordMeansADirectOpen() {
        #expect(NotificationOpenAttribution.current() == nil)
    }

    @Test
    func keepsTheTappedNotificationsDetails() {
        NotificationOpenAttribution.record(kind: "voice", notificationID: "spendrift.reminder.voice.3")

        let record = NotificationOpenAttribution.current()
        #expect(record?.kind == "voice")
        #expect(record?.notificationID == "spendrift.reminder.voice.3")
        #expect(record?.campaign == nil)
    }

    @Test
    func keepsPushCampaign() {
        NotificationOpenAttribution.record(kind: "push", campaign: "feedback_nudge_v1")

        let record = NotificationOpenAttribution.current()
        #expect(record?.kind == "push")
        #expect(record?.campaign == "feedback_nudge_v1")
    }

    /// A cold start captures `app_opened` twice (`onAppear` then `scenePhase`),
    /// so reading must not consume the record.
    @Test
    func survivesRepeatedReads() {
        NotificationOpenAttribution.record(kind: "statement")

        #expect(NotificationOpenAttribution.current()?.kind == "statement")
        #expect(NotificationOpenAttribution.current()?.kind == "statement")
    }

    @Test
    func expiresAfterTheWindow() {
        let tappedAt = Date()
        NotificationOpenAttribution.record(kind: "type", now: tappedAt)

        let inside = tappedAt.addingTimeInterval(NotificationOpenAttribution.window - 1)
        #expect(NotificationOpenAttribution.current(now: inside)?.kind == "type")

        let outside = tappedAt.addingTimeInterval(NotificationOpenAttribution.window + 1)
        #expect(NotificationOpenAttribution.current(now: outside) == nil)
    }

    @Test
    func clearingDropsTheRecord() {
        NotificationOpenAttribution.record(kind: "quota_refill")
        NotificationOpenAttribution.clear()

        #expect(NotificationOpenAttribution.current() == nil)
    }

    @Test
    func latestTapWins() {
        NotificationOpenAttribution.record(kind: "type", notificationID: "a")
        NotificationOpenAttribution.record(kind: "push", campaign: "b")

        #expect(NotificationOpenAttribution.current()?.kind == "push")
        #expect(NotificationOpenAttribution.current()?.notificationID == nil)
    }
}

@Suite
struct NotificationOpenKindTests {
    @Test
    func prefersTheStampedKind() {
        let userInfo: [AnyHashable: Any] = [
            "kind": "voice",
            "deeplink": "spendrift://voiceExpense",
        ]
        #expect(NotificationManager.openKind(userInfo: userInfo) == "voice")
    }

    /// Requests scheduled before the `kind` stamp shipped are still pending on device.
    @Test
    func fallsBackToTheDeepLinkHost() {
        let userInfo: [AnyHashable: Any] = ["deeplink": "spendrift://createTransaction"]
        #expect(NotificationManager.openKind(userInfo: userInfo) == "createTransaction")
    }

    @Test
    func reportsUnknownRatherThanDroppingTheOpen() {
        #expect(NotificationManager.openKind(userInfo: [:]) == "unknown")
        #expect(NotificationManager.openKind(userInfo: ["kind": ""]) == "unknown")
    }

    @Test
    func readsTheDeepLink() {
        let userInfo: [AnyHashable: Any] = ["deeplink": "spendrift://importStatement"]
        #expect(NotificationManager.deeplink(userInfo: userInfo)?.host == "importStatement")
        #expect(NotificationManager.deeplink(userInfo: ["kind": "quota_refill"]) == nil)
    }
}
