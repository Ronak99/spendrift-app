//
//  AppRouter.swift
//  Spendrift
//
//  Path-driven Settings navigation, plus a pending buffer so a cold-start push
//  tap is not lost before SwiftUI is on screen.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum SettingsDestination: Hashable {
        case feedback
        case explore
        case emailReceipts
        case backup
        /// Bank SMS capture, opened from the Home capture tray.
        case bankSMS
    }

    var settingsPath: [SettingsDestination] = []
    private(set) var pending: AppRoute?

    private init() {}

    func request(_ route: AppRoute) {
        pending = route
    }

    func consume() -> AppRoute? {
        defer { pending = nil }
        return pending
    }
}
