//
//  AppDelegate.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
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

    /// Routes a tapped reminder into the matching quick-add flow by opening its
    /// `spendrift://` deep link, reusing ContentView's existing `.onOpenURL` path.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard
            let link = response.notification.request.content.userInfo["deeplink"] as? String,
            let url = URL(string: link)
        else { return }

        Analytics.capture(.notificationOpened, [Analytics.Key.kind: url.host ?? "open"])

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
