//
//  ForcedPro.swift
//  Spendrift
//
//  Developer switch that makes the app behave as a Pro subscriber however it
//  was launched. StoreKit test purchases only exist while Xcode launches the app,
//  so flows that start from Shortcuts or the home screen otherwise run as free.
//
//  Stored in the App Group so the App Intent and widget processes see it too.
//  The flag stays off until a developer turns the Settings switch on. Debug builds
//  always expose that switch. Release builds expose it only after the developer
//  passphrase, so an App Store install that never unlocks developer tools cannot
//  turn it on.
//

import Foundation

enum ForcedPro {
    static let defaultsKey = "spendriftForcePro"

    static var isEnabled: Bool {
        get {
            guard DeveloperMode.isEnabled else { return false }
            return DeveloperMode.store.bool(forKey: defaultsKey)
        }
        set {
            guard DeveloperMode.isEnabled else { return }
            DeveloperMode.store.set(newValue, forKey: defaultsKey)
        }
    }
}
