//
//  AppStoreReviewRequest.swift
//  Spendrift
//
//  Centralized one-shot App Store review prompts. The system may throttle when the dialog appears.
//

import Foundation
import StoreKit
import UIKit

enum AppStoreReviewRequest {
    enum Keys {
        static let firstStatementImport = "didRequestAppStoreReviewAfterFirstStatementImport"
        static let firstVoiceTransaction = "didRequestAppStoreReviewAfterFirstVoiceTransaction"
    }

    /// Persists `true` for `key` and requests a review. No-ops if `key` was already set.
    static func requestIfFirstTime(forKey key: String) {
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
