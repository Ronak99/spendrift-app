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
                CyclingSearchPlaceholder()
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.inkSecondary)
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            // Makes the whole capsule the tap target, not just the icon and words.
            .contentShape(Capsule())
            .glassSearchCapsule()
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityLabel(CyclingSearchPlaceholder.accessibilityText)
        .accessibilityIdentifier("homeSearchBar")
    }
}

/// Icon over label, with an underline under the selected tab. The underline
/// is one bar that slides, and its width follows the selected icon and label
/// rather than the tab slot. The selected Transactions tab reads as its month
/// and the selected Categories tab as its type, and a second tap on either
/// opens the matching picker.
struct HomeTabStrip: View {
    let selected: HomeTab
    /// Month name while Transactions is selected.
    let monthLabel: String
    /// "Expense" or "Income" while Categories is selected.
    let typeLabel: String
    let onSelect: (HomeTab) -> Void
    let onReselect: (HomeTab) -> Void

    private static let stripInset: CGFloat = 6

    /// Changes when the bar must move or resize, including a month or type swap
    /// on the already selected tab. Labels themselves stay outside this animation.
    private var indicatorToken: String {
        "\(selected.rawValue)|\(label(for: selected))"
    }

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
        .overlayPreferenceValue(TabContentAnchorKey.self) { anchors in
            underline(anchors: anchors)
        }
    }

    /// One underline that moves, rather than one per tab that appears and disappears.
    /// Width and offset both come from the selected tab's measured content, so a tap
    /// mid-slide retargets the spring from where the bar is.
    private func underline(anchors: [HomeTab: Anchor<CGRect>]) -> some View {
        GeometryReader { proxy in
            if let anchor = anchors[selected] {
                let frame = proxy[anchor]

                AppTheme.ink
                    .frame(width: frame.width, height: 3)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 3,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 3,
                            style: .continuous
                        )
                    )
                    .offset(x: frame.minX)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    // Scoped to the bar so the caller needs no withAnimation and the
                    // labels swap instantly.
                    .animation(.snappy(duration: 0.25), value: indicatorToken)
            }
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
            VStack(spacing: 4) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppTheme.ink)
                    .frame(height: 18)

                HStack(spacing: 2) {
                    Text(label(for: tab))
                        .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                        .tracking(-0.1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if hasPicker(tab) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                    }
                }
                .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.inkSecondary)
            }
            // Hug the icon and label so the underline can match them. The frame
            // below still fills the slot, which keeps the tap target full width.
            .fixedSize(horizontal: true, vertical: false)
            .anchorPreference(key: TabContentAnchorKey.self, value: .bounds) { [tab: $0] }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 9)
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

/// Bounds of each tab's icon-and-label stack, in the strip's coordinate space.
private struct TabContentAnchorKey: PreferenceKey {
    static var defaultValue: [HomeTab: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [HomeTab: Anchor<CGRect>],
        nextValue: () -> [HomeTab: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
