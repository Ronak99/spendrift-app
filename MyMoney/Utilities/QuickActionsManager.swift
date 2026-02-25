//
//  QuickActionsManager.swift
//  MyMoney
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
        
        let importStatement = UIApplicationShortcutItem(
            type: "com.mymoney.importStatement",
            localizedTitle: "Import Statement",
            localizedSubtitle: "Import bank statement",
            icon: UIApplicationShortcutIcon(systemImageName: "square.and.arrow.down"),
            userInfo: nil
        )
        
        let search = UIApplicationShortcutItem(
            type: "com.mymoney.search",
            localizedTitle: "Search",
            localizedSubtitle: "Search for a transaction",
            icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
            userInfo: nil
        )
        
        UIApplication.shared.shortcutItems = [createTransaction, importStatement, search]
    }
    
    static func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> String? {
        return shortcutItem.type
    }
}
