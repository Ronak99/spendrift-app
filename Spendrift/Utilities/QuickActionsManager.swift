//
//  QuickActionsManager.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import UIKit

class QuickActionsManager {
    static func setupQuickActions() {
        let createTransaction = UIApplicationShortcutItem(
            type: "com.mymoney.createTransaction",
            localizedTitle: "Create Transaction",
            localizedSubtitle: "Record a new transaction",
            icon: UIApplicationShortcutIcon(systemImageName: "plus.circle"),
            userInfo: nil
        )
        
        UIApplication.shared.shortcutItems = [createTransaction]
    }
    
    static func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> String? {
        return shortcutItem.type
    }
}
