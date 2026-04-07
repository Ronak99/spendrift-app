//
//  AppShareContent.swift
//  Spendrift
//

import Foundation

enum AppShareContent {
    /// Friendly copy for Messages, Mail, and other share targets.
    static let shareMessage: String = """
    I've been using Spendrift to track spending, income, and even log things by voice, it's been really helpful. Check it out, you might like it too.
    """

    /// App Store search link until a dedicated App Store URL is available; replace with your app’s link when published.
    static let appStoreSearchURL = URL(string: "https://apps.apple.com/search?term=Spendrift")!

    static var fullShareText: String {
        """
        \(shareMessage)

        \(appStoreSearchURL.absoluteString)
        """
    }
}
