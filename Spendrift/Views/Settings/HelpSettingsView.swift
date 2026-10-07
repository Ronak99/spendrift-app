//
//  HelpSettingsView.swift
//  Spendrift
//

import SwiftUI

struct HelpSettingsRows: View {
    @Environment(\.openURL) private var openURL

    private let privacyPolicyURL = URL(string: "https://spendrift.ronakpunase.dev/privacy_policy")

    private var accent: Color { AppTheme.accent }

    private enum Row: Int, CaseIterable, Identifiable {
        case privacy
        case invite
        case rate

        var id: Int { rawValue }

        var icon: String {
            switch self {
            case .privacy: "hand.raised.fill"
            case .invite: "square.and.arrow.up.fill"
            case .rate: "star.fill"
            }
        }

        var title: String {
            switch self {
            case .privacy: "Privacy Policy"
            case .invite: "Invite friends"
            case .rate: "Rate Spendrift"
            }
        }

        var accessory: SettingsListItem.Accessory {
            switch self {
            case .privacy: .externalLink
            case .invite: .chevron
            case .rate: .none
            }
        }
    }

    var body: some View {
        ForEach(Array(Row.allCases)) { row in
            rowControl(row)
                .buttonStyle(.plain)
        }
        .tint(accent)
    }

    /// Invite uses `ShareLink` so the system share sheet is presented by the row itself.
    /// A `.sheet` hosting `UIActivityViewController` on this list appears, then dismisses, on the first tap.
    @ViewBuilder
    private func rowControl(_ row: Row) -> some View {
        if row == .invite {
            ShareLink(item: AppShareContent.fullShareText) {
                rowLabel(row)
            }
        } else {
            Button {
                handleTap(row)
            } label: {
                rowLabel(row)
            }
        }
    }

    private func rowLabel(_ row: Row) -> some View {
        SettingsListItem(
            icon: row.icon,
            title: row.title,
            accent: accent,
            accessory: row.accessory
        )
        .listItemPositioned(index: row.rawValue, count: Row.allCases.count)
    }

    private func handleTap(_ row: Row) {
        switch row {
        case .privacy:
            open(privacyPolicyURL)
        case .invite:
            // Presented by ShareLink in `rowControl`.
            break
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
