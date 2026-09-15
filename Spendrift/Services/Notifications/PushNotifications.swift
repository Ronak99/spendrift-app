//
//  PushNotifications.swift
//  Spendrift
//
//  OneSignal bootstrap, click routing, and permission-state sync. Local spend
//  reminders stay in NotificationManager; this type is the remote-push surface.
//

import Foundation
import OneSignalFramework
import UIKit
import UserNotifications

enum PushNotifications {
    private static let placeholderAppID = "ONESIGNAL_APP_ID_REPLACE_ME"
    private static var didSetup = false
    private static let clickListener = PushClickListener()

    /// True after OneSignal initialized this process. Audience tags no-op until then.
    static var isConfigured: Bool { didSetup }

    // MARK: - Lifecycle

    /// Initialise OneSignal and attach the click listener. Does not request
    /// notification permission — that happens from the Settings row.
    static func bootstrap(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !didSetup else { return }

        let appID = AppSecrets.oneSignalAppID
        guard !appID.isEmpty, appID != placeholderAppID else { return }

        OneSignal.initialize(appID, withLaunchOptions: launchOptions)
        OneSignal.login(DeviceIdentity.current)
        OneSignal.Notifications.addClickListener(clickListener)
        didSetup = true

        Task { @MainActor in
            await syncState()
            NotificationManager.refreshQuotaRefillReminder()
        }
    }

    static func handleForeground() {
        Task { @MainActor in
            await syncState()
            NotificationManager.refreshQuotaRefillReminder()
        }
    }

    // MARK: - Permission grant

    /// Called after the Settings toggle. Requests permission if needed, grants
    /// bonus credits on success, registers for remote notifications, and syncs.
    @MainActor
    static func enableFromSettings() async -> Bool {
        let status = await NotificationManager.authorizationStatus()
        if status == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return false
        }

        let granted: Bool
        if NotificationManager.isPermissionGranted(status) {
            granted = true
        } else {
            granted = await NotificationManager.requestAuthorization()
        }
        guard granted else { return false }

        UIApplication.shared.registerForRemoteNotifications()
        if AIQuotaStore.grantNotificationRewardIfNeeded() {
            Analytics.capture(.notificationRewardGranted)
        }
        await syncState()
        NotificationManager.refreshQuotaRefillReminder()
        return true
    }

    // MARK: - Click

    @MainActor
    static func handleClick(path: String?, campaign: String?) {
        let properties: [String: Any] = [
            Analytics.Key.kind: "push",
            Analytics.Key.path: path ?? "unknown",
            Analytics.Key.campaign: campaign ?? "",
        ]
        Analytics.capture(.notificationOpened, properties)

        guard let path, let route = AppRoute(path: path) else { return }
        AppRouter.shared.request(route)
    }

    // MARK: - Sync

    @MainActor
    static func syncState() async {
        guard !ProcessInfo.processInfo.arguments.contains("-UITesting") else { return }

        let status = await NotificationManager.authorizationStatus()
        let subscriptionID = didSetup ? OneSignal.User.pushSubscription.id : nil

        do {
            let client = try SpendriftBackendClient()
            try await client.recordNotificationState(
                deviceID: DeviceIdentity.current,
                appVersion: AppInfo.appVersionLabel(),
                permissionStatus: NotificationManager.permissionStatusName(status),
                onesignalSubscriptionID: subscriptionID,
                rewardGranted: AIQuotaStore.didGrantNotificationReward
            )
        } catch {
            Diagnostics.log(
                "Notification state sync failed",
                level: .warning,
                tags: [
                    Diagnostics.Tag.feature: Diagnostics.Feature.notifications.rawValue,
                    Diagnostics.Tag.stage: Diagnostics.Stage.bootstrap.rawValue,
                    Diagnostics.Tag.errorDomain: (error as NSError).domain,
                    Diagnostics.Tag.errorCode: String((error as NSError).code),
                ]
            )
        }

        await AudienceTags.sync()
    }
}

private final class PushClickListener: NSObject, OSNotificationClickListener {
    func onClick(event: OSNotificationClickEvent) {
        let data = event.notification.additionalData
        let path = data?["path"] as? String
        let campaign = data?["campaign"] as? String
        DispatchQueue.main.async {
            PushNotifications.handleClick(path: path, campaign: campaign)
        }
    }
}
