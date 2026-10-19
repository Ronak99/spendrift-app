//
//  LedgerToolbar.swift
//  Spendrift
//
//  One title bar for the four tabs: the tab's title small and centred, and the
//  add and Settings plates together at the trailing edge, so Settings is one tap
//  away on every screen.
//
//  The title is the system inline navigation title rather than a Text in a
//  toolbar item: iOS 26 sizes toolbar items to a narrow slot and clipped custom text.
//

import SwiftUI

extension View {
    /// Small, centred title for a tab's root screen.
    func ledgerNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Trailing add and Settings plates. Pair with `ledgerNavigationTitle(_:)`.
/// Leave `onAdd` nil on a tab that creates nothing, and only Settings shows.
struct LedgerToolbar: ToolbarContent {
    /// VoiceOver name of the add plate, for example "Add transaction".
    var addAccessibilityLabel: String = "Add"
    var addAccessibilityIdentifier: String? = nil
    var onAdd: (() -> Void)? = nil

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .navigationBarTrailing) {
                actions
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                actions
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if let onAdd {
                LedgerAddButton(
                    accessibilityLabel: addAccessibilityLabel,
                    accessibilityIdentifier: addAccessibilityIdentifier,
                    action: onAdd
                )
            }
            ProfileSettingsToolbarButton()
        }
    }
}

/// The one inverted plate on screen: it creates whatever the tab lists.
struct LedgerAddButton: View {
    let accessibilityLabel: String
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.actionForeground)
                .frame(width: 32, height: 32)
                .background(AppTheme.actionBackground, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier ?? "plus")
    }
}

/// Value plus a down chevron, for the pickers pinned under the search bar: the
/// month on Transactions and the type on Categories.
struct LedgerDropdownLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.2)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(AppTheme.ink)
        .contentShape(Rectangle())
    }
}
