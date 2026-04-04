//
//  OnboardingShortcutsOpener.swift
//  MyMoney
//
//  Opens the Shortcuts app from onboarding, falling back gracefully if unavailable.
//  LSApplicationQueriesSchemes must include "shortcuts" in the target's Info settings.
//

import UIKit

enum OnboardingShortcutsOpener {
    static func openBestEffort() {
        let candidates = [
            "shortcuts://create-shortcut",
            "shortcuts://"
        ]
        for string in candidates {
            guard let url = URL(string: string) else { continue }
            guard UIApplication.shared.canOpenURL(url) else { continue }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
    }
}
