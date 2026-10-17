//
//  HomeHeader.swift
//  Spendrift
//
//  Title bar, search entry and tab strip. Only the search bar and the strip pin:
//  the title and Settings scroll away under the status bar as the user reads.
//

import SwiftUI

/// Title and Settings. Scrolls with the content rather than pinning.
struct HomeTitleBar: View {
    let title: String
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.4)
                .accessibilityIdentifier("homeTitle")
            Spacer(minLength: 8)
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile and settings")
            .accessibilityIdentifier("openSettingsToolbar")
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
    }
}

/// Search entry. Tapping it pushes the search screen; it never filters in place.
struct HomeSearchBar: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(AppTheme.ink)
                Text("Search everything")
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(AppTheme.searchField, in: Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.searchFieldEdge, lineWidth: 1))
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityLabel("Search transactions, categories and accounts")
        .accessibilityIdentifier("homeSearchBar")
    }
}

/// Icon over label, with an underline under the selected tab. The selected
/// Transactions tab reads as its month and the selected Categories tab as its
/// type, and a second tap on either opens the matching picker.
struct HomeTabStrip: View {
    let selected: HomeTab
    /// Month name while Transactions is selected.
    let monthLabel: String
    /// "Expense" or "Income" while Categories is selected.
    let typeLabel: String
    let onSelect: (HomeTab) -> Void
    let onReselect: (HomeTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .overlay(alignment: .bottom) {
            AppTheme.hairline.frame(height: 1)
        }
    }

    private func label(for tab: HomeTab) -> String {
        switch tab {
        case .transactions where selected == .transactions: monthLabel
        case .categories where selected == .categories: typeLabel
        default: tab.title
        }
    }

    /// True while the label stands for a value the tab can change.
    private func hasPicker(_ tab: HomeTab) -> Bool {
        (tab == .transactions || tab == .categories) && selected == tab
    }

    private func tabButton(_ tab: HomeTab) -> some View {
        let isSelected = selected == tab

        return Button {
            if isSelected {
                onReselect(tab)
            } else {
                onSelect(tab)
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppTheme.ink)
                    .frame(height: 24)

                HStack(spacing: 2) {
                    Text(label(for: tab))
                        .font(.system(size: 12.5, weight: isSelected ? .bold : .regular))
                        .tracking(-0.1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if hasPicker(tab) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
                .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 11)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if isSelected {
                    AppTheme.ink
                        .frame(height: 3)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 3,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 3,
                                style: .continuous
                            )
                        )
                        .padding(.horizontal, 10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab-\(tab.rawValue)")
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? label(for: tab) : "")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint(hasPicker(tab) ? "Tap again to change" : "")
    }
}
