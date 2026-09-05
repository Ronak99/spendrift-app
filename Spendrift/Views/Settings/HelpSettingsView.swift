//
//  HelpSettingsView.swift
//  Spendrift
//

import SwiftUI

struct HelpSettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex

    @State private var showFeatureRequest = false
    @State private var showInviteSheet = false

    private let helpFAQURL = URL(string: "https://spendrift.app/faq")
    private let privacyPolicyURL = URL(string: "https://spendrift.app/privacy_policy")

    private var accent: Color { Color.accentColor(forThemeIndex: selectedThemeIndex) }
    private var accentSoft: Color { accent.opacity(0.16) }

    var body: some View {
        SettingsScreen(title: "Help, Privacy & Contact") {
            SettingsCard {
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & FAQ",
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .externalLink,
                    action: { open(helpFAQURL) }
                )

                SettingsInsetDivider()

                SettingsRow(
                    icon: "hand.raised.fill",
                    title: "Privacy Policy",
                    accent: accent,
                    accentSoft: accentSoft,
                    accessory: .externalLink,
                    action: { open(privacyPolicyURL) }
                )

                SettingsInsetDivider()

                SettingsRow(
                    icon: "lightbulb.fill",
                    title: "Request a feature",
                    accent: accent,
                    accentSoft: accentSoft,
                    action: { showFeatureRequest = true }
                )

                SettingsInsetDivider()

                SettingsRow(
                    icon: "square.and.arrow.up.fill",
                    title: "Invite friends",
                    accent: accent,
                    accentSoft: accentSoft,
                    action: { showInviteSheet = true }
                )

                SettingsInsetDivider()

                SettingsRow(
                    icon: "star.fill",
                    title: "Rate Spendrift",
                    accent: accent,
                    accentSoft: accentSoft,
                    action: {
                        AppStoreReviewRequest.requestIfFirstTime(forKey: AppStoreReviewRequest.Keys.settingsRateTap)
                    }
                )
            }
        }
        .tint(accent)
        .sheet(isPresented: $showFeatureRequest) {
            FeatureRequestView()
        }
        .sheet(isPresented: $showInviteSheet) {
            ShareSheet(items: [AppShareContent.fullShareText])
        }
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }
}

#Preview {
    NavigationStack {
        HelpSettingsView()
    }
}
