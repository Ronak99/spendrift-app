//
//  AppDelegate.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
// comment fixes an issue

import UIKit
import UserNotifications
#if DEBUG
import DebugSwift
#endif

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    #if DEBUG
    let debugSwift = DebugSwift()
    #endif

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        PushNotifications.bootstrap(launchOptions: launchOptions)
        #if DEBUG
        DebugSwiftBootstrap.start(debugSwift)
        #endif
        if let url = launchOptions?[.url] as? URL {
            handleIncomingURL(url)
        }
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        handleIncomingURL(url)
        return true
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "spendrift", url.host == "importReceipt" else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .receiptShareImportTriggered, object: nil)
        }
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let handled = handleQuickAction(shortcutItem)
        completionHandler(handled)
    }
    
    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let actionType = QuickActionsManager.handleQuickAction(shortcutItem) else {
            return false
        }
        
        // Post notification to handle in SwiftUI
        NotificationCenter.default.post(
            name: NSNotification.Name("QuickAction"),
            object: nil,
            userInfo: ["action": actionType]
        )
        
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Logs the open and routes a tapped reminder into the matching quick-add flow
    /// by opening its `spendrift://` deep link, reusing ContentView's existing
    /// `.onOpenURL` path.
    ///
    /// The analytics half runs for every tap, including reminders with no deep link
    /// (the quota refill and the Pro trial reminder) — those used to open the app
    /// without logging anything at all.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let request = response.notification.request
        let userInfo = request.content.userInfo
        let kind = NotificationManager.openKind(userInfo: userInfo)

        NotificationOpenAttribution.record(kind: kind, notificationID: request.identifier)
        Analytics.capture(.notificationOpened, [
            Analytics.Key.source: "local",
            Analytics.Key.kind: kind,
            Analytics.Key.notificationID: request.identifier,
        ])

        guard let url = NotificationManager.deeplink(userInfo: userInfo) else { return }

        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }

    /// Show reminders as banners even when the app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
