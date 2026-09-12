//
//  HelpSettingsView.swift
//  Spendrift
//

import SwiftUI

struct HelpSettingsRows: View {
    @Environment(\.openURL) private var openURL
    @State private var showFeatureRequest = false
    @State private var showInviteSheet = false

    private let helpFAQURL = URL(string: "https://spendrift.app/faq")
    private let privacyPolicyURL = URL(string: "https://spendrift.app/privacy_policy")

    private var accent: Color { AppTheme.accent }

    private enum Row: Int, CaseIterable, Identifiable {
        case faq
        case privacy
        case feature
        case invite
        case rate

        var id: Int { rawValue }

        var icon: String {
            switch self {
            case .faq: "questionmark.circle.fill"
            case .privacy: "hand.raised.fill"
            case .feature: "lightbulb.fill"
            case .invite: "square.and.arrow.up.fill"
            case .rate: "star.fill"
            }
        }

        var title: String {
            switch self {
            case .faq: "Help & FAQ"
            case .privacy: "Privacy Policy"
            case .feature: "Request a feature"
            case .invite: "Invite friends"
            case .rate: "Rate Spendrift"
            }
        }

        var accessory: SettingsListItem.Accessory {
            switch self {
            case .faq, .privacy: .externalLink
            case .feature, .invite: .chevron
            case .rate: .none
            }
        }
    }

    var body: some View {
        ForEach(Array(Row.allCases)) { row in
            Button {
                handleTap(row)
            } label: {
                SettingsListItem(
                    icon: row.icon,
                    title: row.title,
                    accent: accent,
                    accessory: row.accessory
                )
                .listItemPositioned(index: row.rawValue, count: Row.allCases.count)
            }
            .buttonStyle(.plain)
        }
        .tint(accent)
        .sheet(isPresented: $showFeatureRequest) {
            FeatureRequestView()
        }
        .sheet(isPresented: $showInviteSheet) {
            ShareSheet(items: [AppShareContent.fullShareText])
        }
    }

    private func handleTap(_ row: Row) {
        switch row {
        case .faq:
            open(helpFAQURL)
        case .privacy:
            open(privacyPolicyURL)
        case .feature:
            showFeatureRequest = true
        case .invite:
            showInviteSheet = true
        case .rate:
            AppStoreReviewRequest.requestIfFirstTime(forKey: AppStoreReviewRequest.Keys.settingsRateTap)
        }
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }
}

struct HelpSettingsView: View {
    var body: some View {
        SettingsScreen(title: "Help, Privacy & Contact", watermarkIcon: "questionmark.circle") {
            Section {
                HelpSettingsRows()
            }
        }
    }
}

#Preview {
    NavigationStack {
        HelpSettingsView()
    }
}
