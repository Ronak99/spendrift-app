//
//  AppDelegate.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
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
}
