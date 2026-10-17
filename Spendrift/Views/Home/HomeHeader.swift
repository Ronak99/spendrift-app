//
//  HomeHeader.swift
//  Spendrift
//
//  Title bar, search entry and tab strip. All three stay put while the panes
//  scroll beneath them.
//

import SwiftUI

// MARK: - Liquid Glass surface

private extension View {
    /// Liquid Glass capsule on iOS 26: transparent, so the header's blue atmosphere
    /// wash shows straight through it instead of sitting on a flat tinted fill.
    /// Falls back to that flat fill on earlier systems.
    @ViewBuilder
    func glassSearchCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self
                .background(AppTheme.searchField, in: Capsule())
                .overlay(Capsule().strokeBorder(AppTheme.searchFieldEdge, lineWidth: 1))
        }
    }
}

/// Title and Settings.
struct HomeTitleBar: View {
    let title: String
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.4)
                .accessibilityIdentifier("homeTitle")
            Spacer(minLength: 8)
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    // Fixed black rather than ink, so the white glyph keeps its
                    // contrast in dark mode, where ink turns light.
                    .background(Color.black.opacity(0.45), in: Circle())
                    .contentShape(Circle())
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.ink)
                Text("Search everything")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            .glassSearchCapsule()
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityLabel("Search transactions, categories and accounts")
        .accessibilityIdentifier("homeSearchBar")
    }
}

/// Icon over label, with an underline under the selected tab. The selected
/// Transactions tab reads as its month and the selected Categories tab as its
/// type, and a second tap on either opens the mat ching picker.
struct HomeTabStrip: View {
    let selected: HomeTab
    /// Month name while Transactions is selected.
    let monthLabel: String
    /// "Expense" or "Income" while Categories is selected.
    let typeLabel: String
    let onSelect: (HomeTab) -> Void
    let onReselect: (HomeTab) -> Void

    private static let stripInset: CGFloat = 6
    private static let underlineInset: CGFloat = 10

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, Self.stripInset)
        .overlay(alignment: .bottom) {
            AppTheme.hairline.frame(height: 1)
        }
        .overlay(alignment: .bottomLeading) { underline }
    }

    /// One underline that moves, rather than one per tab that appears and disappears.
    /// Only its offset animates, so a tap mid-slide retargets the spring from where
    /// the bar is instead of restarting from a view that is still being removed.
    private var underline: some View {
        GeometryReader { proxy in
            let tabs = HomeTab.allCases
            let tabWidth = (proxy.size.width - Self.stripInset * 2) / CGFloat(tabs.count)
            let index = CGFloat(tabs.firstIndex(of: selected) ?? 0)

            AppTheme.ink
                .frame(width: max(tabWidth - Self.underlineInset * 2, 0), height: 3)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 3,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 3,
                        style: .continuous
                    )
                )
                .offset(x: Self.stripInset + index * tabWidth + Self.underlineInset)
                .frame(maxHeight: .infinity, alignment: .bottom)
                // Scoped to the bar so the caller needs no withAnimation and the
                // labels swap instantly.
                .animation(.snappy(duration: 0.25), value: selected)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
                        .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                        .tracking(-0.1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if hasPicker(tab) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab-\(tab.rawValue)")
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? label(for: tab) : "")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint(hasPicker(tab) ? "Tap again to change" : "")
    }
}
