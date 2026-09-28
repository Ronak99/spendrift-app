//
//  ForcedPro.swift
//  Spendrift
//
//  Debug-only switch that makes the app behave as a Pro subscriber however it
//  was launched. StoreKit test purchases only exist while Xcode launches the app,
//  so flows that start from Shortcuts or the home screen otherwise run as free.
//
//  Stored in the App Group so the App Intent and widget processes see it too.
//  Release builds always read false, so it cannot reach App Store users.
//

import Foundation

enum ForcedPro {
    static let defaultsKey = "spendriftForcePro"

    static var isEnabled: Bool {
        get {
            #if DEBUG
            DeveloperMode.store.bool(forKey: defaultsKey)
            #else
            false
            #endif
        }
        set {
            #if DEBUG
            DeveloperMode.store.set(newValue, forKey: defaultsKey)
            #endif
        }
    }
}
